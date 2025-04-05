#!/bin/bash
set -e

# If docker is not running, log an error and terminate
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build the image and tag as staa99/local-http-server
docker build -t staa99/local-http-server ..

# Push to the docker registry
if [[ -n "$DOCKER_USERNAME" && -n "$DOCKER_PASSWORD" ]]; then
    echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    docker push staa99/local-http-server
else
    echo "Docker credentials not provided. Trying push with existing docker login."
    docker push staa99/local-http-server
fi
