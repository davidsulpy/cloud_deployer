##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class S3Helper
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'
 
		def initialize (options = {
			:region => 'us-east-1'
			})
			if (options[:access_key_id] == nil || options[:access_key_id] == '')
				raise "access_key_id cannot be empty or nil"
			end
			if (options[:secret_access_key] == nil || options[:secret_access_key] == '')
				raise "secret_access_key cannot be empty or nil"
			end
			Aws.config.update({
				credentials: Aws::Credentials.new(options[:access_key_id], options[:secret_access_key]),
				region: options[:region]
				})
		end
 
		def put_asset_in_s3(asset_location, bucket, s3_path = "", content_type = "application/zip")
			puts "Copying asset #{asset_location} to S3 bucket #{bucket}"
			s3client = Aws::S3::Client.new

			Dir.glob(asset_location) do |file_name|
				base_name = File.basename(file_name)
				remote_name = "#{base_name}"
				if (s3_path != "")
					remote_name = "#{s3_path}/#{base_name}"
				end
				puts "  # Uploading #{remote_name}"
				
				s3client.put_object({
						bucket: bucket,
						body: File.open(file_name),
						key: remote_name,
						content_type: content_type,
						content_length: File.size(file_name)
					})
			end
			puts "Finished pushing assets to S3!"
		end
	end

end