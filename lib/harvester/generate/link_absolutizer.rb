# encoding: utf-8
require 'singleton'

begin
  require 'hpricot'
rescue LoadError
  $stderr.puts "Hpricot not found, will not mangle relative links in <description/>"
end

class Harvester; class Generate; end; end

class Harvester::Generate::LinkAbsolutizer
  include Singleton

  def absolutize_links(body, base)
    html = Hpricot("<html><body>#{body}</body></html>")
    (html/'a').each { |a|
      begin
        f = a.get_attribute('href')
        t = URI::join(base, f.to_s).to_s
        puts "Rewriting #{f.inspect} => #{t.inspect}" if f != t
        a.set_attribute('href', t)
      rescue URI::Error
        puts "Cannot rewrite relative URL: #{a.get_attribute('href').inspect}" unless a.get_attribute('href') =~ /^[a-z]{2,10}:/
      end
    }
    (html/'img').each { |img|
      begin
        f = img.get_attribute('src')
        t = URI::join(base, f.to_s).to_s
        puts "Rewriting #{f.inspect} => #{t.inspect}" if f != t
        img.set_attribute('src', t)
      rescue URI::Error
        puts "Cannot rewrite relative URL: #{img.get_attribute('href').inspect}" unless img.get_attribute('href') =~ /^[a-z]{2,10}:/
      end
    }
    html.search('/html/body/*').to_s
  rescue Hpricot::Error => e
    $stderr.puts "Hpricot::Error: #{e}"
    body
  end
  
  def self.run(body, base)
    if defined? Hpricot
      instance.absolutize_links(body, base)
    else
      body
    end
  end
end
