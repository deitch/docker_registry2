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
  
  def doget(url, token=nil)
    begin
      # do we already have a token to authenticate?
      if token.nil?
        response = RestClient.get @base_uri+url
      else
        response = RestClient.get @base_uri+url, Authorization: 'Bearer '+token
      end
    rescue SocketError
      raise DockerRegistry::RegistryUnknownException
    rescue RestClient::Unauthorized => e
      # unauthorized
      # did we already try for this realm and service and scope and have insufficient privileges?
      if token.nil?
        token = authenticate e.response.headers[:www_authenticate]
        # go do whatever you were going to do again
        response = doget url, token
      else
        throw DockerRegistry::RegistryAuthorizationException
      end
    rescue RestClient::ResourceNotFound
      raise DockerRegistry::UnknownRegistry
    end
    return response
  end
  
  def authenticate(header)
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
    JSON.parse response
  end

  def tags(repo)
    response = doget "/v2/#{repo}/tags/list"
    # parse the response
    JSON.parse response
  end
end