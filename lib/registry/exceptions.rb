# frozen_string_literal: true

module DockerRegistry2
  class Exception < RuntimeError
  end

  class RegistryAuthenticationException < DockerRegistry2::Exception
  end

  class RegistryAuthorizationException < DockerRegistry2::Exception
  end

  class RegistryUnknownException < DockerRegistry2::Exception
  end

  class RegistrySSLException < DockerRegistry2::Exception
  end

  class RegistryVersionException < DockerRegistry2::Exception
  end

  class ReauthenticatedException < DockerRegistry2::Exception
  end

  class UnknownRegistryException < DockerRegistry2::Exception
  end

  class NotFound < DockerRegistry2::Exception
  end

  class InvalidMethod < DockerRegistry2::Exception
  end
end
