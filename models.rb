require 'mongoid'

class Company
  include Mongoid::Document
  field :name, type: String
  field :full_address, type: String
  field :phone_number, type: String
  field :website, type: String
  field :image_url, type: String
  field :source_url, type: String
  field :description, type: String

  embeds_many :coupons
end

class Coupon
  include Mongoid::Document
  field :description, type: String
  field :restrictions, type: String
  field :source_url, type: String

  embedded_in :company
end