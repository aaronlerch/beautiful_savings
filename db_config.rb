require 'mongoid'

class Configurator
  def self.development
    Mongoid.configure do |config|
      config.sessions = {
                          :default =>
                          {
                            :hosts => ["localhost:27017"],
                            :database => "couponsfiveindy"
                          }
                        }
    end
  end
end