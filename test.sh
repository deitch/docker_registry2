#!/bin/sh

set -e

cleanup() {
    docker kill registry
    docker rm registry
}

trap cleanup EXIT

docker run --name registry -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -v $PWD/test/registry:/var/lib/registry -p 5000:5000 registry:2.6

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
