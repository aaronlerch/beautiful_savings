# encoding: utf-8

require_relative './company_processor.rb'
require_relative './helpers.rb'
require 'open-uri'
require 'hpricot'

class Processor
  def process_all
    categories = {}
    directory_url = "#{ROOT_URL}Site.Directories.html"

    begin
      category_html = Hpricot(Helpers.instance.sanitize_contents(open(directory_url).read))
    rescue Exception => ex
      abort("Error accessing site directory at #{directory_url}:\n\n#{ex.message}\n\n#{ex.backtrace}")
    end

    category_html.search('td.dirparcats a').each do |cat_link_html|
      cat_url = cat_link_html.get_attribute(:href)
      cat_text = cat_link_html.inner_text
      categories[cat_text] = cat_url
    end

    if categories.empty?
      abort("No categories were found ... that ain't good.")
    end

    puts "Processing #{categories.length} categories"
    #puts "Using category 'Automobile' for TESTING only!!"
    #categories = { "Automobile" => "Directory-pc13444.11312-Automobile.html" }
    categories.each do |name, suburl|
      CompanyProcessor.process_url_of_companies("#{ROOT_URL}#{suburl}", true)
    end
  end
end