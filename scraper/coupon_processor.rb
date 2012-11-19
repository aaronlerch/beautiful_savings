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
    
    # TODO: not all coupon pages have the same structure - need to figure out 
    # the right structure for the "outliers".
    page = Hpricot(Helpers.instance.sanitize_contents(open(url).read))
    coupon_rows = page.search('div.cbghpgcicajge > table.lp > tr')

    if coupon_rows.empty?
        doc = {
          :message => "No coupons found for #{company[:name]}",
          :url => company[:coupon_list_url]
        }
        Database.errors.insert doc
        puts "No coupons found for #{company[:name]}!"
    end

    coupon_rows.each do |row|
      begin
        coupon = {}
        coupon[:description] = row.search('div.couponvalue').inner_text
        coupon[:restrictions] = row.search('div.couponrestriction').inner_text

        coupon_link_elem = row.search('span.lp > a').first
        onclick = coupon_link_elem.get_attribute('onclick')
        url_match = onclick.match /window.open\('(.*?)'/i
        link = url_match[1]

        coupon[:source_url] = "#{ROOT_URL}#{link}"
        company[:coupons] << coupon
      rescue Exception => ex
        puts Helpers.get_error_string("Error retrieving coupon information for company #{company[:name]}", ex)
      end
    end
  end
end