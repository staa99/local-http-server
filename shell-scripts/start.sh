#!/bin/bash
set -e

if [ ! -f ~/.local-http-server/config.json ]; then
  mkdir ~/.local-http-server
fi

if [ ! -f ~/.local-http-server/config.json ]; then
    echo '{}' > ~/.local-http-server/config.json
fi

# If docker is not running, log an error and terminate
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Stop the container if it is already running
if [ "$(docker ps -q -f name=local-http-server)" ]; then
    echo "Stopping existing local-http-server container..."
    docker stop local-http-server > /dev/null
    docker rm local-http-server > /dev/null
fi

# Start the local-http-server in a Docker container
echo "Starting local-http-server Docker container..."
docker run -d \
  --name local-http-server \
  -p 80:80 \
  -v ~/.local-http-server:/app \
  staa99/local-http-server:latest

host=$(docker container exec local-http-server sh -c "ping -c 1 host.docker.internal" | awk -F'[()]' '/PING/{print $2}')

# Store the host in the JSON config file - note that there may be some data already
# The key for the host is `static.host_ip`
if [ -n "$host" ]; then
    # Use jq to update the JSON file
    jq --arg host "$host" '.static.host_ip = $host' ~/.local-http-server/config.json > tmp.$$.json && mv tmp.$$.json ~/.local-http-server/config.json
    echo "Updated static.host_ip to $host in config.json"
else
    echo "Failed to determine host IP."
fi
