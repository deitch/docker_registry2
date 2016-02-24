require File.dirname(__FILE__) + '/registry/version'
require File.dirname(__FILE__) + '/registry/registry'
require File.dirname(__FILE__) + '/registry/exceptions'


module DockerRegistry
  def self.connect(uri)
    @reg = DockerRegistry::Registry.new(uri)
  end  
  
  def self.search(query = '')
    @reg.search(query)
  end

  def self.tags(repository)
    @reg.tags(repository)
  end  
  
  def self.manifest(repository,tag)
    @reg.manifest(repository,tag)
  end
end