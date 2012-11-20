# encoding: utf-8

require_relative './company_processor.rb'
require_relative './helpers.rb'
require 'open-uri'
require 'hpricot'

class Processor
  def process_all
    begin
      root_html = Hpricot(Helpers.instance.sanitize_contents(open(ROOT_URL).read))
    rescue Exception => ex
      abort("Error accessing coupons4indy.com:\n\n#{ex.message}\n\n#{ex.backtrace}")
    end

    root_html.search('select.sidedirectorybody').first

    abort("No global select list! (One can only dream.)") if root_html.nil?

    root_html.search('option').each do |company_option|
      option_value = company_option.get_attribute(:value)
      next if option_value.nil? or option_value.empty?

      url = "#{ROOT_URL}#{option_value}"
      company_name = company_option.inner_text.strip
      CompanyProcessor.process_company_url_and_name(url, company_name)
    end
  end
end