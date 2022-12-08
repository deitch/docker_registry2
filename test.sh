#!/bin/sh

set -e

cleanup() {
    docker kill registry
    docker rm registry
    docker network rm $NETNAME
}

# just runs the tests, assuming that everything else already is running, and that we know nothing about containers
run_tests_local() {
    # test a pull of each image - not a fancy start, but a good enough one
    export REGISTRY="$1"
    
    echo "=== Starting Tests"

    bundle install
    
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
}

run_tests() {
	if [ "$BUILD" = "local" ]; then
		run_tests_local "${TEST_REGISTRY:-http://localhost:5000}"
	else
    		docker build --network=$NETNAME --build-arg IMG=$IMG --build-arg registry="http://registry:5000" --build-arg cachebuster=$(date +%s) --target=test -t gem-test .
	fi
}

TASK=$1
NETNAME=registry-test
IMG=ruby:3.1.1-alpine

case $TASK in
testonly)
	run_tests
	;;
test)
	trap cleanup EXIT
	run_tests
	;;
setup)
	docker network create $NETNAME
    	docker run --name registry --network=$NETNAME -d -e REGISTRY_STORAGE_DELETE_ENABLED=true -p 5000:5000 registry:2.6
    	docker cp $PWD/test/registry/. registry:/var/lib/registry
	;;
teardown)
	cleanup
	;;
esac
