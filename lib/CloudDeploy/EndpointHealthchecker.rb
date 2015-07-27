##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################


require 'net/http'

module CloudDeploy
	class HttpHealthCheck
		def initialize(options = {
				health_attempts: 25,
				notify_teamcity: true,
				sleep: "linear",
				version_header: nil,
				debug: true,
			})
			@sleep_calc = options[:sleep]
			@use_teamcity = options[:notify_teamcity]
			@health_attempts = options[:health_attempts]
			@debug = options[:debug]
			@version_header = options[:version_header]
		end

		def check_health(full_endpoint, new_version = nil)
			if @notify_teamcity; puts "##teamcity[blockOpened name='healthchecking']" end

			puts "Starting health check"

			health_attempts = @health_attempts
			sleep_time = 2
			while (health_attempts > 0)
				url = full_endpoint.gsub("https://", "http://")

				if @debug; puts "    DEBUG: checking #{url}" end

				begin
					url = URI.parse(url)
					res = Net::HTTP.get_response(url)
					if (res.code == "200")
						puts "#{url} healthy!"
						if (@version_header != nil && new_version != nil)
							puts "    DEBUG: checking for version #{new_version}"
							if (res['X-IS-Version'] == new_version)
								puts "#{new_version} found! Success!"
								break
							else
								puts "still looking for version, current: #{res['X-IS-Version']}"
							end
						else
							break
						end
					end
				rescue Exception => ex
					if res != nil
						if @debug; puts "    DEBUG: code #{res.code}" end
					end
					if @debug; puts "    DEBUG: #{ex.message} (#{url})" end
				end
				puts "  still checking #{url} health (#{health_attempts} more attempts left, sleeping #{sleep_time} seconds)"
				sleep sleep_time

				if @sleep_calc == "linear"; sleep_time = sleep_time * 2 end

				if sleep_time > 120; sleep_time = 120 end 
				health_attempts = health_attempts - 1
			end
			if @notify_teamcity; puts "##teamcity[blockClosed name='healthchecking']" end
		end
	end
end