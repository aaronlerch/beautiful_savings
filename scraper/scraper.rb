require_relative './processor.rb'
require_relative '../db_config.rb'

# Configure the Mongoid connection
Configurator.development

companies = Processor.new.process_all