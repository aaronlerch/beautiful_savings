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
  end

  get '/autocomplete' do
  end

  get '/company/:slug' do
  end

end