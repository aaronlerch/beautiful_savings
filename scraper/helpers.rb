# encoding: utf-8

require 'singleton'

class Helpers
  include Singleton

  def initialize
    @processed_urls = {}
  end

  def should_process(url)
    return false if url.nil?
    canonical_url = url.downcase
    
    if @processed_urls.keys.count >= 10000
      abort "Something might be wrong, we've processed 10,000 URLs so far."
    end

    if @processed_urls.has_key? canonical_url
      false
    else
      @processed_urls[canonical_url] = true
      true
    end
  end

  def write_error(message, ex)
    puts(Helpers.get_error_string(message, ex))
  end

  def sanitize_contents(contents)
    contents.encode!('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
    contents.encode!('UTF-8', 'UTF-16')
  end

  def self.get_error_string(message, ex)
    "#{message}:\n#{ex.message}\n\n#{ex.backtrace}\n"
  end
end