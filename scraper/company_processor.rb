# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'
require_relative './coupon_processor.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

class CompanyProcessor
  def self.process_url_of_companies(full_url, process_paging = false)
    begin
      return if !Helpers.instance.should_process(full_url)
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
        process_company_page(page, full_url)
      else
        process_page_script(paging_script, full_url)
      end
    rescue Exception => ex
      Helpers.instance.write_error "Error accessing url", ex, :url => full_url
    end
  end

  def self.process_page_script(page_script, full_url)
    begin
      # Fun times, parse the start and end pages and then
      # iterate over the entire set and grab all companies
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
        process_url_of_companies("#{ROOT_URL}#{base_url}#{num*10}")
      end
    rescue Exception => ex
      Helpers.instance.write_error "Error processing the paging script from a url", ex, :url => full_url, :script => page_script
    end
  end

  def self.process_company_page(page, full_url)
    list_items = page.search('div.lpsyslistall div.cgeyixcacaidb')

    list_items.each_with_index do |list_item, index|
      company = {}

      begin
        title = list_item.search('h2.diruptitle a').first

        if title.nil?
          raise "No title parsed for list_item #{index}!"
        end

        company[:name] = title.inner_text.strip
        company[:source_url] = "#{ROOT_URL}#{title.get_attribute(:href)}"

        # Get the link to the coupon page, trying the two variations we've seen
        coupon_link = list_item.search('a[@href*="coupon"]').first

        if !coupon_link.nil?
          company[:coupon_list_url] = "#{ROOT_URL}#{coupon_link.get_attribute(:href)}"
        end

        address_area = list_item.search('span.dirupheader')
        address_items = address_area.search('font')
        
        if address_items.count > 0
          company[:full_address] = address_items[0].inner_text.strip
        end
        
        if address_items.count > 1
          company[:phone_number] = address_items[1].inner_text.strip
        end
        
        description_element = list_item.search('span.dirupheader + div').first

        if !description_element.nil?
          company[:description] = description_element.inner_text.strip
        end

        company[:slug] = company[:name].to_slug
        
        CouponProcessor.process_coupons_for_company(company)

        # Try to find an existing company with the same slug - if so,
        # remove it and insert this one instead - and flag the issue. There
        # can be a few reasons for this, so it's not terrible, just inefficient.
        duplicate_count = Database.companies.find("slug" => company[:slug]).count
        if duplicate_count > 0
          Database.companies.remove("slug" => company[:slug])
          Database.errors.insert({ :message => "Duplicate companies with the slug '#{company[:slug]}' were found" })
          puts "Duplicates found for '#{company[:name]}'"
        end

        Database.companies.insert company
      rescue Exception => ex
        Helpers.instance.write_error "Error retrieving company information", ex, :url => full_url
      end
    end
  end
end