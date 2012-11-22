# encoding: utf-8

require 'geocoder'
require_relative './helpers.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

# Configure the Mongo connection
Database.configure :development

companies = Database.companies.find({ "full_address" => { "$exists" => true }})
total = processed = 0

companies.each do |company|
  begin
    total = total + 1
    result = Geocoder.search(company["full_address"]).first
    next if result.nil? || !result.data.has_key?("geometry")
    company[:lat] = result.data["geometry"]["location"]["lat"]
    company[:lng] = result.data["geometry"]["location"]["lng"]
    Database.companies.save company
    processed = processed + 1
  rescue Exception => ex
    Helpers.instance.write_error "Error geocoding", ex, :company_name => company_name, :address => company["full_address"]
  end
end

puts "#{processed} companies geocoded (out of #{total} total)"