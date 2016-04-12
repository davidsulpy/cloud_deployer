##########################################
# Author: David Sulpy (david@sulpy.com)  #
# License: MIT                           #
##########################################

module CloudDeploy

	class StaticWebsiteDeployer
		gem 'aws-sdk', '>= 2.0.0'
		require 'aws-sdk'
		require 'json'
 
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


		def create_or_update(asset_dir, options)
			domain = options[:domain]

			web_config_file_loc = options[:web_config_json_location]
			web_config_file = File.read(web_config_file_loc)
			web_config = JSON.parse(web_config_file, :symbolize_names => true)

			create_static_web_s3_bucket(domain, web_config)

			upload(asset_dir, domain)

		end

		def create_static_web_s3_bucket(bucket_name, website_configuration)
			puts "Creating s3 bucket #{bucket_name} in region #{Aws.config[:region]}"

			s3client = Aws::S3::Client.new

			bucket_exists = false
			begin
				resp = s3client.head_bucket({
					bucket: bucket_name
					})
				puts "bucket exists"
				bucket_exists = true
			rescue
				puts "bucket doesn't exist"
			end

			if (!bucket_exists)
				begin
					resp = s3client.create_bucket({
						acl: "public-read",
						bucket: bucket_name
						})
				rescue
					puts "error creating bucket"
					raise
				end
			end

			begin
				resp = s3client.put_bucket_website({
						bucket: bucket_name,
						website_configuration: website_configuration
					})
			rescue
				puts "error setting up website"
				raise
			end

		end

		# this method was adapted from a class provided by Avi Tzurel http://avi.io/blog/2013/12/03/upload-folder-to-s3-recursively/
	    def upload(folder_path, bucket_name, thread_count = 5)
			s3client = Aws::S3::Client.new

			files = Dir.glob("#{folder_path}/**/*")
			total_files = files.length
			file_number = 0
			mutex       = Mutex.new
			threads     = []

			thread_count.times do |i|
			threads[i] = Thread.new {
				until files.empty?
				mutex.synchronize do
					file_number += 1
					Thread.current["file_number"] = file_number
				end
				file = files.pop rescue nil
				next unless file

				# I had some more manipulation here figuring out the git sha
				# For the sake of the example, we'll leave it simple
				#
				path = file

				puts "[#{Thread.current["file_number"]}/#{total_files}] uploading..."

				data = File.open(file)

				next if File.directory?(data)
				key = file[folder_path.length+1..-1]
				content_length = File.size(file)
				mime = "text/plain"
				ext = File.extname(file)
				if (ext == ".html" || ext == ".htm")
					mime = "text/html"
				elsif (ext == ".css")
					mime = "text/css"
				elsif (ext == ".js")
					mime = "text/javascript"
				elsif (ext == ".svg")
					mime = "image/svg+xml"
				else
					mime = `file --mime --brief #{file}`.strip
				end

				s3client.put_object({
						acl: "public-read",
						bucket: bucket_name,
						body: data,
						key: key,
						content_type: mime
					})
				end
			}
			end
			threads.each { |t| t.join }
			end
	end

end