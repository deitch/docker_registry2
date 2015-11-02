# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'registry/version'

Gem::Specification.new do |spec|
  spec.name          = 'docker_registry2'
  spec.version       = DockerRegistry::VERSION
  spec.authors       = ['Avi Deitcher']
  spec.summary       = 'Docker v2 registry HTTP API client'
  spec.description   = 'Docker v2 registry HTTP API client with support for token authentication'
  spec.homepage      = 'https://github.com/deitch/docker_registry2'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '>= 0.26.0'

  spec.add_dependency 'rest-client', '>= 1.8.0'
end