require 'mongo'

class Configurator
  def self.connection
    @@connection
  end

  def self.development
    # Not lazy - bad.
    @@connection = Mongo::Connection.new("localhost", 27017, :safe => true)
  end
end