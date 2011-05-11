# encoding: utf-8
require 'rubygems' unless defined? Gem
require File.dirname(__FILE__) + "/lib/harvester"
 
Gem::Specification.new do |s|
  s.name        = "harvester"
  s.version     = Harvester::VERSION
  s.authors     = ["astro", "Neingeist", "Tigion", "Josef Spillner", "Jan Lelis"]
  s.email       = "FIX"
  s.homepage    = "https://github.com/astro/harvester"
  s.summary     = "Web-based feed aggregator"
  s.description = "The harvester collects your favourite feeds and generates static html/feed pages"
  s.required_ruby_version = ">= 1.9.2"
  s.required_rubygems_version = ">= 1.3.6"
  # main
  s.add_dependency 'rdbi'
  s.add_dependency 'rdbi-driver-sqlite3'
  s.add_dependency 'logger-colors'
  # fetch
  s.add_dependency 'eventmachine'
  s.add_dependency 'em-http-request'
  # generate
  s.add_dependency 'ruby-xslt'
  s.add_dependency 'hpricot'
  # chart
  s.add_dependency 'rmagick'
  s.add_dependency 'gruff'
  # clock
  s.add_dependency 'clockwork'
  # jabber
  s.add_dependency 'xmpp4r'
  s.files = Dir.glob(%w|lib/**/*.rb bin/* [A-Z]*.{txt,rdoc} data/**/* *.yaml|) + %w|Rakefile harvester.gemspec|
  s.executables = Dir['bin/*'].map{|f| File.basename f }
  s.license = "FIX"
end
