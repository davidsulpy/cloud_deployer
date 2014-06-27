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

end