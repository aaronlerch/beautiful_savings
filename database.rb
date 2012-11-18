require 'mongo'

class Database
  def self.connection
    @@connection
  end

  def self.collection
    connection.db(@@database_name).collection("companies")
  end

  def self.configure(env = :development)
    if env == :development
      uri = "mongodb://localhost/beautiful_savings"
    else
      uri = ENV['COUPONS5INDY_MONGODB_URI']
    end

    # Not lazy = bad.
    parser = Mongo::URIParser.new uri
    @@connection = parser.connection({})
    @@database_name = uri[%r{/([^/\?]+)(\?|$)}, 1]
  end
end