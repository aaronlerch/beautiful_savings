# encoding: utf-8

require 'open-uri'
require 'hpricot'
require 'geocoder'
require_relative './helpers.rb'
require_relative './coupon_processor.rb'
require_relative '../database.rb'
require_relative '../app_helpers.rb'

class CompanyProcessor
  def self.process_company_url_and_name(url, company_name)
    begin
      company_html = Hpricot(Helpers.instance.sanitize_contents(open(url).read))

      slug = company_name.to_slug

      # Find an existing company to match
      company = Database.companies.find_one({ "slug" => slug })
      company = {} if company.nil?

      company["name"] = company_name
      company["slug"] = slug
      company["source_url"] = url

      # Get the link to the coupon page, trying the two variations we've seen
      coupon_link = company_html.search('div.cgeyixcacaidb a[@href^="coupon"]').first

      if coupon_link.nil? or coupon_link.empty?
        coupon_link = company_html.search('div.cgeyixcacaidb a[@href^="acctcoupon"]').first
      end

      if coupon_link.nil? or coupon_link.empty?
        # Handle a different case for the URL. Le sigh.
        coupon_link = company_html.search('div.cgeyixcacaidb a[@href^="AcctCoupon"]').first
      end

      if !coupon_link.nil? and !coupon_link.empty?
        company["coupon_list_url"] = "#{ROOT_URL}#{coupon_link.get_attribute(:href)}"
      else
        raise "There is no coupon link for this company"
      end

      address_area = company_html.search('span.dirupheader')
      address_items = address_area.search('font')

      has_address = address_items.count >= 2
      
      if has_address
        new_company_address = address_items[0].inner_text.strip
        
        # Update the address only if it's newly retrieved, or changed,
        # or if we don't have a lat/lng for the address
        if !new_company_address.nil? &&
           (
             !company.has_key?("full_address") || 
             (!company.has_key?("lat") && !company.has_key?("lng")) || 
             company["full_address"] != new_company_address
           )
          
          company["full_address"] = new_company_address
          company.delete "lat"
          company.delete "lng"

          # geocode it
          result = Geocoder.search(new_company_address).first
          if !result.nil? && result.data.has_key?("geometry") && result.data["geometry"].has_key?("location")
            company["lat"] = result.data["geometry"]["location"]["lat"]
            company["lng"] = result.data["geometry"]["location"]["lng"]
          end
        end
      end
      
      if has_address || address_items.count == 1
        if has_address
          company["phone_number"] = address_items[1].inner_text.strip
        elsif address_items.count == 1
          company["phone_number"] = address_items[0].inner_text.strip
        end
      end
      
      description_element = company_html.search('span.dirupheader + div').first

      if !description_element.nil?
        company["description"] = description_element.inner_text.strip
      end
      
      CouponProcessor.process_coupons_for_company(company)

      # Build an array with the set of searchable values from:
      # - description
      # - each coupon description
      searchable = []
      if company.has_key?("description")
        searchable.concat(company["description"].split)
      end
      if company.has_key?("full_address")
        searchable.concat(company["full_address"].split)
      end
      company["coupons"].each do |coupon|
        searchable.concat(coupon["description"].split)
      end

      searchable.each { |item| item.downcase! }
      searchable.uniq!
      company["search"] = searchable

      # Flag this company as not stale anymore
      company["stale"] = false
      company["updated_at"] = Time.now

      Database.companies.save company

    rescue Exception => ex
      Helpers.instance.write_error "Error retrieving company information for '#{company_name}'", ex, :url => url, :company_name => company_name
    end
  end
end