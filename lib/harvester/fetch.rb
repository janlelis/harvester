# encoding: utf-8

require_relative '../harvester'
require_relative 'mrss'

require 'eventmachine'
require 'em-http'
require 'uri'

class Harvester
  FETCH = true
  # fetches new feed updates and store them in the database
  def fetch!
    info "FETCH"
    Fetcher.run @dbi, @collections, @settings, @logger do |*args| update_db(*args) end # results will be passed to the update function
  end

  private

  # saves result of a request in db
  def update_db(rss_url, new_source, collection, response, rss_url_nice = rss_url)
    rss = MRSS.parse(response)

    begin @dbi.transaction do
      # update source
      if new_source
        @dbi.execute "INSERT INTO sources (collection, rss, last, title, link, description) VALUES (?, ?, ?, ?, ?, ?)",
          collection, rss_url, response['Last-Modified'], rss.title, rss.link, rss.description
        info rss_url_nice + "Added as source"
      else
        @dbi.execute "UPDATE sources SET last=?, title=?, link=?, description=? WHERE collection=? AND rss=?",
          response['Last-Modified'], rss.title, rss.link, rss.description, collection, rss_url
        debug rss_url_nice + "Source updated"
      end

      # update items
      items_new, items_updated = 0, 0
      rss.items.each { |item|
        description = item.description

        # Link mangling
        begin
          link = URI::join((rss.link.to_s == '') ? URI.parse(rss_url).to_s : rss.link.to_s, item.link || rss.link).to_s
        rescue URI::Error
          link = item.link
        end

        # Push into database
        db_title, = *@dbi.execute("SELECT title FROM items WHERE rss=? AND link=?", rss_url, link).fetch

        if db_title.nil? || db_title.empty? # item is new
          begin
            @dbi.execute "INSERT INTO items (rss, title, link, date, description) VALUES (?, ?, ?, ?, ?)",
              rss_url, item.title, link, item.date.to_s, description
            items_new += 1
          #rescue DBI::ProgrammingError
          #  puts description
          #  puts "#{$!.class}: #{$!}\n#{$!.backtrace.join("\n")}"
          end
        else
          @dbi.execute "UPDATE items SET title=?, description=?, date=? WHERE rss=? AND link=?",
            item.title, description, item.date.to_s, rss_url, link
          items_updated += 1
        end

        # Remove all enclosures
        @dbi.execute "DELETE FROM enclosures WHERE rss=? AND link=?", rss_url, link

        # Re-add all enclosures
        item.enclosures.each do |enclosure|
          href = URI::join((rss.link.to_s == '') ? link.to_s : rss.link.to_s, enclosure['href']).to_s
          @dbi.execute "INSERT INTO enclosures (rss, link, href, mime, title, length) VALUES (?, ?, ?, ?, ?, ?)",
            rss_url, link, href, enclosure['type'], enclosure['title'],
            !enclosure['length'] || enclosure['length'].empty? ? 0 : enclosure['length']
        end
      }
      info rss_url_nice + "#{ items_new } new items, #{ items_updated } updated"
    end; end
  end
end

# fetches new feed updates and store them in the database using Eventmachine
module Harvester::Fetcher
  def self.run(dbi, collections, settings, logger)
    logger.info '[start] fetch using Eventmachine'

    # prepare logger
    max_url_size = collections.inject(0){ |acc, (_,rss_urls)| # log display hack
      if rss_urls
        max = rss_urls.max_by(&:size).size.to_i
        acc > max ? acc : max
      else
        acc
      end
    }

    #dbi['AutoCommit'] = false # TODO check for rdbi
    
    EventMachine.run do
      pending = []
      collections.each{ |collection, rss_urls|
        rss_urls and rss_urls.each{ |rss_url|
          # prepare log prefix
          rss_url_nice = '* ' + rss_url.ljust(max_url_size) + ' | '

          # get last_modified or if new
          db_rss, last = dbi.execute("SELECT rss, last FROM sources WHERE collection=? AND rss=?",
                          collection, rss_url).fetch
          new_source = db_rss.nil? || db_rss.empty?
          uri = URI.parse(rss_url)

          # prepare request
          header = {}
          header['Authorization'] = [uri.user, uri.password] if uri.user

          if new_source || last.nil?
            logger.info rss_url_nice + "GET"
          else
            logger.info rss_url_nice + "GET with If-Modified-Since: #{ last }"
            header['If-Modified-Since'] = last
          end

          # do request
          pending << rss_url
          http = EM::HttpRequest.new(uri).get :head => header

          http.errback do
            logger.error rss_url_nice + "Request Error: #{ http.error }"

            pending.delete rss_url
            EM.stop if pending.empty?
          end

          http.callback do
            if http.response_header.status != 200
              logger.warn rss_url_nice + "HTTP not OK, but: #{ http.response_header.status }"
            elsif http.response.size > settings['size limit'].to_i
              logger.warn rss_url_nice + "Got too big repsonse: #{ response.size } bytes"
            else
              yield rss_url, new_source, collection, http.response, rss_url_nice # TODO clean up
            end

            pending.delete rss_url # same url twice?
            EM.stop if pending.empty?
          end
        }
      }
      EM.stop if pending.empty? # e.g. no collections configured

      EM.add_timer(settings['timeout'].to_i){
        pending.each { |rss_url| logger.warn rss_url_nice + 'Timed out' }
        EM.stop
      }
    end
    logger.info '[done ] fetch using Eventmachine'
  end
end
