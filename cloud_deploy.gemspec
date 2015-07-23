Gem::Specification.new do |s|
	s.name			= 'cloud_deploy'
	s.version		= '1.1.0'
	s.date			= '2015-07-23'
	s.summary		= 'AWS Deployment Bootstrapper'
	s.description 	= 'A simple, opinionated wrapper for performing rake deployments into AWS'
	s.authors		= ["David Sulpy"]
	s.email			= 'david@sulpy.com'
	s.files			= ["lib/cloud_deploy.rb", 
						"lib/CloudDeploy/CloudFormationDeployer.rb", 
						"lib/CloudDeploy/CloudFrontHelper.rb",
						"lib/CloudDeploy/ElasticBeanstalkDeployer.rb",
						"lib/CloudDeploy/EndpointHealthchecker.rb",
						"lib/CloudDeploy/Route53.rb",
						"lib/CloudDeploy/S3Helper.rb"]
	s.homepage		= 'https://github.com/davidsulpy/cloud_deployer'
	s.license		= 'MIT'
end
