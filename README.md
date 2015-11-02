# Docker Registry

## Introduction

This is a simple gem that provides direct http access to a docker registry v2 without going through a docker server. You do **not** requires docker installed on your system to provide access.

````ruby
reg = DockerRegistry.new("https://my.registy.corp.com")
repos = reg.search("foo/repo")
tags = reg.tags("foo/repo")
````

Supports anonymous access, http authorization and v2 token access.

Inspired by https://github.com/rosylilly/docker_registry but written separately.


## Installation

Add the following to your Gemfile:

    gem 'docker_registry2`

And execute:

    bundle install

## Usage

Once it is installed, you first *open* a connection to a registry, and then *request* from the registry.

### Connecting

#### Anonymous
To connect to a registry:

````ruby
reg = DockerRegistry.new("https://my.registy.corp.com")
````

The above will connect anonymously to the registry via the endpoint `https://my.registry.corp.com/v2/`.

The following exceptions are thrown:

* `RegistryAuthenticationException`: registry does not support anonymous access
* `RegistryUnknownException`: registry does not exist at the given URL
* `RegistrySSLException`: registry SSL certificate cannot be validated

#### Authenticated
If you wish to authenticate, pass a username and password as the second and third parameters.

````ruby
reg = DockerRegistry.connect("https://myuser:mypass@my.registy.corp.com")
````

The following exceptions are thrown:

* `RegistryAuthenticationException`: username/password combination is invalid
* `RegistryAuthorizationException`: username/password does not have sufficient rights to access this registry
* `RegistryUnknownException`: registry does not exist at the given URL
* `RegistrySSLException`: registry SSL certificate cannot be validated


### Requests
Once you have a valid `reg` object return by `DockerRegistry.new()`, you can make requests. As of this version, only search and tags are supported. Others will be added over time.


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
results = reg.tags("mylibs")
````

Returns all known tags for the repository precisely named `"mylibs"`. 

Returns an object with the following key value pairs:
 array of objects, each of which has the following key/value pairs:

* `name`: full name of repository, e.g. `redis` or `user/redis`
* `tags`: array of strings, each of which is a tag for ths given repository

Other fields may be added later. Do *not* assume those are the only fields.

If no tags are found, or the named repository does not exist, return an empty object `{}`. An unknown repository will not throw an exception.

The following exceptions are thrown:

* `RegistryAuthenticationException`: username and password are invalid
* `RegistryAuthorizationException`: registry does not support tags using the given credentials, probably because the repository is private and the credentials provided do not have access

### Exceptions

All exceptions thrown inherit from `DockerRegistry::Exception`.

## License

MIT License.

## Contribution

Developed by Avi Deitcher http://github.com/deitch 
Contributions courtesy of TraderTools, Inc. http://tradertools.com




