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
require_relative '../database.rb'
require_relative '../app_helpers.rb'

ROOT_URL = "http://www.coupons4indy.com/"

start = Time.now

# Configure the Mongo connection
Database.configure :development

Database.companies.remove
Database.errors.remove

Processor.new.process_all

finish = Time.now

# Done!
puts "Done in #{finish - start} seconds"