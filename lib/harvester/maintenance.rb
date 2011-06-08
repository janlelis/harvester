# encoding: utf-8

require_relative '../harvester'

class Harvester
  MAINTENANCE = true
  # check for feed source changes
  def maintenance!
    info "MAINTENANCE"
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
  alias purge! maintenance!
end
