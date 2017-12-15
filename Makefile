.PHONY: build test deploy all clean

GEM ?= $(shell ruby ./get-gem-name.rb)

all: deploy

deploy: build
	gem push $(GEM)

push: deploy

build: $(GEM)

$(GEM):
	gem build docker_registry2.gemspec

clean:
	rm -rf docker_registry2*.gem

test:
	./test.sh
