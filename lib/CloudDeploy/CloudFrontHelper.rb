##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class CloudFrontHelper
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

			@cf_distro_id = options[:cf_distro_id]
			@code_version = options[:code_version]
		end
 
		def invalidate(path, wait=false)
			if (@cf_distro_id == nil || @cf_distro_id == '')
				raise "cf_distro_id needs to be provided in constructor"
			end

			cf = Aws::CloudFront.new

			resp = cf.client.create_invalidation({
					:distribution_id => @cf_distro_id,
					:invalidation_batch => {
						:paths => {
							:quantity => 1,
							:items => [path]
						},
						:caller_reference => @code_version
					}
				})

			if (wait)
				cf.client.wait_until(:invalidation_completed, {
					:distribution_id => @cf_distro_id,
					:id => resp.invalidation.id
					}) do |w|

					w.before_attempt do |n|
	 					puts "	# waiting for invalidation to complete (attempt #{n})"
	 				end
				end

			end

		end
	end

end