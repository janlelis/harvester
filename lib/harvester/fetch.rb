# encoding: utf-8

require_relative '../harvester'
require_relative 'mrss'

require 'eventmachine'
require 'em-http'
require 'uri'

class Harvester
  def fetch!
    fetcher = Fetch.new @dbi, @collections, @config['settings']
    fetcher.maintenance
    fetcher.get_content
  end
end

class Harvester::Fetch
  def initialize(dbi, collections, settings = {
        'timeout'    => 90,
        'size limit' => 200_000,
      })
    @dbi         = dbi
    @collections = collections
    @settings    = settings
  end

  def maintenance
    puts "Looking for sources to purge..."
    purge = []
    @dbi.select_all("SELECT collection, rss FROM sources") { |dbc,dbr|
      purge << [dbc, dbr] unless (@collections[dbc] || []).include? dbr
    }

    purge_rss = []
    purge.each { |c,r|
      puts "Removing #{c}:#{r}..."
      @dbi.do "DELETE FROM sources WHERE collection=? AND rss=?", c, r
      purge_rss << r
    }

    purge_rss.delete_if { |r|
      purge_this = true

      @collections.each { |cfc,cfr|
        if purge_this
          puts "Must keep #{r} because it's still in #{cfc}" if cfr && cfr.include?(r)
          purge_this = !(cfr && cfr.include?(r))
        end
      }

      !purge_this
    }
    purge_rss.each { |r|
      puts "Purging items from feed #{r}"
      @dbi.do "DELETE FROM items WHERE rss=?", r
    }
  end

  def get_content
    maxurlsize = @collections.inject(0){ |acc, (_,rss_urls)| # log display hack
      if rss_urls
        max = rss_urls.max_by(&:size).to_i
        acc > max ? acc : max
      else
        acc
      end
    }

    @dbi['AutoCommit'] = false

    EM.run do
      pending = []
      @collections.each{ |collection, rss_urls|
        rss_urls and rss_urls.each{ |rss_url|

          db_rss, last = @dbi.select_one "SELECT rss, last FROM sources WHERE collection=? AND rss=?", collection, rss_url
          is_new = db_rss.nil?

          uri = URI::parse rss_url
          p uri
          logprefix = "[#{uri.to_s.ljust maxurlsize}] "

          header = {}
          header['Authorization'] = [uri.user, uri.password] if uri.user

          print "#{logprefix}GET"
          if is_new || last.nil?
            puts
          else
            puts " with If-Modified-Since: #{last}"
            header['If-Modified-Since'] = last
          end

          pending << rss_url
          http = EM::HttpRequest.new(uri).get :head => header
          p http

          http.errback do
            puts logprefix + "Request Error: #{ http.error }"
            pending.delete rss_url
            EM.stop if pending.empty?
          end

          http.callback do
            if http.response_header.status != 200
              puts "[DEBUGGY] did not return 200 but: #{ http.response_header.status }"
            elsif http.response.size > @settings['size limit'].to_i
              puts logprefix + "#{response.size} bytes big!"
            else
              response = http.response
              begin @dbi.transaction do
                rss = MRSS::parse response

                # update source
                if is_new
                  @dbi.do "INSERT INTO sources (collection, rss, last, title, link, description) VALUES (?, ?, ?, ?, ?, ?)",
                    collection, rss_url, response['Last-Modified'], rss.title, rss.link, rss.description
                  puts logprefix + "Source added"
                else
                  @dbi.do "UPDATE sources SET last=?, title=?, link=?, description=? WHERE collection=? AND rss=?",
                    response['Last-Modified'], rss.title, rss.link, rss.description, collection, rss_url
                  puts logprefix + "Source updated"
                end

                print logprefix
                update_items rss, rss_url
              end; end
            end

            pending.delete rss_url # same url twice?
            EM.stop if pending.empty?
          end
        }
      }

      EM.add_timer @settings['timeout'].to_i do
        pending.each { |rss_url|
          puts "[#{rss_url.ljust maxurlsize}] Timed out"
        }
        EM.stop
      end
    end
  end    

  def update_items(rss, rss_url)
    items_new, items_updated = 0, 0
    rss.items.each { |item|
      description = item.description

      # Link mangling
      begin
        link = URI::join((rss.link.to_s == '') ? uri.to_s : rss.link.to_s, item.link || rss.link).to_s
      rescue URI::Error
        link = item.link
      end

      # Push into database
      db_title = @dbi.select_one "SELECT title FROM items WHERE rss=? AND link=?", rss_url, link
      item_is_new = db_title.nil?

      if item_is_new
        begin
          @dbi.do "INSERT INTO items (rss, title, link, date, description) VALUES (?, ?, ?, ?, ?)",
            rss_url, item.title, link, item.date.to_s, description
          items_new += 1
        rescue DBI::ProgrammingError
          puts description
          puts "#{$!.class}: #{$!}\n#{$!.backtrace.join("\n")}"
        end
      else
        @dbi.do "UPDATE items SET title=?, description=? WHERE rss=? AND link=?",
          item.title, description, rss_url, link
        items_updated += 1
      end

      # Remove all enclosures
      @dbi.do "DELETE FROM enclosures WHERE rss=? AND link=?", rss_url, link
      # Re-add all enclosures
      item.enclosures.each do |enclosure|
        href = URI::join((rss.link.to_s == '') ? link.to_s : rss.link.to_s, enclosure['href']).to_s
        @dbi.do "INSERT INTO enclosures (rss, link, href, mime, title, length) VALUES (?, ?, ?, ?, ?, ?)",
          rss_url, link, href, enclosure['type'], enclosure['title'],
          !enclosure['length'] || enclosure['length'].empty? ? 0 : enclosure['length']
      end
    }
    puts "New: #{items_new} Updated: #{items_updated}"
  end
end
