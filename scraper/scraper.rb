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

ROOT_URL = "http://www.coupons4indy.com/"

# TODO: record how long this script takes to run, and spit it out at the end

# Configure the Mongo connection
Database.configure :development

companies = Processor.new.process_all
puts "Retrieved #{companies.count} companies - storing"

# Clear the existing collection, and recreate it
Database.collection.remove

# Add each company
companies.each do |c|
  Database.collection.insert c
end

# Done!
puts "Done!"