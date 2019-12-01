.PHONY: build test deploy all clean

GEM ?= $(shell ruby ./get-gem-name.rb)

all: deploy

deploy: build
ifneq ($(BUILD),local)
	@docker build --target=deploy -t $@ .
else
	gem push $(GEM)
endif

push: deploy

gem:
	@echo $(GEM)

build: $(GEM)

$(GEM):
ifneq ($(BUILD),local)
	@docker build --target=build -t $@ .
else
	gem build docker_registry2.gemspec
endif

clean:
	rm -rf docker_registry2*.gem

test:
	./test.sh setup
	BUILD=$(BUILD) ./test.sh test
