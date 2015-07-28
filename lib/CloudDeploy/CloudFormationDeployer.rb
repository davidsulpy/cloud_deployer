##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class AWSDeployer
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'

		def initialize(options = {})
			@template_location = options[:template_location]
			@stack_name = options[:stack_name].gsub(".", "-")
			@cfn_vars = options[:cfn_vars]
			@use_curses = options[:use_curses]
			@disable_rollback = options[:disable_rollback] || true
 
			if (options[:access_key_id] == nil || options[:access_key_id] == '')
				raise "access_key_id cannot be empty or nil"
			end
			if (options[:secret_access_key] == nil || options[:secret_access_key] == '')
				raise "secret_access_key cannot be empty or nil"
			end
			@access_key_id = options[:access_key_id]
			@secret_access_key = options[:secret_access_key]
 
			configure_aws()
		end
 
		def configure_aws()
			Aws.config.update({
				credentials: Aws::Credentials.new(@access_key_id, @secret_access_key)
				})
		end
 
		def validate_template(cloudformation, template_contents)
			puts " # validating template"
			validationResponse = cloudformation.validate_template({
				template_body: template_contents
				})
			
			if (validationResponse[:code])
				raise "invalid template: #{validationResponse[:message]}"
			else
				puts " # # template VALID!"
			end
		end
 
		def check_if_exists(stack_name)
			stack = get_stack(stack_name)

			if (stack != nil)
				puts "stack exists with status #{stack.stack_status}"
				return true
			end
			puts "stack doesn't exist"
			return false
		end

		def get_stack(stack_name)
			cf_client = Aws::CloudFormation::Client.new

			stacks = cf_client.describe_stacks({
				stack_name: stack_name
				})
			satck = stacks.find{|s| s.stack_name == stack_name}

			return stack
		end

		def deploy_or_update_cloudformation()
			puts "Deploying CloudFormation stack using template #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')

			cloudformation = Aws::CloudFormation::Client.new
			
			existing_stack = get_stack(@stack_name)
			if (existing_stack != nil && existing_stack.stack_status == "CREATE_FAILED")
				puts "The stack #{@stack_name} exists but has a CREATE_FAILED state, deleting it..."
				delete_stack(@stack_name)
				return deploy_cloudformation_template()
			end

			puts "updating #{@stack_name}"

			validate_template(cloudformation, app_template)

			puts " # updating stack"

			if (existing_stack != nil)
				resp = cloudformation.update_stack({
					stack_name: @stack_name,
					template_body: app_template,
					parameters: @cfn_vars
					})
			end

			success = false
			if (@use_curses)
				success = check_stack_status_curses(current_stack_name)
			else
				success = check_stack_status()
			end
 			
			if (!success)
				raise "Updating the cloudformations tack failed, check logs for details"
			end

			@stack_outputs = {}
			stack.outputs.each do |output|
				@stack_outputs[output.key] = output.value
			end
			return @stack_outputs
		end
 
		def deploy_cloudformation_template()
			puts "Getting CloudFormation template at #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')
			
			cloudformation = Aws::CloudFormation.new
			app_stackname = current_stack_name
			
			puts "deploying #{app_stackname}"
			
			validate_template(cloudformation, app_template)
 
			puts " # creating stack"
			stack = cloudformation.stacks.create(app_stackname, app_template,
				:capabilities => ['CAPABILITY_IAM'],
				:disable_rollback => @disable_rollback,
				:parameters => @cfn_vars
				)
			
			success = true
			if (@use_curses)
				success = check_stack_status_curses(current_stack_name)
			else
				success = check_stack_status(current_stack_name)
			end
 			
 			if (!success)
 				raise "Deploying the cloudformation stack failed, check logs for details"
 			end

			@stack_outputs = {}
			stack.outputs.each do |output|
				@stack_outputs[output.key] = output.value
			end

			return @stack_outputs
		end
 
		def delete_stack(stack_name)
			puts "deleting #{stack_name}"
			cloudformation = Aws::CloudFormation::Client.new
 	
 			cloudformation.delete_stack({
 				stack_name: stack_name
 				})
			
			puts "AWS has been informed to delete #{stack_name}."


			check_stack_status(stack_name, {
				:force_delete => true,
				:status => :stack_delete_complete
				})

			puts "Delete has finished!"
		end

		def check_stack_status(stack_name, options = { :status => :stack_create_complete})
			status_title_message = "Monitoring AWS Stack Events for #{stack_name}"
			cloudformation = Aws::CloudFormation::Client.new
 			
 			status = options[:status]

 			begin
	 			cloudformation.wait_until(status, {
	 				stack_name: stack_name
	 				}) do |w|

	 				w.before_attempt do |n|
	 					puts "	# waiting for #{status} (attempt #{n})"
	 				end
	 			end
	 		rescue Aws::Waiters::Errors::FailureStateError
	 			puts "  # failed, stack is in a stuck state"
	 			return false
	 		rescue Aws::Waiters::Errors::TooManyAttempsError
	 			puts "	# stack didn't become healthy fast enough..."
	 			return false
	 		rescue Aws::Waiters::Errors::UnexpectedError
	 			puts "	# unexpected error occured"
	 			return false
	 		rescue Aws::Waiters::Errors::NoSuchWaiterError
	 			puts "	# invalid wait status"
	 			return false
	 		end

			return true
		end
	end

end