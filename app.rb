require 'bundler'
Bundler.require
require 'shellwords'
require 'sinatra/content_for2'
require_relative './database.rb'

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :results_page_size, 10

  configure do
    Database.configure :production
    search_api ||= IndexTank::Client.new ENV['BEAUTIFULSAVINGS_INDEXDEN_URI']
    search_index ||= search_api.indexes "beautiful_savings"
    set :search_index, search_index
  end

  helpers Sinatra::ContentFor2

  helpers do
    def distance_to?(company)
      params[:lat].to_f != 0 && params[:lng].to_f != 0 && company.has_key?("lat") && company.has_key?("lng")
    end

    def distance_to(company)
      from = [params[:lat].to_f, params[:lng].to_f]
      to = [company["lat"].to_f, company["lng"].to_f]
      Geocoder::Calculations.distance_between(from, to, { :units => :mi }).round(1)
    end

    def next_page
      @page + 2
    end

    def pre_process_query
      return if params[:lat].to_f != 0 and params[:lng].to_f != 0
      matchdata = /\b(\d{5})\b/.match params[:q]
      return if !matchdata || !matchdata.captures.any?
      zip = matchdata.captures[0]
      coords = get_zip_coords zip
      return if coords == [0,0]
      params[:lat] = coords[0]
      params[:lng] = coords[1]
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

    def search
      pre_process_query
      query = build_indexden_query params[:q]
      page = params[:page].to_i
      page = page - 1 if page > 0
      search_options = { 
        :start => page * options.results_page_size, 
        :len => options.results_page_size, 
        :function => 1
      }

      lat = params[:lat].to_f
      lng = params[:lng].to_f
      if lat != 0 && lng != 0
        search_options[:variables] = { 0 => lat, 1 => lng }
        search_options[:function] = 2
      end

      result = options.search_index.search(query, search_options)
      matches = result["matches"].to_i
      offset = (page * options.results_page_size) + result["results"].count
      has_more = matches != 0 && (offset < matches)
      ids = result["results"].map { |doc| BSON::ObjectId(doc["docid"]) }
      companies = Database.companies.find({"_id" => { "$in" => ids }}).to_a
      [matches, page, has_more, companies]
    end

    def build_indexden_query(query)
      return "match:all" if query.strip.empty?

      # Escape single quotes. Might miss a few cases where people
      # use single quotes instead of double, but oh well
      list = query.gsub(/'/, "\\\\'").shellsplit
      criteria_query = ""
      list.each do |token|
        criteria_query += " OR " if criteria_query.length > 0

        token_prefix = token + "*"
        token_full = token

        if token =~ /\s/
          # If the token has a string, don't do a prefix search on it, because we can't
          # and IndexTank barfs a bit.
          token_prefix = "\"#{token_full}\""
          token_full = "\"#{token_full}\""
        end

        criteria_query += "name:#{token_prefix}^3 OR text:#{token_full}^1"
      end

      criteria_query
    end
  end

  get '/' do
    slim :index, :layout => :home_layout
  end

  get '/wtf' do
    slim :about
  end

  get '/search' do
    redirect(to('/')) if !params[:q] || params[:q].empty?
    
    company = Database.companies.find_one({:name => params[:q]})
    redirect(to("/company/#{company["slug"]}")) if company

    @matches, @page, @has_more, @companies = search
    redirect(to("/company/#{@companies[0]["slug"]}")) if @companies.count == 1
    slim :search
  end

  get '/company/:slug' do
    @company = Database.companies.find_one({:slug => params[:slug]})
    slim :company
  end

  get '/autocomplete' do
    halt(400) if !params[:query] || params[:query].empty?
    
    query_regexp = Regexp.new "^#{params[:query].downcase}"
    companies = Database.companies.find({:normalized_name => query_regexp}, 
      {
        :limit => 10,
        :fields => ["name", "slug"]
      }).to_a

    content_type :json
    results = companies.map { |c| { :name => c["name"], :url => "/company/#{c["slug"]}" } }
    results.to_json
  end

end