# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'
require_relative '../models.rb'

class CouponProcessor
  def self.process_coupons_for_company(company)
    return [] if company.nil? or company.coupon_list_url.nil?
    url = company.coupon_list_url
    # test url = "http://www.coupons4indy.com/acctcoupons-118650.113129-A1-Auto-Service.html"
    return [] if !Helpers.instance.should_process(url)
    
    page = Hpricot(Helpers.instance.sanitize_contents(open(url).read))
    coupon_rows = page.search('div.cbghpgcicajge > table.lp > tr')

    coupon_rows.each do |row|
      coupon = Coupon.new
      coupon.description = row.search('div.couponvalue').inner_text
      coupon.restrictions = row.search('div.couponrestriction').inner_text

      coupon_link_elem = row.search('span.lp > a').first
      onclick = coupon_link_elem.get_attribute('onclick')
      url_match = onclick.match /window.open\('(.*?)'/i
      link = url_match[1]

      coupon.source_url = "#{ROOT_URL}#{link}"
      company.coupons << coupon
    end
  end
end