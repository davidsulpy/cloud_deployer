##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class AWSDeployer
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'

		def initialize(options = {
			region: 'us-east-1',
			notify_teamcity: true
			})
			@template_location = options[:template_location]
			@stack_name = options[:stack_name].gsub(".", "-")
			@cfn_vars = options[:cfn_vars]
			@disable_rollback = options[:disable_rollback] || true
			@notify_teamcity = options[:notify_teamcity]
 
			if (options[:access_key_id] == nil || options[:access_key_id] == '')
				raise "access_key_id cannot be empty or nil"
			end
			if (options[:secret_access_key] == nil || options[:secret_access_key] == '')
				raise "secret_access_key cannot be empty or nil"
			end
			@access_key_id = options[:access_key_id]
			@secret_access_key = options[:secret_access_key]
 
			Aws.config.update({
				credentials: Aws::Credentials.new(@access_key_id, @secret_access_key),
				region: options[:region]
				})
		end

		def validate_template_pub()
			return validate_template(Aws::CloudFormation::Client.new, File.read(@template_location, :encoding => 'UTF-8'))
		end
 
		def validate_template(cloudformation, template_contents)
			puts " # validating template"

			begin
				validationResponse = cloudformation.validate_template({
					template_body: template_contents
					})
			rescue Aws::CloudFormation::Errors::ValidationError => error
				puts " # # invalid template #{error}"
				return
			end
			
			puts " # # template valid!"
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

			begin
				resp = cf_client.describe_stacks({
					stack_name: stack_name
					})
				stack = resp.stacks.find{|s| s.stack_name == stack_name}
				return stack
			rescue Aws::CloudFormation::Errors::ValidationError
				return nil
			end
		end

		def deploy_or_update_cloudformation()
			puts "Deploying CloudFormation stack using template #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')

			cloudformation = Aws::CloudFormation::Client.new
			
			existing_stack = get_stack(@stack_name)
			if (existing_stack == nil)
				puts "The stack #{@stack_name} doesn't exist, creating"
				return deploy_cloudformation_template()
			elsif (existing_stack != nil && (existing_stack.stack_status == "CREATE_FAILED" || existing_stack.stack_status == "UPDATE_ROLLBACK_FAILED"))
				puts "The stack #{@stack_name} exists but has a CREATE_FAILED state, deleting it..."
				delete_stack(@stack_name)
				return deploy_cloudformation_template()
			end

			puts "updating #{@stack_name}"

			validate_template(cloudformation, app_template)

			puts " # updating stack"

			template_params = []

			@cfn_vars.each do |key, value|
				template_params.push({
					parameter_key: key,
					parameter_value: value
					})
			end

			if (existing_stack != nil)
				resp = cloudformation.update_stack({
					stack_name: @stack_name,
					template_body: app_template,
					parameters: template_params
					})
				success = check_stack_status(@stack_name, {
						:status => :stack_update_complete
					})
			end
 			
			if (!success)
				raise "Updating the cloudformation stack failed, check logs for details"
			end

			@stack_outputs = {}

			stack = get_stack(@stack_name)

			stack.outputs.each do |output|
				@stack_outputs[output.output_key] = output.output_value
			end
			return @stack_outputs
		end
 
		def deploy_cloudformation_template()
			puts "Getting CloudFormation template at #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')
			
			cloudformation = Aws::CloudFormation::Client.new
			
			puts "deploying #{@stack_name}"
			
			validate_template(cloudformation, app_template)
 
			puts " # creating stack"

			template_params = []

			@cfn_vars.each do |key, value|
				template_params.push({
					parameter_key: key,
					parameter_value: value
					})
			end

			resp = cloudformation.create_stack(
				{
					stack_name: @stack_name,
					template_body: app_template,
					parameters: template_params,
					disable_rollback: @disable_rollback,
					capabilities: ['CAPABILITY_IAM']
				})
			
			success = check_stack_status(@stack_name)
 			
 			if (!success)
 				raise "Deploying the cloudformation stack failed, check logs for details"
 			end

			@stack_outputs = {}

			stack = get_stack(@stack_name)

			stack.outputs.each do |output|
				@stack_outputs[output.output_key] = output.output_value
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

	 				if (options[:status] == :stack_update_complete)
	 					w.max_attempts = 40
	 				end
	 				w.before_attempt do |n|
	 					puts "	# waiting for #{status} (attempt #{n})"
	 				end
	 			end
	 		rescue Aws::Waiters::Errors::FailureStateError
	 			if (@notify_teamcity)
	 				puts "##teamcity[message text='CloudFormation FailureStateError' errorDetails='failed, stack may be in a stuck state' status='ERROR']"
	 			end
	 			puts "  # failed, stack is in a stuck state"
	 			return false
	 		rescue Aws::Waiters::Errors::TooManyAttemptsError
	 			if (@notify_teamcity)
	 				puts "##teamcity[message text='CloudFormation TooManyAttemptsError' errorDetails='CloudFormation stack didn't arrive at the specified status in enough checks' status='ERROR']"
	 			end
	 			puts "	# stack didn't become healthy fast enough..."
	 			return false
	 		rescue Aws::Waiters::Errors::UnexpectedError
	 			if (@notify_teamcity)
	 				puts "##teamcity[message text='CloudFormation UnexpectedError' errorDetails='unexpected error occured deploying CloudFormation template' status='ERROR']"
	 			end
	 			puts "	# unexpected error occured"
	 			return false
	 		rescue Aws::Waiters::Errors::NoSuchWaiterError
	 			if (@notify_teamcity)
	 				puts "##teamcity[message text='CloudFormation NoSuchWaiterError' errorDetails='invalid CloudFormation stack wait status' status='ERROR']"
	 			end
	 			puts "	# invalid wait status"
	 			return false
	 		end

			return true
		end
	end

end