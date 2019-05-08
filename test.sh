#!/bin/sh

set -e

cid=$(docker run -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -v $PWD/test/registry:/var/lib/registry -p 5000:5000 registry:2.6)

# test a pull of each image - not a fancy start, but a good enough one
bundle install

echo "=== Starting Tests"

set +e
echo "=== v1 --- OUTPUT"
VERSION=v1 ruby ./test/test.rb
success1=$?
set -e

set +e
echo "=== v2 --- OUTPUT"
VERSION=v2 ruby ./test/test.rb
success2=$?
set -e

echo "=== Tests Complete"

docker kill $cid
docker rm $cid

if [ $success1 -ne 0 ]; then
	echo "Failed v1 test"
fi

if [ $success2 -ne 0 ]; then
	echo "Failed v2 test"
fi

if [ $success1 -ne 0 -o $success2 -ne 0 ]; then
	exit 1
fi
