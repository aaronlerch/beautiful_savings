require 'bundler'
Bundler.require
require 'sinatra/content_for2'
require_relative './database.rb'

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)

  configure do
    Database.configure :production
  end

  helpers Sinatra::ContentFor2

  helpers do
    def pre_process_query
      return if params[:lat].present? and params[:lng].present?
      matchdata = /\b(\d{5})\b/.match params[:q]
      return if !matchdata || !matchdata.captures.any?
      zip = matchdata.captures[0]
      coords = get_zip_coords zip
      return if coords == [0,0]
      params[:lat] = coords[0]
      params[:lng] = coords[1]
      params[:q] = params[:q].sub zip, ''
    end

    def get_zip_coords(zip)
      zip_doc = Database.zip_codes.find_one({"_id" => zip})
      return zip_doc["coords"] if zip_doc

      loc = Geocoder.search(zip)
      if loc && loc.any?
        coords = [loc.first.data["geometry"]["location"]["lat"], loc.first.data["geometry"]["location"]["lng"]]
      else
        # Persist something invalid, so we don't hit Geocoder every time
        coords = [0,0]
      end

      Database.zip_codes.save({"_id" => zip, :coords => coords})
      coords
    end

    def get_query
      pre_process_query
      query = params[:q]
      tokens = query.gsub(/'/, "\\\\'").shellsplit
      tokens.each { |token| token.downcase! }
      #Database.companies.find({:search => { "$in" => tokens }})
    end
  end

  get '/' do
    slim :index
  end

  get '/search' do
    redirect(to('/')) if !params[:q]
    query = get_query
    slim :search
  end

  get '/company/:slug' do
    @company = Database.companies.find_one({:slug => params[:slug]})
    slim :company
  end

  get '/autocomplete' do
    halt(400) if !params[:query]
    
    query_regexp = Regexp.new "^#{params[:query].downcase}"
    companies = Database.companies.find({:normalized_name => query_regexp}, 
      {
        :limit => 10,
        :fields => ["name", "slug"]
      }).to_a

    content_type :json
    result = {
      :lat => params[:lat],
      :lng => params[:lng],
      :query => params[:query],
      :suggestions => []
    }
    
    return result.to_json if companies.empty?
    
    companies.each do |c|
      result[:suggestions].push({
        :label => c["name"],
        :value => "/company/#{c["slug"]}"
      })
    end
    result.to_json
  end

end