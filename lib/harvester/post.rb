# encoding: utf-8

require_relative '../harvester'

class Harvester
  module POST; end

  def post!(path = nil)
    task "post process" do
      if post_script = path || @config['settings']['post_script']
        error "Cannot find an executable script at #{ post_script }" unless test('x', post_script)
        exec post_script, @config['settings']['output']
      else
        warn 'No post processing script configured or passed as argument!'
      end
    end#task
  end
end
