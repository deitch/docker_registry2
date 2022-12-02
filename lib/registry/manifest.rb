# frozen_string_literal: true

module DockerRegistry2
  class Manifest < Hash
    attr_accessor :body, :headers
  end
end
