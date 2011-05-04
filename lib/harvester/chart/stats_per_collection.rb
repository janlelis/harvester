# encoding: utf-8

class Harvester; class Chart; end; end

class Harvester::Chart::StatsPerCollection
  attr_reader :days

  def initialize
    @collections = {}
    @days = []
  end

  def add_one(collection, day)
    @days << day unless @days.index(day)
    collection ||= '(unknown)'

    c = @collections[collection] || {}
    c[day] = (c[day] || 0) + 1
    @collections[collection] = c
  end

  def each
    @collections.each { |n,c|
      v = []
      @days.each { |d|
        v << c[d].to_i
      }

      yield n, v
    }
  end
end
