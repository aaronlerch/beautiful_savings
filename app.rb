require 'bundler'
Bundler.require
require_relative './app_helpers'

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)

  configure :development do
    Configurator.development
  end

  configure :production do
  end

  configure do
  end

  helpers do
  end

  get '/' do
    slim :index
  end

end