require 'mongo'

class Database
  def self.companies
    @@connection.db(@@database_name).collection("companies")
  end

  def self.zip_codes
    @@connection.db(@@database_name).collection("zip_codes")
  end

  def self.configure(env = :development)
    if env == :development
      uri = "mongodb://localhost/beautiful_savings"
    else
      uri = ENV['COUPONS5INDY_MONGODB_URI']
    end

    # Not lazy = bad.
    # I'm lazy = bad.
    parser = Mongo::URIParser.new uri
    @@connection = parser.connection({})
    @@database_name = uri[%r{/([^/\?]+)(\?|$)}, 1]
  end
end