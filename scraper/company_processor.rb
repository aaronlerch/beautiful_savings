# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'
require_relative './coupon_processor.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

class CompanyProcessor
  def self.process_company_url_and_name(url, company_name)
    begin
      company = {}
      company_html = Hpricot(Helpers.instance.sanitize_contents(open(url).read))

      company[:name] = company_name
      company[:source_url] = url

      # Get the link to the coupon page, trying the two variations we've seen
      coupon_link = company_html.search('div#listing0 a[@href^="coupon"]').first

      if coupon_link.nil? or coupon_link.empty?
        coupon_link = company_html.search('div#listing0 a[@href^="acctcoupon"]').first
      end

      if coupon_link.nil? or coupon_link.empty?
        # Handle a different case for the URL. Le sigh.
        coupon_link = company_html.search('div#listing0 a[@href^="AcctCoupon"]').first
      end

      if !coupon_link.nil? and !coupon_link.empty?
        company[:coupon_list_url] = "#{ROOT_URL}#{coupon_link.get_attribute(:href)}"
      else
        raise "There is no coupon link for this company"
      end

      address_area = company_html.search('span.dirupheader')
      address_items = address_area.search('font')
      
      if address_items.count > 0
        company[:full_address] = address_items[0].inner_text.strip
      end
      
      if address_items.count > 1
        company[:phone_number] = address_items[1].inner_text.strip
      end
      
      description_element = company_html.search('span.dirupheader + div').first

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
      Helpers.instance.write_error "Error retrieving company information for '#{company_name}'", ex, :url => url, :company_name => company_name
    end
  end
end