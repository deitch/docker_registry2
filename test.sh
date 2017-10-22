#!/bin/sh

set -e

cid=$(docker run -d -v $PWD/test/registry:/var/lib/registry -p 5000:5000 registry:2.6)

# test a pull of each image - not a fancy start, but a good enough one
bundle install

set +e
VERSION=v1 ruby ./test/test.rb
success1=$?
set -e

set +e
VERSION=v2 ruby ./test/test.rb
success2=$?
set -e


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
