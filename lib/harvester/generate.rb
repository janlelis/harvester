# encoding: utf-8

require_relative '../harvester'
require_relative 'generate/link_absolutizer'
require_relative 'generate/entity_translator'

require 'fileutils'
require 'time'
require 'rexml/document'
begin
  require 'xml/xslt'
rescue LoadError
  require 'xml/libxslt'
end

class Harvester
  def generate!
    f        = Generate.new @dbi
    xslt     = XML::XSLT.new
    xslt.xml = f.generate_root.to_s

    default_template_dir = File.dirname(__FILE__) + '/../../data/templates'
    template_dir = @config['settings']['templates'] || default_template_dir
    output_dir   = @config['settings']['output']

    FileUtils.mkdir_p output_dir
    puts "Copying static files"
    FileUtils.cp_r Dir[File.join( template_dir, 'static', '*' )], output_dir

    begin
      Dir.foreach(template_dir) { |template_file|
        next if template_file =~ /^\./ || template_file == 'static'

        puts "Processing #{template_file}"
        xslt.xsl = File.join( template_dir, template_file )
        File::open( File.join( output_dir, template_file ), 'w') { |f| f.write(xslt.serve) }
      }
    rescue Errno::ENOENT
      $stderr.puts "Couldn't find templates directory, fallback to default templates!"
      template_dir = default_template_dir
      retry
    end
  end
end

class Harvester::Generate
  FUNC_NAMESPACE = 'http://astroblog.spaceboyz.net/harvester/xslt-functions'

  def initialize(dbi)
    @dbi = dbi
    %w(collection-items feed-items item-description item-images item-enclosures).each { |func|
      XML::XSLT.extFunction(func, FUNC_NAMESPACE, self)
    }
  end

  def generate_root
    root = REXML::Element.new('collections')
    @dbi.execute("SELECT collection FROM sources GROUP BY collection").each{ |name,|
      collection = root.add(REXML::Element.new('collection'))
      collection.attributes['name'] = name
      @dbi.execute("SELECT rss,title,link,description FROM sources WHERE collection=?", name).each{ |rss,title,link,description|
        #p [title, description]
        feed = collection.add(REXML::Element.new('feed'))
        feed.add(REXML::Element.new('rss')).text = rss
        feed.add(REXML::Element.new('title')).text = title
        feed.add(REXML::Element.new('link')).text = link
        feed.add(REXML::Element.new('description')).text = description
      }
    }

    EntityTranslator.run(root)
  end

  def collection_items(collection, max=23)
    items = REXML::Element.new('items')
    @dbi.execute("SELECT items.title,items.date,items.link,items.rss FROM items,sources WHERE items.rss=sources.rss AND sources.collection LIKE ? ORDER BY items.date DESC LIMIT ?", collection, max.to_i).each{ |title,date,link,rss|
      if title # TODO: debug (sqlite)
        item = items.add(REXML::Element.new('item'))
        item.add(REXML::Element.new('title')).text = title
        item.add(REXML::Element.new('date')).text = date.to_time.xmlschema
        item.add(REXML::Element.new('link')).text = link
        item.add(REXML::Element.new('rss')).text = rss
      end
    }

    EntityTranslator.run(items)
  end

  def feed_items(rss, max=23)
    items = REXML::Element.new('items')
    @dbi.execute("SELECT title,date,link FROM items WHERE rss=? ORDER BY date DESC LIMIT ?", rss, max.to_i).each{ |title,date,link| p rss,title,date,link
      # p title
      if title # TODO: debug (sqlite)
        item = items.add(REXML::Element.new('item'))
        item.add(REXML::Element.new('title')).text = title
        item.add(REXML::Element.new('date')).text = date.to_time.xmlschema
        item.add(REXML::Element.new('link')).text = link
      end
    }

    EntityTranslator.run(items)
  end

  def item_description(rss, item_link)
    # FIXME!!!! tmp ugly sqlite fix
    if @dbi.driver.class.to_s =~ /sqlite3/i
    a= "SELECT description FROM items WHERE rss='%s' AND link='%s'" % [rss, item_link].map{|e|::SQLite3::Database.quote(e) }
    b= @dbi.execute(a).fetch
    else
    b= @dbi.execute("SELECT description FROM items WHERE rss=? AND link=?", rss, item_link).fetch
    end
    b.each{ |desc|
      desc = EntityTranslator.run(desc, false)
      desc = LinkAbsolutizer.run(desc, item_link)
      return desc
    }
    ''
  end

  def item_images(rss, item_link)
    desc = "<description>" + item_description(rss, item_link) + "</description>"
    images = REXML::Element.new('images')
    REXML::Document.new(desc.to_s).root.each_element('//img') { |img|
      images.add img
    }
    mages
  end

  def item_enclosures(rss, link)
    #p [rss,link]
    enclosures = REXML::Element.new('enclosures')
    @dbi.execute("SELECT href, mime, title, length FROM enclosures WHERE rss=? AND link=? ORDER BY length DESC", rss, link).each{ |href,mime,title,length|
      enclosure = enclosures.add(REXML::Element.new('enclosure'))
      enclosure.add(REXML::Element.new('href')).text = href
      enclosure.add(REXML::Element.new('mime')).text = mime
      enclosure.add(REXML::Element.new('title')).text = title
      enclosure.add(REXML::Element.new('length')).text = length
    }
    #p enclosures.to_s
    enclosures
  end
end

