# encoding: utf-8

require_relative './processor.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

ROOT_URL = "http://www.coupons4indy.com/"

start = Time.now

# Configure the Mongo connection
Database.configure :development

# Clear all previous errors
Database.errors.remove

# Flag all existing companies as stale
Database.companies.update({}, { "$set" => { "stale" => true } }, { :multi => true })

Processor.new.process_all

# Remove all still-stale companies (meaning they don't exist anymore)
Database.companies.remove({ "stale" => true })

finish = Time.now

# Done!
puts "Done in #{finish - start} seconds"