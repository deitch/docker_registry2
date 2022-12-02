# frozen_string_literal: true

module DockerRegistry2
  class Exception < RuntimeError
  end

  class RegistryAuthenticationException < StandardError
  end

  class RegistryAuthorizationException < StandardError
  end

  class RegistryUnknownException < StandardError
  end

  class RegistrySSLException < StandardError
  end

  class RegistryVersionException < StandardError
  end

  class ReauthenticatedException < StandardError
  end

  class UnknownRegistryException < StandardError
  end

  class NotFound < StandardError
  end

  class InvalidMethod < StandardError
  end
end
