##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy
 
	class EBDeployer
		#gem 'aws-sdk', '< 2.0.0'
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