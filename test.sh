#!/bin/sh

set -e

cleanup() {
    if [ -z "$TEST_REGISTRY" ]; then
        docker kill registry
        docker rm registry
    fi
}

trap cleanup EXIT

# if the registry target was passed to us, we do not need to create anything or tear down anything
if [ -z "$TEST_REGISTRY" ]; then
    docker run --name registry -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -p 5000:5000 registry:2.6
    docker cp $PWD/test/registry/. registry:/var/lib/registry
fi

# test a pull of each image - not a fancy start, but a good enough one
bundle install

echo "=== Starting Tests"

export REGISTRY="http://localhost:5000/"

echo "=== v1 --- OUTPUT"
if VERSION=v1 ruby ./test/test.rb; then
    success1=true
    echo "Successfully finished V1 test"
else
    success1=false
    echo "Error during V1 test"

fi

set +e
echo "=== v2 --- OUTPUT"
if VERSION=v2 ruby ./test/test.rb; then
  success2=true
  echo "Successfully finished V2 test"
else
  sucess=false
  echo "Error during V2 test"
fi

echo "=== Tests Complete"

if [  "$success1" = false ] || [ "$success2" = false ]; then
	exit 1
fi
