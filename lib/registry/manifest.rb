module DockerRegistry2

  class Manifest < Hash
    attr_accessor :body, :headers
    def initialize
      super
    end
  end
end
