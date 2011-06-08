# encoding: utf-8

require_relative '../harvester'
require 'gruff'

class Harvester
  STATS = true
  # generates a fetch statistic image
  def stats!
    info "STATS"
    task "generate chart" do
      c = Chart::StatsPerCollection.new
      @dbi.execute( File.read( sql_query(:chart) ) ).each{ |date,collection|
        c.add_one(collection, Date.parse(date).day)
      }
      Chart.new(c).write File.join( @config['settings']['output'], '/chart.jpg' )
    end
  end
end

# generates a fetch statistics image using gruff
class Harvester::Chart
  def initialize(stats, options = {}) # TODO configure g with options
    @g = Gruff::Line.new(300)
    @g.title = "Harvested items per day"
    @g.x_axis_label = "Days"
    @g.y_axis_label = "Items"

    stats.each(&@g.method(:data))

    labels = {}
    stats.days.each_with_index do |d,i|
      labels[i] = d.to_s
    end
    @g.labels = labels
  end

  def write(path)
    @g.write(path)
  end
end

class Harvester::Chart::StatsPerCollection
  attr_reader :days

  def initialize
    @collections = {}
    @days = []
  end

  def add_one(collection, day)
    @days << day unless @days.index(day)
    collection ||= '(unknown)' # TODO research

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
