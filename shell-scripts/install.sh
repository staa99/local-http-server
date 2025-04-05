#!/bin/bash
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Follow the instructions https://jqlang.org/download/ to install it."
    exit 1
fi

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Pull the docker image from the registry
echo "Pulling the latest local-http-server Docker image..."

# Check if the image was pulled successfully
if ! docker pull staa99/local-http-server:latest &> /dev/null; then
    echo "Failed to pull the Docker image. Please check your internet connection or the Docker registry."
    exit 1
fi

echo "Successfully pulled the latest local-http-server Docker image."
