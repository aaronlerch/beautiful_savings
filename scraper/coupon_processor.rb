# encoding: utf-8

require 'open-uri'
require 'hpricot'
require_relative './helpers.rb'

class CouponProcessor
  def self.process_coupons_for_company(company = {})
    # Clear any existing coupons, we're going to reset these no matter what
    company["coupons"] = []
    return [] if !company.has_key?("coupon_list_url")
    url = company["coupon_list_url"]
    return [] if !Helpers.instance.should_process(url)
    
    page = Hpricot(Helpers.instance.sanitize_contents(open(url).read))

    # process all coupons based on the div.couponvalue div
    coupon_divs = page.search('div.couponvalue')

    if coupon_divs.empty?
        doc = {
          :message => "No coupons found for #{company["name"]}",
          :url => company["coupon_list_url"]
        }
        Database.errors.insert doc
        puts "No coupons found for #{company["name"]}!"
    end

    # Some pages have a single coupon, and are structured differently. Process that here.
    is_single_coupon_page = page.search('div.cbghpgcicajge table.lp').empty?

    coupon_divs.each do |coupon_div|
      begin
        if is_single_coupon_page
          company["coupons"] << parse_single_coupon_structure(coupon_div)
        else
          company["coupons"] << parse_multiple_coupon_structure(coupon_div)
        end
      rescue Exception => ex
        Helpers.instance.write_error("Error processing a coupon for '#{company["name"]}' with description #{coupon_div.inner_text}", ex)
      end
    end
  end

  def self.parse_single_coupon_structure(coupon_div)
    # walk back up the element's parent until we find the parent div
    parent_div = coupon_div
    while not parent_div.nil? || 
              (parent_div.name.downcase == "div" &&
               parent_div.classes.include?("cbghpgcicajge"))
      parent_div = parent_div.parent
    end

    raise "Unable to process the coupon with description #{coupon_div.inner_text}" if parent_div.nil?
    
    coupon = {}
    coupon["description"] = parent_div.search('div.couponvalue').first.inner_text
    coupon["restrictions"] = parent_div.search('div.couponrestriction').first.inner_text

    coupon_link_elem = parent_div.search('span.lp > a').first
    raise "Unable to find coupon print link" if coupon_link_elem.nil?
    onclick = coupon_link_elem.get_attribute('onclick')
    url_match = onclick.match /window.open\('(.*?)'/i
    link = url_match[1]

    coupon["source_url"] = "#{ROOT_URL}#{link}"
    coupon
  end

  def self.parse_multiple_coupon_structure(coupon_div)
    # walk back up the element's parent until we find the parent table (or we end)
    parent_table = coupon_div
    while not parent_table.nil? || parent_table.name.downcase == "table"
      parent_table = parent_table.parent
    end

    raise "Unable to process the coupon with description #{coupon_div.inner_text}" if parent_table.nil?
    
    coupon = {}
    coupon["description"] = parent_table.search('div.couponvalue').first.inner_text
    coupon["restrictions"] = parent_table.search('div.couponrestriction').first.inner_text

    # Find the current row inside the "lp" table, to use as the root for findind the coupon link
    lp_table_row = parent_table
    while not lp_table_row.nil? ||
              (lp_table_row.name.downcase == "tr" &&
                !lp_table_row.parent.nil? &&
                lp_table_row.parent.name.downcase == "table" &&
                lp_table_row.parent.classes.include?("lp"))
      lp_table_row = lp_table_row.parent
    end

    raise "Unable to find the parent 'lp' table for the coupon" if lp_table_row.nil?

    coupon_link_elem = lp_table_row.search('span.lp > a').first
    raise "Unable to find coupon print link" if coupon_link_elem.nil?
    onclick = coupon_link_elem.get_attribute('onclick')
    url_match = onclick.match /window.open\('(.*?)'/i
    link = url_match[1]

    coupon["source_url"] = "#{ROOT_URL}#{link}"
    coupon
  end
end