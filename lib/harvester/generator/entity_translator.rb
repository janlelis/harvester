# encoding: utf-8
class Harvester; class Generator; end; end

# This module translates old-fashioned entities into utf-8
class Harvester::Generator::EntityTranslator
  def self.run(doc, with_xmldecl = true, logger = nil)
    @logger = logger || Logger.new(STDOUT)

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
    translate_entities(doc, with_xmldecl)
  end

  def self.load_entities_from_file(filename)
    File.read(filename).scan(/<!ENTITY +(.+?) +CDATA +"(.+?)".+?>/m) do |ent,code|
      @entities[ent] = code
    end
  end

  def self.translate_entities(doc, with_xmldecl = true)
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
end

