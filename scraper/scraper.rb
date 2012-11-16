#!/usr/bin/ruby
# encoding: utf-8

require_relative './processor.rb'
require_relative '../db_config.rb'

ROOT_URL = "http://www.coupons4indy.com/"

# Configure the Mongoid connection
Configurator.development

companies = Processor.new.process_all