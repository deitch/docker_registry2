require 'fileutils'
require 'rest-client'
require 'json'

class DockerRegistry2::Registry
  # @param [#to_s] base_uri Docker registry base URI
  # @param [Hash] options Client options
  # @option options [#to_s] :user User name for basic authentication
  # @option options [#to_s] :password Password for basic authentication
  # @option options [#to_s] :open_timeout Time to wait for a connection with a registry
  # @option options [#to_s] :read_timeout Time to wait for data from a registry
  def initialize(uri, options = {})
    @uri = URI.parse(uri)
    @base_uri = "#{@uri.scheme}://#{@uri.host}:#{@uri.port}"
    @user = options[:user]
    @password = options[:password]
    @open_timeout = options[:open_timeout] || 2
    @read_timeout = options[:read_timeout] || 5
  end

  def doget(url)
    return doreq "get", url
  end

  def doput(url,payload=nil)
    return doreq "put", url, nil, payload
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

  def tags(repo,count=nil,last="",withHashes = false, auto_paginate: false)
    #create query params
    params = []
    params.push(["last",last]) if last && last != ""
    params.push(["n",count]) unless count.nil?

    query_vars = ""
    query_vars = "?#{URI.encode_www_form(params)}" if params.length > 0

    response = doget "/v2/#{repo}/tags/list#{query_vars}"
    # parse the response
    resp = JSON.parse response
    # parse out next page link if necessary
    resp["last"] = last(response.headers[:link]) if response.headers[:link]

    # do we include the hashes?
    if withHashes
      useGet = false
      resp["hashes"] = {}
      resp["tags"].each do |tag|
        if useGet
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
      end
    end

    return resp unless auto_paginate

    while (last_tag = resp.delete("last"))
      additional_tags = tags(repo, count, last_tag, withHashes)
      resp["last"] = additional_tags["last"]
      resp["tags"] += additional_tags["tags"]
      resp["tags"] = resp["tags"].uniq
      resp["hashes"].merge!(additional_tags["hashes"]) if withHashes
    end

    resp
  end

  def manifest(repo,tag)
    # first get the manifest
    response = doget "/v2/#{repo}/manifests/#{tag}"
    parsed = JSON.parse response.body
    manifest = DockerRegistry2::Manifest[parsed]
    manifest.body = response.body
    manifest.headers = response.headers
    manifest
  end

  def blob(repo, digest)
    response = doget "/v2/#{repo}/blobs/#{digest}"
    parsed = JSON.parse response.body
    blob = DockerRegistry2::Blob[parsed]
    blob.body = response.body
    blob.headers = response.headers
    blob 
  end

  def digest(repo, tag)
    tag_path = "/v2/#{repo}/manifests/#{tag}"
    dohead(tag_path).headers[:docker_content_digest]
  rescue DockerRegistry2::InvalidMethod
    # Pre-2.3.0 registries didn't support manifest HEAD requests
    doget(tag_path).headers[:docker_content_digest]
  end

  def rmtag(image, tag)
    # TODO: Need full response back. Rewrite other manifests() calls without JSON?
    reference = doget("/v2/#{image}/manifests/#{tag}").headers[:docker_content_digest]

    return dodelete("/v2/#{image}/manifests/#{reference}").code
  end

  def pull(repo, tag, dir)
    # make sure the directory exists
    FileUtils.mkdir_p dir
    # get the manifest
    m = manifest repo, tag
    # puts "pulling #{repo}:#{tag} into #{dir}"
    # manifest can contain multiple manifests one for each API version
    downloaded_layers = []
    downloaded_layers += _pull_v2(repo, m, dir) if m['schemaVersion'] == 2
    downloaded_layers += _pull_v1(repo, m, dir) if m['schemaVersion'] == 1
    # return downloaded_layers
    downloaded_layers
  end

  def _pull_v2(repo, manifest, dir)
    # make sure the directory exists
    FileUtils.mkdir_p dir
    return false unless manifest['schemaVersion'] == 2
    # pull each of the layers
    manifest['layers'].each do |layer|
      # define path of file to save layer in
      layer_file = "#{dir}/#{layer['digest']}"
      # skip layer if we already got it
      next if File.file? layer_file
      # download layer
      # puts "getting layer (v2) #{layer['digest']}"
      File.open(layer_file, 'w') do |fd|
        doreq('get',
              "/v2/#{repo}/blobs/#{layer['digest']}",
              fd)
      end
      layer_file
    end
  end

  def _pull_v1(repo, manifest, dir)
    # make sure the directory exists
    FileUtils.mkdir_p dir
    return false unless manifest['schemaVersion'] == 1
    # pull each of the layers
    manifest['fsLayers'].each do |layer|
      # define path of file to save layer in
      layer_file = "#{dir}/#{layer['blobSum']}"
      # skip layer if we already got it
      next if File.file? layer_file
      # download layer
      # puts "getting layer (v1) #{layer['blobSum']}"
      File.open(layer_file, 'w') do |fd|
        doreq('get',
              "/v2/#{repo}/blobs/#{layer['blobSum']}",
              fd)
      end
      # return layer file
      layer_file
    end
  end

  def push(manifest,dir)
  end

  def tag(repo,tag,newrepo,newtag)
    manifest = manifest(repo, tag)

    if manifest['schemaVersion'] == 2
      doput "/v2/#{newrepo}/manifests/#{newtag}", manifest.to_json
    else
      raise DockerRegistry2::RegistryVersionException
    end
  end

  def copy(repo,tag,newregistry,newrepo,newtag)
  end

  # gets the size of a particular blob, given the repo and the content-addressable hash
  # usually unneeded, since manifest includes it
  def blob_size(repo,blobSum)
    response = dohead "/v2/#{repo}/blobs/#{blobSum}"
    Integer(response.headers[:content_length],10)
  end

  def last(header)
    last=''
    parts = header.split(',')
    links = Hash.new

    # Parse each part into a named link
    parts.each do |part, index|
      section = part.split(';')
      url = section[0][/<(.*)>/,1]
      name = section[1][/rel="(.*)"/,1].to_sym
      links[name] = url
    end

    if links[:next]
      query=URI(links[:next]).query
      last=URI::decode_www_form(query).to_h["last"]
    end
    last
  end

  def manifest_sum(manifest)
    size = 0
    manifest["layers"].each { |layer|
      size += layer["size"]
    }
    size
  end

  private
    def doreq(type,url,stream=nil,payload=nil)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute(
          method: type,
          url: @base_uri+url,
          headers: headers(payload: payload),
          block_response: block,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          payload: payload
        )
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::NotFound => error
        raise DockerRegistry2::NotFound, error
      rescue RestClient::Unauthorized => e
        header = e.response.headers[:www_authenticate]
        method = header.downcase.split(' ')[0]
        case method
        when 'basic'
          response = do_basic_req(type, url, stream, payload)
        when 'bearer'
          response = do_bearer_req(type, url, header, stream, payload)
        else
          raise DockerRegistry2::RegistryUnknownException
        end
      end
      return response
    end

    def do_basic_req(type, url, stream=nil, payload=nil)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute(
          method: type,
          url: @base_uri+url,
          user: @user,
          password: @password,
          headers: headers(payload: payload),
          block_response: block,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          payload: payload
        )
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::Unauthorized
        raise DockerRegistry2::RegistryAuthenticationException
      rescue RestClient::MethodNotAllowed
        raise DockerRegistry2::InvalidMethod
      rescue RestClient::NotFound => error
        raise DockerRegistry2::NotFound, error
      end
      return response
    end

    def do_bearer_req(type, url, header, stream=false, payload=nil)
      token = authenticate_bearer(header)
      begin
        block = stream.nil? ? nil : proc { |response|
          response.read_body do |chunk|
            stream.write chunk
          end
        }
        response = RestClient::Request.execute(
          method: type,
          url: @base_uri+url,
          headers: headers(payload: payload, bearer_token: token),
          block_response: block,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout,
          payload: payload
        )
      rescue SocketError
        raise DockerRegistry2::RegistryUnknownException
      rescue RestClient::Unauthorized
        raise DockerRegistry2::RegistryAuthenticationException
      rescue RestClient::MethodNotAllowed
        raise DockerRegistry2::InvalidMethod
      rescue RestClient::NotFound => error
        raise DockerRegistry2::NotFound, error
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
        response = RestClient::Request.execute(
          method: :get,
          url: uri.to_s, headers: {params: target[:params]},
          user: @user,
          password: @password,
          open_timeout: @open_timeout,
          read_timeout: @read_timeout
        )
      rescue RestClient::Unauthorized, RestClient::Forbidden
        # bad authentication
        raise DockerRegistry2::RegistryAuthenticationException
      rescue RestClient::NotFound => error
        raise DockerRegistry2::NotFound, error
      end
      # now save the web token
      result = JSON.parse(response)
      return result["token"] || result["access_token"]
    end

    def split_auth_header(header = '')
      h = Hash.new
      h = {params: {}}
      header.scan(/([\w]+)\=\"([^"]+)\"/) do |entry|
        case entry[0]
        when 'realm'
          h[:realm] = entry[1]
        else
          h[:params][entry[0]] = entry[1]
        end
      end
      h
    end

    def headers(payload: nil, bearer_token: nil)
      headers={}
      headers['Authorization']="Bearer #{bearer_token}" unless bearer_token.nil?
      headers['Accept']='application/vnd.docker.distribution.manifest.v2+json, application/json' if payload.nil?
      headers['Content-Type']='application/vnd.docker.distribution.manifest.v2+json' unless payload.nil?

      headers
    end
end
