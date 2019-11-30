module DockerRegistry2
  class Blob < Hash
    attr_accessor :body, :headers
    def initialize
      super
    end
  end
end
