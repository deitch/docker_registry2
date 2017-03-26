#!ruby

require "rubygems"

spec = Gem::Specification::load("docker_registry2.gemspec")
puts spec.name.to_s+'-'+spec.version.to_s+'.gem'
