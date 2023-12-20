#!/bin/bash

# Source image
source_image="localhost:5000/hello-world-v1:latest"

# Registry URL
registry_url="localhost:5000"

# Iterating from 2 to 101
for counter in {2..101}
do
    # Destination image name
    dest_image="$registry_url/hello-world-v$counter:latest"

    # Skopeo copy command
    skopeo copy --dest-tls-verify=false "docker-daemon:$source_image" "docker://$dest_image"

    # Optional: Echo to track progress
    echo "Copied to $dest_image"
done

