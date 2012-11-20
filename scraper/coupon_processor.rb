# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'

class CouponProcessor
  def self.process_coupons_for_company(company = {})
    company[:coupons] = []
    return [] if !company.has_key? :coupon_list_url
    url = company[:coupon_list_url]
    return [] if !Helpers.instance.should_process(url)
    
    page = Hpricot(Helpers.instance.sanitize_contents(open(url).read))

    # process all coupons based on the div.couponvalue div
    coupon_divs = page.search('div.couponvalue')

    if coupon_divs.empty?
        doc = {
          :message => "No coupons found for #{company[:name]}",
          :url => company[:coupon_list_url]
        }
        Database.errors.insert doc
        puts "No coupons found for #{company[:name]}!"
    end

    coupon_divs.each do |coupon_div|
      begin
        # walk back up the element's parent until we find the parent table (or we end)
        parent_table = coupon_div
        while not parent_table.name.nil? || parent_table.name.downcase == "table" || parent_table.name.downcase == "html"
          parent_table = parent_table.parent
        end

        if parent_table.nil?
          raise "Unable to process the coupon with description #{coupon_div.inner_text}"
        else
          coupon = {}
          coupon[:description] = parent_table.search('div.couponvalue').first.inner_text
          coupon[:restrictions] = parent_table.search('div.couponrestriction').first.inner_text

          coupon_link_elem = parent_table.search('span.lp > a').first
          onclick = coupon_link_elem.get_attribute('onclick')
          url_match = onclick.match /window.open\('(.*?)'/i
          link = url_match[1]

          coupon[:source_url] = "#{ROOT_URL}#{link}"
          company[:coupons] << coupon
        end
      rescue Exception => ex
        Helpers.instance.write_error("Error processing a coupon for '#{company[:name]}' with description #{coupon_div.inner_text}", ex)
      end
    end
  end
end