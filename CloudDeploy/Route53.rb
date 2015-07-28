##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class Route53
		gem 'aws-sdk', '< 2.0.0'
		require 'aws-sdk'
		@hosted_zone_name = ""
		def initialize(options = {})
			@hosted_zone_name = options[:hosted_zone_name]
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
			r53 = AWS::Route53.new

			hosted_zone = nil
			r53.hosted_zones.each do |zone|
				if (zone.name.casecmp(@hosted_zone_name) == 0)
					hosted_zone = zone
				end
			end

			record = hosted_zone.resource_record_sets[dns_name, 'A']

			elb = AWS::ELB.new

			load_balancer = nil
			elb.load_balancers.each do |balancer|
				dns_name = balancer.dns_name + "."

				if (dns_name.casecmp(new_alias) == 0)
					load_balancer = balancer
				end
			end

			if (record.alias_target[:dns_name].include? new_alias)
				puts "The target record already has this new alias, so no change is needed."
				return
			end

			record.alias_target = {
				:hosted_zone_id => load_balancer.canonical_hosted_zone_name_id,
				:dns_name => new_alias,
				:evaluate_target_health => false
			}

			record.update

		end
	end

end