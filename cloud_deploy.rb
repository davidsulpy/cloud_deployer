module CloudDeploy
	class S3Helper
		require 'aws-sdk'
 
		def initialize (options = {})
			if (options[:access_key_id] == nil || options[:access_key_id] == '')
				raise "access_key_id cannot be empty or nil"
			end
			if (options[:secret_access_key] == nil || options[:secret_access_key] == '')
				raise "secret_access_key cannot be empty or nil"
			end
			AWS.config({
				:access_key_id => options[:access_key_id],
				:secret_access_key => options[:secret_access_key]
				})
		end
 
		def put_asset_in_s3(asset_location, bucket, s3_path = "")
			puts "Copying asset #{asset_location} to S3 bucket #{bucket}"
			s3 = AWS::S3.new
			bucket = s3.buckets[bucket]
			Dir.glob(asset_location) do |file_name|
				base_name = File.basename(file_name)
				remote_name = "#{base_name}"
				if (s3_path != "")
					remote_name = "#{s3_path}/#{base_name}"
				end
				puts " # Uploading #{remote_name}"
 
				#Uploading with a temp name and renaming to get around some weird bug.
		 		obj = bucket.objects["_#{remote_name}"]		
		 		obj.write(:data => File.open(file_name), :content_length => File.size(file_name), :content_type =>  'application/zip', :multipart_threshold => 100 * 1024 * 1024)
		 		obj.move_to(remote_name)
			end
			puts "Finished pushing assets to S3!"
		end
	end
 
	class AWSDeployer
		require 'aws-sdk'

		def initialize(options = {})
			@template_location = options[:template_location]
			@stack_name = options[:stack_name]
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
			AWS.config({
				:access_key_id => @access_key_id,
				:secret_access_key => @secret_access_key
				})
		end
 
		def put_asset_in_s3(asset_location, bucket)
			puts "Copying asset #{asset_location} to S3 bucket #{bucket}"
			s3 = AWS::S3.new
			bucket = s3.buckets[bucket]
			Dir.glob(asset_location) do |file_name|
				base_name = File.basename(file_name)
				remote_name = "#{base_name}"
				puts " # Uploading #{remote_name}"
 
				#Uploading with a temp name and renaming to get around some weird bug.
		 		obj = bucket.objects["_#{remote_name}"]		
		 		obj.write(:data => File.open(file_name), :content_length => File.size(file_name), :content_type =>  'application/zip', :multipart_threshold => 100 * 1024 * 1024)
		 		obj.move_to(remote_name)
			end
			puts "Finished pushing assets to S3!"
		end
 
		def validate_template(cloudformation, template_contents)
			puts " # validating template"
			validationResponse = cloudformation.validate_template(template_contents)
			
			if (validationResponse[:code])
				raise "invalid template: #{validationResponse[:message]}"
			else
				puts " # # template VALID!"
			end
		end
 
		def check_if_exists(stack_name)
			cloudformation = AWS::CloudFormation.new

			stack = cloudformation.stacks[stack_name]
			if (stack.exists?)
				puts "stack exists with status #{stack.status}"
				return true
			end
			puts "stack doesn't exist"
			return false
		end

		def update_cloudformation_template()
			puts "Updating CloudFormation stack using template #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')

			cloudformation = AWS::CloudFormation.new
			app_stackname = current_stack_name
			
			if (check_if_exists(current_stack_name) && cloudformation.stacks[current_stack_name].status == "CREATE_FAILED")
				puts "The stack #{current_stack_name} exists but has a CREATE_FAILED state, deleting it..."
				delete_stack(current_stack_name)
				return deploy_cloudformation_template()
			end
			
			puts "updating #{app_stackname}"

			validate_template(cloudformation, app_template)

			puts " # updating stack"
			stack = cloudformation.stacks[app_stackname]

			if (stack != nil)
				stack.update({
					:template => app_template,
					:parameters => @cfn_vars
					})
			end

			if (@use_curses)
				check_stack_status_curses(current_stack_name)
			else
				check_stack_status(current_stack_name)
			end
 
			@stack_outputs = {}
			stack.outputs.each do |output|
				@stack_outputs[output.key] = output.value
			end

		end
 
		def deploy_cloudformation_template()
			puts "Getting CloudFormation template at #{@template_location}"
			app_template = File.read(@template_location, :encoding => 'UTF-8')
			
			cloudformation = AWS::CloudFormation.new
			app_stackname = current_stack_name
			
			puts "deploying #{app_stackname}"
			
			validate_template(cloudformation, app_template)
 
			puts " # creating stack"
			stack = cloudformation.stacks.create(app_stackname, app_template,
				:capabilities => ['CAPABILITY_IAM'],
				:disable_rollback => @disable_rollback,
				:parameters => @cfn_vars
				)
			
			if (@use_curses)
				check_stack_status_curses(current_stack_name)
			else
				check_stack_status(current_stack_name)
			end
 
			@stack_outputs = {}
			stack.outputs.each do |output|
				@stack_outputs[output.key] = output.value
			end
		end
 
		def delete_stack(stack_name)
			puts "deleting #{stack_name}"
			cloudformation = AWS::CloudFormation.new
			stack = cloudformation.stacks[stack_name]
 
			puts "#{stack_name} has current status #{stack.status}"
			stack.delete
			puts "AWS has been informed to delete #{stack_name} #{stack.status}."

			if (@use_curses)
				check_stack_status_curses(stack_name, {
					:force_delete => true
					})
			else
				check_stack_status(stack_name, {
					:force_delete => true
					})
			end
			puts "Delete has finished!"
		end

		def check_stack_status(stack_name, options = {})
			status_title_message = "Monitoring AWS Stack Events for #{stack_name}"
			cloudformation = AWS::CloudFormation.new
			stack = cloudformation.stacks[stack_name]
 
			if (stack.status == "CREATE_COMPLETE")
				puts " # Create Complete!"
			else
				finished = false
				while (!finished)
					if (stack == nil || !stack.exists? || stack.status == "DELETE_COMPLETE")
						puts "success! stack deleted."
						finished = true
						break
					end
					if (stack.status == "CREATE_COMPLETE")
						puts "success! stack created!"
						finished = true
						break
					elsif (stack.status == "UPDATE_COMPLETE")
						puts "success! stack has been updated!"
						finished = true
						break
					elsif (stack.status == "CREATE_FAILED")
						puts "failed to create #{@app_name} stack. #{stack.status_reason}"
						finished = true
						break
					elsif (stack.status == "UPDATE_FAILED")
						puts "failed to update #{@app_name} stack. #{stack.status_reason}"
						finished = true
						break
					elsif (stack.status == "DELETE_FAILED")
						if (options[:force_delete])
							puts " # Delete failed, attempting delete again"
							stack.delete
						else
							puts "failed to delete #{stack_name} stack. #{stack.status_reason}"
							finished = true
							break
						end
					end
					index = 2
					stack.events.each do |event|
						event_message = "[#{event.timestamp}] #{event.logical_resource_id}: #{event.resource_status} #{event.resource_status_reason}"
						if (event_message.include? "CREATE_COMPLETE")
							
						end
						index += 1
					end
					wait_sec = 15 # this is an interval to wait before checking the cloudformation stack status again
					while (wait_sec > 0)
						sleep 1
						wait_sec -= 1
					end
				end
			end
 
			stack.events.each do |event|
				puts "#{event.timestamp},#{event.logical_resource_id}:,#{event.resource_status},#{event.resource_status_reason}"
			end
			puts "Status summary: #{stack.status} #{stack.status_reason}"
		end
 
		def check_stack_status_curses(stack_name, options = {})
			begin
				require 'curses'
			rescue Exception
				puts "Curses dependency doesn't exist, using non curses version..."
				return check_stack_status(stack_name, options)
			end
			
			Curses.init_screen
			Curses.start_color
			status_title_message = "Monitoring AWS Stack Events for #{stack_name}"
			Curses.refresh
			cloudformation = AWS::CloudFormation.new
			stack = cloudformation.stacks[stack_name]
 
			if (stack.status == "CREATE_COMPLETE")
				Curses.setpos(1,0)
				Curses.addstr("#{stack_name} is created")
				sleep 2
				Curses.close_screen
			else
				finished = false
				while (!finished)
					Curses.addstr(status_title_message)
					if (stack == nil || !stack.exists? || stack.status == "DELETE_COMPLETE")
						Curses.close_screen
						puts "success! stack deleted."
						finished = true
						break
					end
					if (stack.status == "CREATE_COMPLETE")
						Curses.close_screen
						puts "success! stack created!"
						finished = true
						break
					elsif (stack.status == "UPDATE_COMPLETE")
						Curses.close_screen
						puts "success! stack has been updated!"
						finished = true
						break
					elsif (stack.status == "CREATE_FAILED")
						Curses.close_screen
						puts "failed to create #{@app_name} stack. #{stack.status_reason}"
						finished = true
						break
					elsif (stack.status == "UPDATE_FAILED")
						Curses.close_screen
						puts "failed to update #{@app_name} stack. #{stack.status_reason}"
						finished = true
						break
					elsif (stack.status == "DELETE_FAILED")
						if (options[:force_delete])
							Curses.setpos(1, 0)
							Curses.addstr("Delete failed, attempting delete again.")
							stack.delete
						else
							Curses.close_screen
							puts "failed to delete #{stack_name} stack. #{stack.status_reason}"
							finished = true
							break
						end
					end
					index = 2
					stack.events.each do |event|
						event_message = "[#{event.timestamp}] #{event.logical_resource_id}: #{event.resource_status} #{event.resource_status_reason}"
						if (event_message.include? "CREATE_COMPLETE")
							
						end
						Curses.setpos(index, 0)
						Curses.addstr(event_message)
						index += 1
					end
					Curses.refresh
					wait_sec = 15 # this is an interval to wait before checking the cloudformation stack status again
					while (wait_sec > 0)
						Curses.setpos(1, (wait_sec-15))
						Curses.addstr(">")
						Curses.refresh
						sleep 1
						wait_sec -= 1
					end
					Curses.clear
				end
			end
 
			stack.events.each do |event|
				puts "#{event.timestamp},#{event.logical_resource_id}:,#{event.resource_status},#{event.resource_status_reason}"
			end
			puts "Status summary: #{stack.status} #{stack.status_reason}"
		end
 
		def switch_elastic_ip(elastic_ip, options = {})
			@elastic_ip = elastic_ip
			puts "Switching elastic IP for #{@app_name}"
			
			instanceId = @stack_outputs['InstanceId']
			if (instanceId == nil || instanceId == "")
				instanceId = options[:instance_id]
				if (instanceId == nil || instanceId == "")
					raise "Instance Id is not found."
				end
			end
 
			begin
				eip = AWS::EC2::ElasticIp.new(@elastic_ip)
				
				associateOptions = {
					:instance => instanceId
				}
 
				if (eip.exists?)
					eip.associate(associateOptions)
					puts "New instance now associated with #{@elastic_ip}"
				end
				
			rescue Exception => ex
				raise "problem setting changing elastic ip. Exception Message: #{ex.message}"
			end
		end
 
		def delete_old_stacks(app_env, app_name)
			puts "DELETING OLD STACKS FOR #{app_env} APP #{app_name}"
			
			current_app_stackname = current_stack_name
			
			cloudformation = AWS::CloudFormation.new
			
			cloudformation.stacks.each do |stack|
				puts " # checking #{stack.name}"
				if (stack.name == current_app_stackname)
					puts " # # leaving #{stack.name}. (This is the current stack)"
				elsif (stack.name.include? "#{app_env}") && (stack.name.include? "#{app_name}")
					puts " # # DELETING stack: #{stack.name}"
					stack.delete
					puts " # # Delete sent!"
				elsif
					puts " # # leaving #{stack.name}. (This stack isn't my responsibility)"
				end
			end
		end
 
		private
 
		def current_stack_name
			return "#{@stack_name}".gsub(".", "-")
		end
	end
 
	class EBDeployer
		require 'aws-sdk'
 
		def initialize(options = {
				:app_name => "default",
				:environment_name => "dev"
			})
			@app_name = options[:app_name]
			@app_environment = options[:environment_name]
 
			if (options[:access_key_id] == nil || options[:access_key_id] == '')
				raise "access_key_id cannot be empty or nil"
			end
			if (options[:secret_access_key] == nil || options[:secret_access_key] == '')
				raise "secret_access_key cannot be empty or nil"
			end
			@access_key_id = options[:access_key_id]
			@secret_access_key = options[:secret_access_key]
		end
 
		def update_application(version, source_bundle, option_settings = [])
			beanstalk = AWS::ElasticBeanstalk.new(
				:access_key_id => @access_key_id,
				:secret_access_key => @secret_access_key)
 
			application_versions = beanstalk.client.describe_application_versions({
				:application_name => @app_name,
				:version_labels => [version]
				})
 
			if (application_versions.application_versions.length == 0)
				version_response = beanstalk.client.create_application_version({
					:application_name => @app_name,
					:version_label => version,
					:source_bundle => {
						:s3_bucket => source_bundle[:s3_bucket],
						:s3_key => source_bundle[:s3_key]
					},
					:auto_create_application => true
					})
			end
 
			beanstalk.client.update_environment({
				:environment_name => @app_environment,
				:version_label => version,
				:option_settings => option_settings
				})
		end
	end
end