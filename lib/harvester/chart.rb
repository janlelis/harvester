# encoding: utf-8

require_relative '../harvester'
require_relative 'chart/stats_per_collection'

require 'gruff'

class Harvester
  def chart!
    c = Chart::StatsPerCollection.new
    @dbi.select_all("select date(items.date) as date,sources.collection from items left join sources on sources.rss=items.rss where date > now() - interval '14 days' and date < now() + interval '1 day' order by date") { |date,collection|
      c.add_one(collection, date.day)
    }
    Chart.new(c).write File.join( @config['settings']['output'], '/chart.jpg' )
  end
end

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
