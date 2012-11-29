require 'bundler'
Bundler.require
require_relative './database.rb'

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)

  configure do
    Database.configure :production
  end

  helpers do
  end

  get '/' do
    slim :index
  end

  get '/search' do
    slim :search
  end

  get '/autocomplete' do
    content_type :json
    result = {
      :query => params[:query],
      :suggestions => []
    }
    return result.to_json if !params[:query]
    query_regexp = Regexp.new "^#{params[:query].downcase}"
    companies = Database.companies.find({:normalized_name => query_regexp}, 
      {
        :limit => 10,
        :fields => ["name", "slug"]
      }).to_a
    return result.to_json if companies.empty?
    companies.each do |c|
      result[:suggestions].push({
        :label => c["name"],
        :value => "/company/#{c["slug"]}"
      })
    end
    result.to_json
  end

  get '/company/:slug' do
    company = Database.companies.find({:slug => params[:slug]})
    slim :company, :locals => { :company => company }
  end

end