# frozen_string_literal: true

require './lib/docker_registry2'

reg = DockerRegistry2.connect
man = reg.manifest 'library/alpine', 'latest'
puts 'MANIFEST'
puts man
puts 'HEADER'
puts man.headers
