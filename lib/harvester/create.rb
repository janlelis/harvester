# encoding: utf-8

require_relative '../harvester'

class Harvester
  CREATE = true
  # creates required database structure
  def create!
    info "CREATE"
    task "create database tables" do
      begin @dbi.transaction do
        sql_queries(:create).each{ |sql|
          info "* execute " + File.basename(sql)
          @dbi.execute File.read(sql)
        }
      end; end
    end
  end
end
