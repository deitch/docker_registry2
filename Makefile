GEM ?= $(shell ruby ./get-gem-name.rb)

all: deploy

deploy: build
	gem push $(GEM)

build: $(GEM)

$(GEM):
	gem build docker_registry2.gemspec

clean:
	rm -rf docker_registry2*.gem
