# encoding: utf-8
class Harvester; class Generator; end; end

# This module rewrites relative to absolute links
module Harvester::Generator::LinkAbsolutizer
  def self.run(body, base, logger = nil)
    logger ||= Logger.new(STDOUT)
    require 'nokogiri'
    require 'uri'

    html = Nokogiri::HTML("<html><body>#{body}</body></html>")
    [%w[img src], %w[a href]].each{ |elem, attr|
      html.css(elem).each{ |e|
        begin
          src = e[attr]
          uri = URI::join(base, src.to_s).to_s
          if src.to_s != uri.to_s
            logger.debug "* rewriting #{src.inspect} => #{uri.inspect}" 
            e[attr] = uri.to_s
          end
        rescue URI::Error
          logger.debug "* cannot rewrite relative URL: #{src.inspect}" #unless src.to_s =~ /^[a-z]{2,10}:/
        end
      }
    }
    html.css('body').children.to_s
  rescue LoadError
    logger.warn "* nokogiri not found, will not mangle relative links in <description/>"
    body
  rescue Exception => e
    logger.warn "* there was a nokogiri exception: #{e}"
  end
end
