#!/bin/sh

mkdir ~/.gem
printf -- "---\n:rubygems_api_key: $GEM_HOST_API_KEY\n" > ~/.gem/credentials
chmod 0600 ~/.gem/credentials

