require 'bundler'
Bundler.require

class App < Sinatra::Base
  set :root, File.dirname(__FILE__)

  register Sinatra::AssetPack

  assets {
    serve '/js',     from: 'assets/js'
    serve '/css',    from: 'assets/css'
    serve '/images', from: 'assets/images'

    # The second parameter defines where the compressed version will be served.
    # (Note: that parameter is optional, AssetPack will figure it out.)
    js :app, '/js/app.js', [
      '/js/vendor/bootstrap.min.js',
      '/js/vendor/**/*.js',
      '/js/app/**/*.js'
    ]

    css :app, '/css/app.css', [
      '/css/base.css',
    ]
  }

  configure :development do
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