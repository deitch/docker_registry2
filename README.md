# Docker Registry

## Introduction

This is a simple gem that provides direct http access to a docker registry v2 without going through a docker server. You do **not** require docker installed on your system to provide access.

````ruby
reg = DockerRegistry2.connect("https://my.registy.corp.com")
repos = reg.search("foo/repo")
tags = reg.tags("foo/repo")
````

Supports anonymous access, http authorization and v2 token access.

Inspired by https://github.com/rosylilly/docker_registry but written separately.

#### Note

Prior to version 0.4.0, the name used was DockerRegistry. As of 0.4.0 it is DockerRegistry2.
If you still need DockerRegistry, just create an alias with:

````ruby
DockerRegistry = DockerRegistry2
````

## Installation

Add the following to your Gemfile:

    gem 'docker_registry2'

And execute:

    bundle install

## Usage

Once it is installed, you first *open* a connection to a registry, and then *request* from the registry.

### Connecting
Use the `connect` method to connect to a registry:

````ruby
reg = DockerRegistry2.connect("https://my.registy.corp.com")
````

If you do not provide the URL for a registry, it uses the default `https://registry.hub.docker.com`.

By default, requests to the registry will timeout if they take over 2 seconds to
connect or over 5 seconds to respond. You can set different thresholds when
connecting to a registry as follows:

```ruby
opts = { open_timeout: 2, read_timeout: 5 }
reg = DockerRegistry2.connect("https://my.registy.corp.com", opts)
```

You can connect anonymously or with credentials:

#### Anonymous
To connect to a registry:

````ruby
reg = DockerRegistry2.connect("https://my.registy.corp.com")
````

The above will connect anonymously to the registry via the endpoint `https://my.registry.corp.com/v2/`.

The following exceptions are thrown:

* `RegistryAuthenticationException`: registry does not support anonymous access
* `RegistryUnknownException`: registry does not exist at the given URL
* `RegistrySSLException`: registry SSL certificate cannot be validated

#### Authenticated
If you wish to authenticate, pass a username and password as part of the options to `DockerRegistry.connect`.

````ruby
url = "https://my.registy.corp.com"
opts = {user: "me", password: "secretstuff"}
reg = DockerRegistry2.connect(url,opts)
````

**Note:** Older versions prior to 1.0.0 _used_ to support putting the username and password in the URL. We no longer support it as it is **strongly** discouraged in RFCs. Put it in the `opts` hash.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username/password combination is invalid
* `RegistryAuthorizationException`: username/password does not have sufficient rights to access this registry
* `RegistryUnknownException`: registry does not exist at the given URL
* `RegistrySSLException`: registry SSL certificate cannot be validated


### Requests
Once you have a valid `reg` object return by `DockerRegistry2.connect()`, you can make requests. As of this version, only search and tags are supported. Others will be added over time.


#### search
````ruby
results = reg.search("mylibs")
````

Returns all repositories whose name contains `"mylibs"`.

**Note:** The v2 registry does not support search directly server-side. Thus, this is simulated by using the `catalog/` endpoint. It is highly recommended to avoid using this function until the v2 registry supports direct search, as it will be slow. It pulls a list of all repositories to the client and then does a pattern match on them.

Returns an array of strings, each of which is the full name of a repository.

If no results are found, will return an empty array `[]`. An empty array will not throw an exception.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: user does not have sufficient rights to search in this registry

**NOTE:** The search endpoint relies on the catalog endpoint, which only is available from registry:2.1. If you try it prior to 2.1, you will get a `404` error.

#### tags
````ruby
results = reg.tags("mylibs",count=nil,last="",withHashes=false)
````

Returns all known tags for the repository precisely named `"mylibs"`.

Arguments:

* `repository`: name of the repository to return, e.g. "mylibs" above. Relative to the registry to which you connected. REQUIRED.
* `count`: how many records to return, if the registry supports pagination. Default is not to limit. The behaviour changes by registry implementation. See the section on pagination below. OPTIONAL.
* `last`: the last record returned, if using pagination. See the section on pagination below. OPTIONAL.
* `withHashes`: return the hash of the manifest for each tag. Note that retrieving the hashes is an expensive operations, as it requires a separate `HEAD` for each tag. This is why the default is `false`. OPTIONAL.

Returns an object with the following key value pairs:
 array of objects, each of which has the following key/value pairs:

* `name`: full name of repository, e.g. `redis` or `user/redis`.
* `tags`: array of strings, each of which is a tag for ths given repository.
* `hashes`: object, keys of which are the tag name, and values of which are the hash. Only provided if `withHashes` is true.
* `last`: the last entry returned, to be used for pagination, only returned if the results have been paginated by the server.

Other fields may be added later. Do *not* assume those are the only fields.

