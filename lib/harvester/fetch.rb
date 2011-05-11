# encoding: utf-8

require_relative '../harvester'
require_relative 'db'
require_relative 'mrss'

require 'eventmachine'
require 'em-http'
require 'uri'

class Harvester
  module FETCH; end

  def fetch!
    info "FETCH"
    maintenance! unless @settings['no-maintenance']
    Fetcher.run @dbi, @collections, @settings, @logger do |*args| update(*args) end # results will be passed to the update function
  end
end

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
          uri = URI.parse rss_url

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
              logger.warn rss_url_nice + "Got too big repsonse: #{response.size} bytes"
            else
              yield rss_url, new_source, collection, http.response, rss_url_nice
            end

            pending.delete rss_url # same url twice?
            EM.stop if pending.empty?
          end
        }
      }

      EM.add_timer(settings['timeout'].to_i){
        pending.each { |rss_url| logger.warn rss_url_nice + 'Timed out' }
        EM.stop
      }
    end
    logger.info '[done]  fetch using Eventmachine'
  end
end
