# frozen_string_literal: true

module DockerRegistry2
  class Blob
    attr_reader :body, :headers

    def initialize(headers, body)
      @headers = headers
      @body = body
    end
  end
end
