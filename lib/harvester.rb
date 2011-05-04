require 'rubygems' unless defined? Gem

require_relative 'harvester/core_ext'

require 'dbi'
require 'yaml'

class Harvester
  VERSION = '0.8.0.pre'

  attr_reader :config, :dbi

  def initialize(options = {})
    options[:config] ||= './harvester.yaml'

    begin
      @config = YAML::load_file File.expand_path( options[:config] )
    rescue Errno::ENOENT
      raise LoadError, "Could not find a harvester.yaml config file at #{ File.expand_path( options[:config] ) }"
    end

    begin
      @dbi = DBI::connect( config['db']['driver'], config['db']['user'], config['db']['password'] )
    rescue Exception
      warn 'Something is wrong with your database settings:'
      raise
    end
  end

  def self.new_from_argv
    options = {}

    require 'optparse'
    op = OptionParser.new
    op.on('-c', '--config FILE') do |config_path|
      options[:config] = config_path
    end.parse!

    Harvester.new *options
  end
end
