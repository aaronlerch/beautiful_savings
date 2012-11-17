# encoding: utf-8

require_relative './company_processor.rb'
require_relative './helpers.rb'
require 'open-uri'
require 'hpricot'

class Processor
  def process_all
    categories = {}
    directory_url = "#{ROOT_URL}Site.Directories.html"

    puts "Processing categories"

    begin
      category_html = Hpricot(Helpers.instance.sanitize_contents(open(directory_url).read))
    rescue Exception => ex
      abort(Helpers.get_error_string("Error accessing site directory at #{directory_url}", ex))
    end

    category_html.search('td.dirparcats a').each do |cat_link_html|
      cat_url = cat_link_html.get_attribute(:href)
      cat_text = cat_link_html.inner_text
      categories[cat_text] = cat_url
    end

    puts "Found #{categories.length} categories, processing"

    process_categories(categories)
  end

  def process_categories(category_hash)
    all_companies = []

    puts "Using category 'Automobile' for TESTING only!!"
    category_hash = { "Automobile" => "Directory-pc13444.11312-Automobile.html" }

    category_hash.each do |name, url|
      companies = CompanyProcessor.process_url_of_companies("#{ROOT_URL}#{url}", true)
      all_companies.concat companies
    end

    return all_companies
  end
end