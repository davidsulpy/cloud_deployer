#######
# This code was adapted from rubyzip's sample
# original https://github.com/rubyzip/rubyzip/blob/05916bf89181e1955118fd3ea059f18acac28cc8/samples/example_recursive.rb
#######

require 'zip'

# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
#   directoryToZip = "/tmp/input"
#   outputFile = "/tmp/out.zip"
#   zf = CloudDeploy::ZipFileGenerator.new(directoryToZip, outputFile)
#   zf.write()

module CloudDeploy

  class ZipFileGenerator

    # Initialize with the directory to zip and the location of the output archive.
    def initialize(config)
      @inputDir = config[:input_dir]
      @outputFile = config[:output_file]
      @patterns_to_ignore = config[:ignore]
      @verbose = config[:verbose]
    end

    # Zip the input directory.
    def write()
      entries = Dir.entries(@inputDir)
      entries.delete(".")
      entries.delete("..")
      @patterns_to_ignore.each do |pattern|
        entries.delete(pattern)
      end

      if (@verbose)
        puts "archiving these things: #{entries}"
      end

      io = Zip::File.open(@outputFile, Zip::File::CREATE);

      writeEntries(entries, "", io)
      io.close();
    end

    # A helper method to make the recursion work.
    private
    def writeEntries(entries, path, io)

      entries.each { |e|
        zipFilePath = path == "" ? e : File.join(path, e)
        diskFilePath = File.join(@inputDir, zipFilePath)
        if (@verbose)
          puts "Deflating " + diskFilePath
        end
        if  File.directory?(diskFilePath)
          io.mkdir(zipFilePath)
          subdir =Dir.entries(diskFilePath); subdir.delete("."); subdir.delete("..")
          writeEntries(subdir, zipFilePath, io)
        else
          ignore = false
          @patterns_to_ignore.each do |pattern|
            if (File.fnmatch(pattern, e))
              ignore = true
            end
          end
          if (ignore == false)
            io.get_output_stream(zipFilePath) { |f| f.puts(File.open(diskFilePath, "rb").read())}
          end
        end
      }
    end

  end
end