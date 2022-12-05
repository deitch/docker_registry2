#!ruby
# frozen_string_literal: true

require 'rubygems'

spec = Gem::Specification.load('docker_registry2.gemspec')
puts "#{spec.name}-#{spec.version}.gem"
