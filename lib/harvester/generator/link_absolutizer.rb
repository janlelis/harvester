# encoding: utf-8
class Harvester; class Generator; end; end

# This module rewrites relative to absolute links
module Harvester::Generator::LinkAbsolutizer
  def self.run(body, base, logger = nil)
    logger ||= Logger.new(STDOUT)
    require 'hpricot'

    html = Hpricot("<html><body>#{body}</body></html>")
    (html/'a').each { |a|
      begin
        f = a.get_attribute('href')
        t = URI::join(base, f.to_s).to_s
        logger.debug "* rewriting #{f.inspect} => #{t.inspect}" if f != t
        a.set_attribute('href', t)
      rescue URI::Error
        logger.debug "* cannot rewrite relative URL: #{a.get_attribute('href').inspect}" unless a.get_attribute('href') =~ /^[a-z]{2,10}:/
      end
    }
    (html/'img').each { |img|
      begin
        f = img.get_attribute('src')
        t = URI::join(base, f.to_s).to_s
        logger.debug "* rewriting #{f.inspect} => #{t.inspect}" if f != t
        img.set_attribute('src', t)
      rescue URI::Error
        logger.debug "* cannot rewrite relative URL: #{img.get_attribute('href').inspect}" unless img.get_attribute('href') =~ /^[a-z]{2,10}:/
      end
    }
    html.search('/html/body/*').to_s
  rescue Hpricot::Error => e
    logger.error "* hpricot::Error: #{e}"
    body
  rescue LoadError
    logger.warn "* hpricot not found, will not mangle relative links in <description/>"
    body
  rescue Exception => e
    logger.warn "* there was an hpricot exception: #{e}"
  end
end
