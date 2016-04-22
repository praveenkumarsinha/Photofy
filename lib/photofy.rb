require 'photofy/dummy_s3methods'
require 'photofy/core'
require 'tempfile'
begin
  require "rmagick"
rescue Exception => e
  puts "Unable to load 'RMagick' for any image manipulations methods"
end

module Photofy
  def self.included(base)
    base.extend(DummyS3Methods)
    base.extend(Core)
  end
end

ActiveRecord::Base.send(:include, Photofy)