If no tags are found, or the named repository does not exist, return an empty object `{}`. An unknown repository will not throw an exception.

The response structure looks something like this:

````ruby
{
	"name" => "special/repo",
	"tags" => ["1.0","1.1","1.3","latest"],
	"hashes" => {
		"1.0" => "abc4567",
		"1.1" => "87def23",
		"1.3" => "998adf2",
		"latest" => "998adf2"
	}
}
````

It is important to note that the hashes **may** or **may not** match the hashes that you receive when running `docker images` on your machine. These are the hashes returned by the `Docker-Content-Digest` for the manifest. See [v2 API Spec](https://docs.docker.com/registry/spec/api/#get-manifest).

These **may** or **may not** be useful for comparing to the local image on disk when running `docker images`. These **are** useful for comparing 2 different tags or images in one or more registries.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support tags using the given credentials, probably because the repository is private and the credentials provided do not have access

##### pagination

Some regstries support pagination for tags per [this standard](https://docs.docker.com/registry/spec/api/#listing-image-tags). If the registry supports pagination, you have several options:

* Ignore it, and simply get back whatever the max number o tags the registry returns in whatever order. In many cases, this will work. `tags("repo")`
* Set an arbitrarily high number. Note that this may not work, as the registry may implement a limit below your cap. `tags("repo", 5000)`
* Work with pagination.

To work with pagination, after each result set, you keep getting a new result set until there are no more. In this case, with each request, the `tags()` results will tell you what the key of the last one was returned. You pass that into the next call, so it knows where to start for the next set of results. You also can choose to limit the `count`, or just accept whatever default the registry has set.

For example, let us assume that the registry has 26 tags, from `"a"` to `"z"`, and that it returns 3 tags with each call by default. Your first call:

```ruby
res = tags("repo")
# or, to limit to 3 explicilty
res = tags("repo")
```

Your results will be:

```ruby
{
        "name" => "repo",
        "tags" => ["a","b","c"],
	"last" => "c"
}
```

Note that it returned 3, either because that was the registry default or you explicitly limited to 3 results. It also told you that the last tag was `"c"`. You now can pass that on to the next request.

```ruby
res = tags("repo",nil,"c")
# or, to limit to 3 explicitly
res = tags("repo",3,"c")
```

The results will be:

```ruby
{
        "name" => "repo",
        "tags" => ["d","e","f"]
        "last" => "f"
}
```

Repeat until you have all of the results. The last one has no more pagination, and so the results will be without a `"last"` field:

```ruby
{
        "name" => "repo",
        "tags" => ["x","y","z"]
}
```


#### manifest

````ruby
manifest = reg.manifest("namespace/repo","2.5.6")
````

Returns the manifest for the given tag of the given repository. For the format and syntax of the manifest, see the [registry API](https://github.com/docker/distribution/blob/master/docs/spec/api.md) and the [manifest issue](https://github.com/docker/docker/issues/8093).

If the given repository and/or tag is not found, return an empty object `{}`.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support tags using the given credentials, probably because the repository is private and the credentials provided do not have access

The manifest, of course, is requested via http `GET`. While the returned manifest is an object parsed from the JSON of the manifest _body_, sometimes the http _headers_ are valuable as well. Thus the returned manifest object has a method `headers`, which returns the http headers from the request.

```ruby
manifest = reg.manifest("namespace/repo","2.5.6")
manifest.headers
```

#### blob

````ruby
blob = reg.blob("namespace/repo", "sha256:437f2acdb882407ad515c936c6f1cd9adbbb1340c8b271797723464c6ac71f9b")
````

Returns the blob for the given digest of the image of the given repository. For the format and syntax of the blob, see the [registry API](https://docs.docker.com/registry/spec/api/#blob) 

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support tags using the given 
* `NotFound`: Either the repo or blob cannot be found

The response is a json parsed hash containing the raw data returned from the registry, along with any headers set on the response

```
> blob['architecture']
=> "amd64"
> blob['os']
=> "linux"
> blob['docker_version']
=> "18.09.5"
> blob['created']
=> "2019-11-27T15:20:08.074155975Z"
> blob['config']['Labels']
=> {"label1" => "value1", "label2" => "value2"}
> blob.headers
=> {:accept_ranges=>"bytes", :cache_control=>"max-age=31536000", :content_length=>"8981", :content_type=>"application/octet-stream", :docker_content_digest=>"sha256:559b6d4cc7272cf47a2f15606c706319957f56120dfe369ce465dda9952009fb", :docker_distribution_api_version=>"registry/2.0", :etag=>"\"sha256:559b6d4cc7272cf47a2f15606c706319957f56120dfe369ce465dda9952009fb\"", :x_content_type_options=>"nosniff", :date=>"Sat, 30 Nov 2019 17:09:46 GMT"}
```

#### digest
````ruby
digest = reg.digest("namespace/repo", "2.5.6")
````

Returns the digest for the manifest represented by the tag of the given repository.

#### pull
````ruby
reg.pull("namespace/repo","2.5.6",dir)
````

Pulls the given tag of the given repository to the given `dir`. If given `dir`does not exist, will create it.

It is important to note that the image for a tag is not likely to be a single file, but rather multiple layers, each of which is an individual file. Thus, it is necessary to have a directory where the downloaded layers are to be kept. The actual docker engine stores these under `/var/lib/docker/`.

If the given repository and/or tag is not found, return an empty object `{}`.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support tags or pull using the given credentials, probably because the repository is private and the credentials provided do not have access.

#### push
> WARNING: Unimplemented

````ruby
reg.push(manifest,dir)
````

Pushes the given manifest to the registry, using images in the given `dir`. You are assumed to have created the manifest or gotten it from somewhere else. This is especially useful for moving an image from one registry to another. You can get the manifest, pull the layers, and push the manifest to a different registry.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support pushing the layers or uploading the manifest using the given credentials, probably because the repository is private and the credentials provided do not have access
* `MissingLayerException`: A layer from the manifest is missing from the given `dir` and thus cannot be pushed.

#### tag
````ruby
reg.tag("namespace/repo","tag",newrepo,newtag)
````

`tag` is a convenience method to create a new repository for a given repository in the same registry. For example, you have a registry at `https://my.registry.local`. In the registry is a repository named "myspace/repo", with a tag "1.2". You wish to duplicate "myspace/repo:1.2" to "myspace/repo:latest". Or, perhaps you wish to duplicate "myspace/repo:1.2" to "others/image:10.5". You can do it using `tag`:

````ruby
reg.tag("myspace/repo","1.2","myspace/repo","latest")
reg.tag("myspace/repo","1.2","other/image","10.5")
````

This is a convenience and efficiency method. Because it only manipulates the manifest, and not the layers (which already are present in the registry), it can do so quickly.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support pushing the layers or uploading the manifest using the given credentials, probably because the repository is private and the credentials provided do not have access
* `RegisteryVersionException`: registry does not support the v2 API.

#### copy
> WARNING: Unimplemented

````ruby
reg.copy("namespace/repo","tag",newregistry,newrepo,newtag)
````

`copy` copies an image from one registry to another. It does so in the following manner:

1. Download the manifest
2. Download all relevant layers
3. Modify the manifest as needed to reflect the `newrepo` and `newtag`
4. Upload the layers to `newregistry`
5. Upload the manifest to `newregistry`

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support pushing the layers or uploading the manifest using the given credentials, probably because the repository is private and the credentials provided do not have access

#### rmtag
````ruby
reg.rmtag("namespace/repo","tag")
````

`rmtag` removes a given tag from a repository.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support your deleting the given tag, probably because you do not have sufficient access rights.

#### rmrepo
````ruby
reg.rmrepo("namespace/repo")
````

`rmrepo` removes the named repository entirely.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support your deleting the given repository, probably because you do not have sufficient access rights.

#### Layer sizes
If you want to get the sizes of one or more layers in an image, you have several convenience functions available.

##### Total Size
If you want to add up easily all of the layers in a manifest (which, of course, should equal the total size of the image), you can pass the manifest to the `manifest_sum` method.

```ruby
manifest = reg.manifest "library/ubuntu", "16.04"
totalSize = reg.manifest_sum manifest
```

##### Single Blob
If you have the repo name and the sha256 hash for the blob, you can get the size of the layer by doing:

```ruby
reg.blob_size "namespace/repo", "sha256:abc5634737434"
```

Of course, most of the time you won't need this, since the sizes are already included in the same place you got the blob hashes in the first place: the manifest.


### Exceptions

All exceptions thrown inherit from `DockerRegistry2::Exception`.

## Tests
The simplest way to test is against a true v2 registry. Thus, the test setup and teardown work against a docker registry. That means that to test, you need a docker engine running. The tests will start up a registry (actually, two registries, to be able to test `copy()`), initialize the data and test against them.

To run tests, simply run

```sh
make test
```

This will run `./test.sh`, which will set up a docker registry in a container, run the tests, and then tear it down.

If you are running on a system where you already have a registry against which to run, and/or cannot run `docker` commands, you can pass it the URL to which to connect for tests:

```sh
make test TEST_REGISTRY=http://registry:5000/   # replace with the URL to your registry
# or to run manually
TEST_REGISTRY=http://registry:5000/ ./test.sh
```

## License

MIT License.

## Contribution

Developed by Avi Deitcher http://github.com/deitch
Contributors Jonathan Hurter https://github.com/johnsudaar
Contributions courtesy of TraderTools, Inc. http://tradertools.com
