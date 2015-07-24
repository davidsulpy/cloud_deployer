#Cloud Deployer Ruby Module

This is an opinionated wrapper for deploying applications to AWS cloud infrastructure. It provides services and helpers for basic tasks in order to aid rake scripts in pushing deployment packages to s3, bootstrapping and deploying CloudFormation templates, creating and/or updating CloudFormation stacks, managing Route53 DNS records, purging CloudFront caches, and HealthChecking endpoints to ensure new version is running.

##Dependencies
`gem 'aws-sdk', '~> 2'`

> NOTE: gem 'net/http' is also required but only for the EndpointHealthchecker

More README with examples to come...