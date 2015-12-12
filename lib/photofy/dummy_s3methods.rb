module Photofy

  module DummyS3Methods
    def self.extended(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      def s3_connected?
        self.class.s3_connected?
      end
    end

    def s3_connected?
      false
    end
  end

end