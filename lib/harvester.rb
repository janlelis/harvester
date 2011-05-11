require 'rubygems' unless defined? Gem
require 'rdbi'
require 'yaml'
require 'logger/colors'

class Harvester
  VERSION = '0.8.0.pre'

  attr_reader :config, :settings, :collections, :dbi, :logger

  # takes an options string (to which overwrites settings) and creates a new Harvester instance
  def initialize(options = {})
    # command line options
    options['config'] ||= './config.yaml'

    # load config
    begin
      config_path = File.expand_path( options.delete('config') )
      @config = YAML::load_file config_path
    rescue Errno::ENOENT
      raise LoadError, "Could not find a yaml config file at #{ config_path }"
    end

    # instance variable helpers
    @settings = {
      'collections' => 'collections.yaml',
      'timeout'     => 90,
      'size limit'  => 200_000,
      'log_level'   => Logger::DEBUG, # 0
      'log_file'    => STDOUT,
    }
    @settings.merge! @config['settings']
    @settings.merge! options

    # load collections
    begin
      @collections = YAML::load_file @settings['collections']
    rescue Errno::ENOENT
      raise LoadError, "Could not find a yaml collections file at #{ File.expand_path( options[:config] ) }"
    end

    # init logger
    @logger = Logger.new(
      if !@settings['log_file'] || @settings['log_file'] =~ /^STD(?:OUT|ERR)$/
        Object.const_get(@settings['log_file'])
      else
        @settings['log_file']
      end
    )
    @logger.formatter = proc { |level, datetime, appname, msg| "#{msg}\n" }
    @logger.level = if %w[debug info warn error fatal].include?(@settings['log_level'].to_s.downcase)
      Logger::Severity.const_get(@settings['log_level'].to_s.upcase)
    else
      @settings['log_level'].to_i
    end

    # connect to db
    begin
      require 'rdbi/driver/' + config['db']['driver'].downcase # FIXME?

      @dbi = RDBI::connect config['db']['driver'],
        database:          config['db']['database'],
        user:              config['db']['user'],
        password:          config['db']['password']
    rescue Exception
      error 'Something is wrong with your database settings:'
      raise
    end
  end

  # creates a new harvester using the command-line options to configure it
  def self.new_from_argv
    options = {}

    require 'optparse'
    OptionParser.new do |op|
      op.banner = %q{USAGE:
    harvester <COMMAND> [OPTIONS]
COMMANDS:
    run          run a complete harvester update
    fetch        run only the fetch script
    generate     run only the generate script
    chart        run only the generate chart script
    post         run only the post processing script
    db           start a database task (create or maintenance)
    clock        start the scheduler (cron replacement)
    new          create a new harvester project
    jabber       start the jabber bot (not implemented yet)
OPTIONS:} # automatically added as --help
      op.on('-v', '--version') do
        puts Harvester::VERSION
        exit
      end
      op.on('-c', '--config FILE') do |config|
        options['config'] = config
      end
      op.on('-l', '--log_file FILE') do |log_file|
        options['log_file'] = log_file
      end
      op.on('-L', '--log_level NUMBER') do |log_level|
        options['log_level'] = log_level
      end
      op.on('-p', '--post_script FILE') do |post_script|
        options['post_script'] = post_script
      end
      op.on('-m', '--no-maintenance') do
        options['no-maintenance'] = true
      end
    end.parse!

    Harvester.new options
  end

  protected

  # logger helpers
  def debug(msg) @logger.debug(msg) end
  def info(msg)  @logger.info(msg)  end
  def warn(msg)  @logger.warn(msg)  end
  def error(msg) @logger.error(msg) end
  def fatal(msg) @logger.fatal(msg) end

  # adds an info message before and after the block
  def task(msg) # MAYBE: nested spaces+behaviour
    info "[start] " + msg
    yield
    info "[done ] " + msg
  end
end
