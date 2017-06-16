require 'fileutils'
require 'rest-client'
require 'json'

class DockerRegistry2::Registry
  # @param [#to_s] base_uri Docker registry base URI
  # @param [Hash] options Client options
  # @option options [#to_s] :user User name for basic authentication
  # @option options [#to_s] :password Password for basic authentication
  def initialize(uri, options = {})
    @uri = URI.parse(uri)
    @base_uri = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}"
    @user = options[:user]
    @password = options[:password]
    # make a ping connection
    ping
  end

  def doget(url)
    return doreq "get", url
  end

  def dodelete(url)
    return doreq "delete", url
  end

  def dohead(url)
    return doreq "head", url
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

  def tags(repo,withHashes = false)
    response = doget "/v2/#{repo}/tags/list"
    # parse the response
    resp = JSON.parse response
    # do we include the hashes?
    if withHashes then
      useGet = false
      resp["hashes"] = {}
      resp["tags"].each {|tag|
        if useGet then
          head = doget "/v2/#{repo}/manifests/#{tag}"
        else
          begin
            head = dohead "/v2/#{repo}/manifests/#{tag}"
          rescue DockerRegistry2::InvalidMethod
            # in case we are in a registry pre-2.3.0, which did not support manifest HEAD
            useGet = true
            head = doget "/v2/#{repo}/manifests/#{tag}"
          end
        end
        resp["hashes"][tag] = head.headers[:docker_content_digest]
      }
    end

    return resp
  end

  def manifest(repo,tag)
    # first get the manifest
    JSON.parse doget "/v2/#{repo}/manifests/#{tag}"
  end

  def rmtag(image, tag)
    # TODO: Need full response back. Rewrite other manifests() calls without JSON?
    reference = doget("/v2/#{image}/manifests/#{tag}").headers[:docker_content_digest]

    return dodelete("/v2/#{image}/manifests/#{reference}").code
  end

  def pull(repo,tag,dir)
    # make sure the directory exists
    FileUtils::mkdir_p dir
    # get the manifest
    m = manifest repo,tag
    # pull each of the layers
    m["layers"].each { |layer|
      # make sure the layer does not exist first
      if ! File.file? "#{dir}/#{layer.blobSum}" then
        doget "/v2/#{repo}/blobs/#{layer.blobSum}" "#{dir}/#{layer.blobSum}"
      end
    }
  end

  def push(manifest,dir)
  end

  def tag(repo,tag,newrepo,newtag)
  end

  def copy(repo,tag,newregistry,newrepo,newtag)
  end

  # gets the size of a particular blob, given the repo and the content-addressable hash
  # usually unneeded, since manifest includes it
  def blob_size(repo,blobSum)
    response = dohead "/v2/#{repo}/blobs/#{blobSum}"
    Integer(response.headers[:content_length],10)
  end

  def manifest_sum(manifest)
    size = 0
    manifest["layers"].each { |layer|
      size += layer["size"]
    }
    size
  end

  private
    def doreq(type,url,stream=nil)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute method: type, url: @base_uri+url, headers: {Accept: 'application/vnd.docker.distribution.manifest.v2+json'}, block_response: block
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::Unauthorized => e
        header = e.response.headers[:www_authenticate]
        method = header.downcase.split(' ')[0]
        case method
        when 'basic'
          response = do_basic_req(type, url, stream)
        when 'bearer'
          response = do_bearer_req(type, url, header, stream)
        else
          raise DockerRegistry2::RegistryUnknownException
        end
      end
      return response
    end

    def do_basic_req(type, url, stream=nil)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute method: type, url: @base_uri+url, user: @user, password: @password, headers: {Accept: 'application/vnd.docker.distribution.manifest.v2+json'}, block_response: block
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::Unauthorized
        raise DockerRegistry2::RegistryAuthenticationException
      rescue RestClient::MethodNotAllowed
        raise DockerRegistry2::InvalidMethod
      end
      return response
    end

    def do_bearer_req(type, url, header, stream=false)
      token = authenticate_bearer(header)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute method: type, url: @base_uri+url, headers: {Authorization: 'Bearer '+token, Accept: 'application/vnd.docker.distribution.manifest.v2+json'}, block_response: block
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::Unauthorized
        raise DockerRegistry2::RegistryAuthenticationException
      rescue RestClient::MethodNotAllowed
        raise DockerRegistry2::InvalidMethod
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
      begin
        response = RestClient::Request.execute method: :get, url: uri.to_s, headers: {params: target[:params]}, user: @user, password: @password
      rescue RestClient::Unauthorized
        # bad authentication
        raise DockerRegistry2::RegistryAuthenticationException
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
end
