# encoding: utf-8

require_relative '../harvester'

class Harvester
  module DB; end

  # creates required database structure
  def create!
    task "create database tables" do
      begin @dbi.transaction do
        sql_queries(:create).each{ |sql|
          info "* execute " + File.basename(sql)
          @dbi.execute File.read(sql)
        }
      end; end
    end
  end

  # check for feed source changes
  def maintenance!
    task "look for sources to purge" do
      purge = []
      @dbi.execute("SELECT collection, rss FROM sources").each{ |dbc,dbr|
        purge << [dbc, dbr] unless (@collections[dbc] || []).include? dbr
      }

      purge_rss = []
      purge.each { |c,r|
        info "* remove #{c}:#{r}..."
        @dbi.execute "DELETE FROM sources WHERE collection=? AND rss=?", c, r
        purge_rss << r
      }

      purge_rss.delete_if { |r|
        purge_this = true

        @collections.each { |cfc,cfr|
          if purge_this
            warn "* must keep #{r} because it's still in #{cfc}" if cfr && cfr.include?(r)
            purge_this = !(cfr && cfr.include?(r))
          end
        }

        !purge_this
      }
      purge_rss.each { |r|
        info "* purge items from feed #{r}"
        @dbi.execute "DELETE FROM items WHERE rss=?", r
      }
    end
  end

  private

  def update(rss_url, new_source, collection, response, rss_url_nice = rss_url)
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
          link = URI::join((rss.link.to_s == '') ? uri.to_s : rss.link.to_s, item.link || rss.link).to_s
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

  def sql_queries(task)
    Dir[ File.dirname(__FILE__) + "/../../data/sql/#{ @config['db']['driver'].downcase }/#{ task }*.sql" ].each
  end

  def sql_query(task)
    File.dirname(__FILE__) + "/../../data/sql/#{ @config['db']['driver'].downcase }/#{ task }.sql"
  end
end
