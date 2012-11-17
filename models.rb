require 'json'

class Company
  attr_accessor :name, 
                :full_address, 
                :phone_number, 
                :website, 
                :image_url, 
                :source_url, 
                :coupon_list_url, 
                :description,
                :coupons

  def initialize
    @coupons = []
  end

  def to_mongo
    hash = {
      :name => @name,
      :full_address => @full_address,
      :phone_number => @phone_number,
      :website => @website,
      :image_url => @image_url,
      :source_url => @source_url,
      :coupon_list_url => @coupon_list_url,
      :description => @description,
      :coupons => []
    }

    @coupons.each do |c|
      hash[:coupons] << { 
        :description => c.description, 
        :restrictions => c.restrictions, 
        :source_url => c.source_url
      }
    end

    hash
  end
end

class Coupon
  attr_accessor :description, :restrictions, :source_url
end