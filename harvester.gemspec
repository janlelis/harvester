# encoding: utf-8
require 'rubygems' unless defined? Gem
require File.dirname(__FILE__) + "/lib/harvester"
 
Gem::Specification.new do |s|
  s.name        = "harvester"
  s.version     = Harvester::VERSION
  s.authors     = ["FIX"]
  s.email       = "FIX"
  s.homepage    = "https://github.com/astro/harvester"
  s.summary     = "Web-based feed aggregator in Ruby"
  s.description =  "FIX"
  s.required_ruby_version = ">= 1.9.2"
  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency 'dbi'
  s.add_dependency 'eventmachine'
  s.add_dependency 'em-http-request'
  s.add_dependency 'ruby-xslt'
  s.add_dependency 'hpricot'
  s.add_dependency 'rmagick'
  s.add_dependency 'gruff'
  s.add_dependency 'xmpp4r'
  s.files = Dir.glob(%w|lib/**/*.rb bin/* [A-Z]*.{txt,rdoc} data/**/*|) + %w|Rakefile harvester.gemspec|
  s.executables = %w|harvester harvester-fetch harvester-generate harvester-chart harvester-jabber|
  s.license = "FIX"
end
