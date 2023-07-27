# frozen_string_literal: true

require "#{File.dirname(__FILE__)}/registry/version"
require "#{File.dirname(__FILE__)}/registry/registry"
require "#{File.dirname(__FILE__)}/registry/exceptions"
require "#{File.dirname(__FILE__)}/registry/manifest"
require "#{File.dirname(__FILE__)}/registry/blob"

module DockerRegistry2
  def self.connect(uri = 'https://registry.hub.docker.com', opts = {})
    @reg = DockerRegistry2::Registry.new(uri, opts)
  end

  def self.search(query = '')
    @reg.search(query)
  end

  def self.tags(repository)
    @reg.tags(repository)
  end

  def self.manifest(repository, tag)
    @reg.manifest(repository, tag)
  end

  def self.manifest_digest(repository, tag)
    @reg.manifest_digest(repository, tag)
  end
end
