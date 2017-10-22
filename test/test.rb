#!ruby
require 'tmpdir'
require_relative '../lib/docker_registry2'
version = ENV["VERSION"]
reg = DockerRegistry2.connect "http://localhost:5000/"

# do we have tags?
image = "hello-world-"+version
tags = reg.tags image
if tags == nil || tags["name"] != image || tags["tags"] != ["latest"]
	abort "Bad tags"
end


# can we read the manifest?
manifest = reg.manifest image, "latest"

# can we pull an image?
tmpdir = Dir.mktmpdir
begin
	reg.pull image, "latest", tmpdir
ensure
	FileUtils.remove_entry_secure tmpdir
end

# success
exit
