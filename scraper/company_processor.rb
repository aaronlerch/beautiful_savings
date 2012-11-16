# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'
require_relative '../models.rb'
require_relative './coupon_processor.rb'

class CompanyProcessor
  def self.process_url_of_companies(full_url, process_paging = false)
    all_companies = []
    begin
      return all_companies if !Helpers.instance.should_process(full_url)
      page = Hpricot(Helpers.instance.sanitize_contents(open(full_url).read))

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
        companies = process_page_script(paging_script)
      end

      all_companies.concat companies
    rescue Exception => ex
      Helpers.instance.write_error "Error accessing #{full_url}, continuing", ex
    end

    return all_companies
  end

  def self.process_page_script(page_script)
    # Fun times, parse the start and end pages and then
    # iterate over the entire set and grab all companies

    all_sub_companies = []

    page_script.gsub! "document.write(\"", ""
    page_script.gsub! "\");$", ""
    links = Hpricot(Helpers.instance.sanitize_contents(page_script)).search('a')
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

  def self.process_company_page(page)
    companies = []
    list_items = page.search('div.lpsyslistall div.cgeyixcacaidb')
    list_items.each do |list_item|
      company = Company.new
      
      title = list_item.search('h2.diruptitle a').first
      company.name = title.inner_text
      company.source_url = "#{ROOT_URL}#{title.get_attribute(:href)}"

      # Get the link to the coupon page
      coupon_link = list_item.search('a[@href^="acctcoupons"]').first
      if !coupon_link.nil?
        company.coupon_list_url = "#{ROOT_URL}#{coupon_link.get_attribute(:href)}"
      end

      address_area = list_item.search('span.dirupheader')
      address_items = address_area.search('font')
      company.full_address = address_items[0].inner_text
      company.phone_number = address_items[1].inner_text

      company.description = list_item.search('span.dirupheader + div').inner_text
      company.coupons = []
      CouponProcessor.process_coupons_for_company(company)
      puts "Processed #{company.coupons.count} coupons for company #{company.name}"
      companies << company
    end
    return companies
  end
end