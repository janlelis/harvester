# encoding: utf-8

require_relative '../harvester'

class Harvester
  def create!
    puts "Creating database tables..."
    Dir[ File.dirname(__FILE__) + "/../../data/sql/#{ @dbi.driver_name.downcase }/*.sql" ].each{ |sql|
      puts "Executing " + File.basename(sql)
      @dbi.execute File.read( sql )
    }
  end

  def maintenance!
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
end
