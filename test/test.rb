#!ruby
require 'tmpdir'
require_relative '../lib/docker_registry2'
version = ENV["VERSION"]
regurl = ENV["REGISTRY"]
reg = DockerRegistry2.connect regurl

# do we have tags?
image = "hello-world-"+version
tags = reg.tags image
if tags == nil || tags["name"] != image || tags["tags"] != ["latest"]
	abort "Bad tags"
end

# Tests only to run against the v2 Registry API
if version == "v2"
	# can we add tags?
	random_tag = ('a'..'z').to_a.shuffle[0,8].join
	reg.tag image, "latest", image, random_tag

	# give the registry a chance to catch up
	sleep 1

	more_tags = reg.tags image
	unless (more_tags["tags"] - [random_tag, "latest"]).empty?
		abort "Failed to add tag"
	end

	# can we delete tags?
	reg.rmtag image, random_tag

	# give the registry a chance to catch up
	sleep 1

	even_more_tags = reg.tags image
	if even_more_tags["tags"] != ["latest"]
		abort "Failed to delete tag"
	end
end

# can we read the manfiest?
manifest = reg.manifest image, "latest"

# can we get the digest?
digest = reg.digest image, "latest"

# can we pull an image?
tmpdir = Dir.mktmpdir
begin
	reg.pull image, "latest", tmpdir
ensure
	FileUtils.remove_entry_secure tmpdir
end

# success
exit
