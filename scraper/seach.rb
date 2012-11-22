# encoding: utf-8

require 'indextank'
require_relative './helpers.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

Database.configure :development

api = IndexTank::Client.new "http://:ahynesyhudem@enybyj.api.indexden.com" #ENV['INDEXDEN_URL']
index = api.indexes "beautiful_savings"

puts "Resetting the indexden index"
begin
  puts "Deleting the index"
  index.delete
rescue
end

puts "Adding the new index"
index.add
while not index.running?
  sleep 0.5
end

puts "Resetting index functions"
index.functions(0, 'relevance').add
index.functions(1, 'relevance').add
index.functions(2, '-miles(q[0], q[1], d[0], d[1])').add

puts "Adding each company to the index"
Database.companies.find().each do |company|
  document = {
      :text => company["name"],
      :name => company["name"],
      :slug => company["slug"],
      :description => company["description"],
      :match => "all"
    }

  # NOTE: The "match" field is so I can issue a location/sorted search that
  # matches all results, in case a user types in just a zip code

  options = {}

  if company.has_key?("lat") and company.has_key?("lng")
    # We have a lat/long, include it as document variables
    options[:variables] = { 0 => company["lat"], 1 => company["lng"] }
  end

  index.document(company["_id"].to_s).add(document, options)
end