# frozen_string_literal: true

module DockerRegistry2
  # Manifest class represents a manfiest or index in an OCI registry
  class Manifest < Hash
    attr_accessor :body, :headers
  end
end
