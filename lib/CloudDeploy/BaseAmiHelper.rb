##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class BaseAmiHelper
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

		def get_most_recent_base_ami()
			ec2_client = Aws::EC2::Client.new

			puts "looking for images with the name #{@app_name}-base"
			resp = ec2_client.describe_images({
				owners: ["self"],
				filters: [
					{
						name: "name",
						values: ["#{@app_name}-base*"]
					}
				]
				})

			sorted_base_amis = resp.images.sort {|a,b| b.creation_date <=> a.creation_date}

			return "#{sorted_base_amis[0].image_id}"
		end
	end
end