# encoding: utf-8
require 'singleton'

class Harvester; class Generate; end; end

class Harvester::Generate::EntityTranslator
  include Singleton

  def initialize
    @entities = {}
    %w(HTMLlat1.ent HTMLsymbol.ent HTMLspecial.ent).each do |file|
      begin
        load_entities_from_file(
          File.expand_path( File.dirname(__FILE__) + '/../../../data/ent/' + file )
        )
      #rescue Errno::ENOENT
      #  system("wget http://www.w3.org/TR/html4/#{file}")
      #  load_entities_from_file(file)
      end
    end
  end

  def load_entities_from_file(filename)
    File.read(filename).scan(/<!ENTITY +(.+?) +CDATA +"(.+?)".+?>/m) do |ent,code|
      @entities[ent] = code
    end
  end

  def translate_entities(doc, with_xmldecl = true)
    oldclass = doc.class
    doc = doc.to_s

    @entities.each do |ent,code|
      doc.gsub!("&#{ent};", code)
    end

    doc = "<?xml version='1.0' encoding='utf-8'?>\n#{doc}" if with_xmldecl

    if oldclass == REXML::Element
      REXML::Document.new(doc).root
    else
      doc
    end
  end

  def self.run(doc, with_xmldecl = true)
    instance.translate_entities(doc, with_xmldecl)
  end
end

