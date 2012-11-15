# encoding: utf-8

require_relative '../models.rb'
require 'open-uri'
require 'hpricot'

class Processor

  ROOT_URL = "http://www.coupons4indy.com/"

  def initialize
    # Used to prevent accidentally requesting the same URL multiple times
    @processed_urls = {}
  end

  def write_error(message, ex)
    puts "#{message}:\n#{ex.message}\n\n#{ex.backtrace}\n"
  end

  def sanitize_contents(contents)
    contents.encode!('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
    contents.encode!('UTF-8', 'UTF-16')
  end

  def process_all
    categories = {}
    directory_url = "#{ROOT_URL}Site.Directories.html"

    puts "Processing categories"

    begin
      category_html = Hpricot(sanitize_contents(open(directory_url).read))
    rescue Exception => ex
      write_error "Error accessing site directory at #{directory_url}", ex
      exit
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

    category_hash.each do |name,url|
      # Process each url of companies, expanding out paging
      companies = process_url_of_companies("#{ROOT_URL}#{url}", true)
      all_companies.concat companies
    end

    return all_companies
  end

  def process_url_of_companies(full_url, process_paging = false)
    all_companies = []
    begin
      return [] if !should_process(full_url)
      page = Hpricot(sanitize_contents(open(full_url).read))

      paging_script = nil
      if process_paging
        # If we have paging, process each page, otherwise
        # process just this one page
        page.search('div.cbghpgcicajge script').each do |script|
          if script.inner_text =~ /lpsysresalltop/
            paging_script = script.inner_text
            break
          end
        end
      end

      if paging_script.nil?
        companies = process_company_page(page)
      else
        companies = process_pages(paging_script)
      end

      all_companies.concat companies
    rescue Exception => ex
      write_error "Error accessing #{full_url}, continuing", ex
    end
    return all_companies
  end

  def process_company_page(page)
    companies = []
    list_items = page.search('div.lpsyslistall div.cgeyixcacaidb')
    list_items.each do |list_item|
      company = Company.new
      
      title = list_item.search('h2.diruptitle a').first
      company.name = title.inner_text
      company.source_url = "#{ROOT_URL}#{title.get_attribute(:href)}"

      address_area = list_item.search('span.dirupheader')
      address_items = address_area.search('font')
      company.full_address = address_items[0].inner_text
      company.phone_number = address_items[1].inner_text

      company.description = list_item.search('span.dirupheader + div').inner_text
      process_company company
      puts "Processed company " + company.name
      companies << company
    end
    return companies
  end

  def process_pages(page_script)
    # Fun times, parse the start and end pages and then
    # iterate over the entire set and grab all companies

    all_sub_companies = []

    page_script.gsub! "document.write(\"", ""
    page_script.gsub! "\");$", ""
    links = Hpricot(sanitize_contents(page_script)).search('a')
    first_url = links.first.get_attribute(:href)
    last_text = links.last.inner_text
    if last_text == "»"
      last_url = links[links.count-3].get_attribute(:href)
    elsif last_text == "›"
      last_url = links[links.count-2].get_attribute(:href)
    else
      last_url = links.last.get_attribute(:href)
    end

    # Now we have the first and last pages, calculate all intermediate pages and process them
    # use this: last_url.match /[0-9]+$/ to find the last number in the URL, which is the last page
    matches = last_url.match /^(.*?)([0-9]+)$/
    base_url = matches[1]
    max_skip_records = matches[2].to_i

    # Loop over each 10 pages
    (0..max_skip_records/10).each do |num|
      # Process this company url, ignoring any paging controls on the page
      companies = process_url_of_companies("#{ROOT_URL}#{base_url}#{num*10}")
      all_sub_companies.concat companies
    end

    return all_sub_companies
  end

  def process_company(company)
    coupons = []
    return coupons
  end

  def should_process(url)
    canonical_url = url.downcase
    if @processed_urls.has_key? canonical_url
      false
    else
      @processed_urls[canonical_url] = true
      true
    end
  end

end