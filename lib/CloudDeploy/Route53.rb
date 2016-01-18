##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class Route53
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'
		@hosted_zone_name = ""
		def initialize(options = {
			:region => 'us-east-1'
			})
			@hosted_zone_name = options[:hosted_zone_name]
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

		def update_dns_alias(dns_name, new_alias, hosted_zone_name = "")
			if (hosted_zone_name != "")
				@hosted_zone_name = hosted_zone_name
			end

			# make sure there is no protocol indicator on the dns names
			new_alias = new_alias.sub("http://", "").sub("https://", "")
			dns_name = dns_name.sub("http://", "").sub("https://", "")

			# make sure there is a period at the end of the dns records
			if (! new_alias.end_with? ".")
				new_alias += "."
			end
			if (! dns_name.end_with? ".")
				dns_name += "."
			end
			if (! @hosted_zone_name.end_with? ".")
				@hosted_zone_name += "."
			end

			puts "Updating DNS alias for name '#{dns_name}' setting alias to '#{new_alias}'"
			r53 = Aws::Route53::Client.new

			hosted_zone = nil

			resp = r53.list_hosted_zones()

			puts "hosted zone '#{@hosted_zone_name}'"
			hosted_zone = resp.hosted_zones.find{|hz| hz.name.casecmp(@hosted_zone_name)}
			puts "hosted zone id '#{hosted_zone.id}"

			if (hosted_zone == nil)
				raise "hosted_zone_name #{@hosted_zone_name} wasn't found in Route53"
			end

			elb_client = Aws::ElasticLoadBalancing::Client.new

			resp = elb_client.describe_load_balancers()

			load_balancer = resp.load_balancer_descriptions.find{|elb| "#{elb.dns_name}.".casecmp(new_alias) == 0}

			r53.change_resource_record_sets({
				hosted_zone_id: hosted_zone.id,
				change_batch: {
					comment: "Updating Record For Deployment",
					changes: [
						{
							action: "UPSERT",
							resource_record_set: {
								name: dns_name,
								type: "A",
								alias_target: {
									hosted_zone_id: load_balancer.canonical_hosted_zone_name_id,
									dns_name: new_alias,
									evaluate_target_health: false
								}
							}
						}
					]
				}
				})

		end
	end

end