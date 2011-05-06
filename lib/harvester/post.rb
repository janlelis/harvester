# encoding: utf-8

require_relative '../harvester'

class Harvester
  def post!(path)
    if post_script = path || @config['settings']['post']
      # raise "Cannot find an executable script at #{ post_script }" unless test('x', post_script)
      exec post_script, @config['settings']['output']
    else
      puts 'No post processing script configured or passed as argument!'
    end
  end
end
