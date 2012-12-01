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
    def pre_process_query
      return if params[:lat].to_f != 0 and params[:lng].to_f != 0
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

    def search
      pre_process_query
      query = build_indexden_query params[:q]
      search_options = { 
        #:start => page * RESULTS_PAGE_SIZE, 
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
=begin
Example return result:

["matches", "184"]<br />["query", "name:a*^3 OR text:a^1"]<br />["search_time", "0.004"]<br />["results", [{"docid"=>"50b3f78dd7730010f4000025", "query_relevance_score"=>"4508"}, {"docid"=>"50b3f71bd7730010f4000010", "query_relevance_score"=>"4490"}, {"docid"=>"50b3f711d7730010f400000f", "query_relevance_score"=>"4490"}, {"docid"=>"50b3f721d7730010f4000011", "query_relevance_score"=>"4490"}, {"docid"=>"50b3f702d7730010f400000c", "query_relevance_score"=>"4489"}, {"docid"=>"50b3f791d7730010f4000026", "query_relevance_score"=>"4489"}, {"docid"=>"50b3f707d7730010f400000d", "query_relevance_score"=>"4488"}, {"docid"=>"50b3f70bd7730010f400000e", "query_relevance_score"=>"4488"}, {"docid"=>"50b3f6f9d7730010f400000a", "query_relevance_score"=>"4488"}, {"docid"=>"50b3f6fdd7730010f400000b", "query_relevance_score"=>"4488"}]]
=end
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
    slim :index
  end

  get '/search' do
    redirect(to('/')) if !params[:q]
    @companies = search
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