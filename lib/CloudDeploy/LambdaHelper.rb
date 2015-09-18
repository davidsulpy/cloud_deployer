##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class LambdaHelper
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'

		def initialize(options = {})
			@app_name = options[:app_name]

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
				region: options[:region] || 'us-east-1'
				})
		end

		def create_or_update_function(options = {})
			lambda = Aws::Lambda::Client.new()

			function_exists = false
			begin
				resp = lambda.get_function({
					function_name: options[:function_name]
					})
				if (resp.configuration.function_name == options[:function_name])
					function_exists = true
				end
			rescue => error
				puts "#{error}"
			end

			if (function_exists)
				begin
					lambda.update_function_code({
						function_name: options[:function_name],
						s3_bucket: options[:code][:s3_bucket],
						s3_key: options[:code][:s3_key]
						})
				rescue => error
					puts "failed to update the existing functions code: #{error}"
					raise error
				end

				begin
					lambda.update_function_configuration({
						function_name: options[:function_name],
						role: options[:role],
						handler: options[:handler],
						description: options[:description],
						timeout: options[:timeout],
						memory_size: options[:memory_size]
						})
				rescue => error
					puts "failed to update the existing functions configuration: #{error}"
					raise error
				end

				puts "Finished updating the function"
			else
				begin
					lambda.create_function(options)
				rescue => error
					puts "Failed to create the function: #{error}"
					raise error
				end

				puts "Finished creating the function"
			end
		end
	end
end