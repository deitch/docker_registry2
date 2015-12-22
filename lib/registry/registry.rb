require 'rest-client'
require 'json'

class DockerRegistry::Registry
  # @param [#to_s] base_uri Docker registry base URI
  # @param [Hash] options Client options
  # @option options [#to_s] :user User name for basic authentication
  # @option options [#to_s] :password Password for basic authentication
  def initialize(uri, options = {})
    @uri = URI.parse(uri)
    @base_uri = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}"
    @user = @uri.user
    @password = @uri.password
    # make a ping connection
    ping
  end

  def doget(url)
    begin
      response = RestClient.get @base_uri+url
    rescue SocketError
      raise DockerRegistry::RegistryUnknownException
    rescue RestClient::Unauthorized => e
      header = e.response.headers[:www_authenticate]
      method = header.downcase.split(' ')[0]
      case method
      when 'basic'
        response = do_basic_get(url)
      when 'bearer'
        response = do_bearer_get(url, header)
      else
        raise DockerRegistry::RegistryUnknownException
      end
    end
    return response
  end

  def do_basic_get(url)
    begin
      res = RestClient::Resource.new( @base_uri+url, @user, @password)
      response = res.get
    rescue SocketError
      raise DockerRegistry::RegistryUnknownException
    rescue RestClient::Unauthorized
      raise DockerRegistry::RegistryAuthenticationException
    end
    return response
  end

  def do_bearer_get(url, header)
    token = authenticate_bearer(header)
    begin
      response = RestClient.get @base_uri+url, Authorization: 'Bearer '+token
    rescue SocketError
      raise DockerRegistry::RegistryUnknownException
    rescue RestClient::Unauthorized
      raise DockerRegistry::RegistryAuthenticationException
    end

    return response
  end

  def authenticate_bearer(header)
    # get the parts we need
    target = split_auth_header(header)
    # did we have a username and password?
    if defined? @user and @user.to_s.strip.length != 0
      target[:params][:account] = @user
    end
    # authenticate against the realm
    uri = URI.parse(target[:realm])
    uri.user = @user if defined? @user
    uri.password = @password if defined? @password
    begin
      response = RestClient.get uri.to_s, {params: target[:params]}
    rescue RestClient::Unauthorized
      # bad authentication
      raise DockerRegistry::RegistryAuthenticationException
    end
    # now save the web token
    return JSON.parse(response)["token"]
  end

  def split_auth_header(header = '')
    h = Hash.new
    h = {params: {}}
    header.split(/[\s,]+/).each {|entry|
      p = entry.split('=')
      case p[0]
      when 'Bearer'
      when 'realm'
        h[:realm] = p[1].gsub(/(^\"|\"$)/,'')
      else
        h[:params][p[0]] = p[1].gsub(/(^\"|\"$)/,'')
      end
    }
    h
  end

  def ping
    response = doget '/v2/'
  end

  def search(query = '')
    response = doget "/v2/_catalog"
    # parse the response
    repos = JSON.parse(response)["repositories"]
    if query.strip.length > 0
      re = Regexp.new query
      repos = repos.find_all {|e| re =~ e }
    end
    return repos
  end

  def tags(repo)
    response = doget "/v2/#{repo}/tags/list"
    # parse the response
    JSON.parse response
  end
end
