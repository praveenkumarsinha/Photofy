require 'singleton'
require 'aws-sdk'

module Photofy

  class S3Setting
    include Singleton

    attr_accessor :s3_setup
    attr_accessor :s3_bucket
  end

  module S3Methods
    def self.extended(base)
      base.include(InstanceMethods)
    end

    module InstanceMethods
      def s3_connected?
        self.class.s3_connected?
      end

      def s3_bucket
        S3Setting.instance.s3_bucket
      end
    end

    def s3_connected?
      (S3Setting.instance.s3_bucket.class == AWS::S3::Bucket)
    end

    #Enables aws s3 as backend storage.
    #Takes two arguments:
    #1. aws_settings. Hash with access_key_id and secret_access_key from aws s3
    #2. instance_settings. Hash with bucket as valid aws s3 bucket to be
    #
    #Example usage:
    #photofy_s3_storage({access_key_id: 'xxxxxxxx',secret_access_key: 'xxxxxxxx'}, {bucket: 'test_bucket'})
    def photofy_s3_storage(aws_settings = {}, instance_settings = {})
      instance_settings[:bucket] ||= 'photofy'
      (S3Setting.instance.s3_setup ||= {}).merge!(aws_settings: aws_settings, instance_settings: instance_settings)

      try_connect
    end

    def try_connect
      if try_accessing_existing_awsconfig
        setup_bucket
      else
        begin
          AWS.config(S3Setting.instance.s3_setup[:aws_settings])
          setup_bucket
        rescue AWS::Errors::MissingCredentialsError => e
          puts 'Photofy:S3: AWS credentials not provided.'
          puts e.message
        rescue AWS::S3::Errors::SignatureDoesNotMatch => e
          puts 'Photofy:S3: AWS credentials is most probably not correct.'
          puts e.message
        end
      end
    end

    def setup_bucket
      s3 = AWS::S3.new
      _bucket_name = S3Setting.instance.s3_setup[:instance_settings][:bucket]
      S3Setting.instance.s3_bucket = if s3.buckets.collect { |x| x.name }.include?(_bucket_name)
                                       s3.buckets[_bucket_name]
                                     else
                                       s3.buckets.create(_bucket_name)
                                     end
      S3Setting.instance.s3_bucket
    end

    def try_accessing_existing_awsconfig
      begin
        setup_bucket
      rescue AWS::Errors::MissingCredentialsError => e
        puts 'Photofy:S3: No existing aws config found.'
        return false
      end
      true
    end

  end
end