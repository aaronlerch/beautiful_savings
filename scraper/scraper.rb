#!/usr/bin/ruby
# encoding: utf-8

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative './processor.rb'
require_relative '../db_config.rb'

ROOT_URL = "http://www.coupons4indy.com/"

# Configure the Mongo connection
Configurator.development

companies = Processor.new.process_all

puts "Retrieved #{companies.count} companies!"