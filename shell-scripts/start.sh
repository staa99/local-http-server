#!/bin/bash
set -e

config_file=${LHS_CONFIG:-~/.local-http-server/config.json}
host_port=${LHS_PORT:-80}

mkdir -p ~/.local-http-server

if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
    echo '{}' > "$config_file"
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
fi

docker rm local-http-server > /dev/null 2>&1 || true

# Start the local-http-server in a Docker container
echo "Starting local-http-server Docker container..."
docker run -d \
  --name local-http-server \
  -p $host_port:80 \
  -v ~/.local-http-server:/app \
  staa99/local-http-server:latest

host=$(docker container exec local-http-server sh -c "ping -c 1 host.docker.internal" | awk -F'[()]' '/PING/{print $2}')

if [ -n "$host" ]; then
    if jq empty "$config_file" > /dev/null 2>&1; then
        # Use jq to update the JSON file
        jq --arg host "$host" '.static.host_ip = $host' "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"

        # Use jq to set the ports.lhs-test-service to "55455" if it's not set
        # This is set as a sample for configuration
        if ! jq -e '.ports."lhs-test-service"? // empty' 'config.json' | grep -q '.'; then
          jq '.ports."lhs-test-service"="55455"' 'config.json' > tmp.$$ && mv tmp.$$ 'config.json'
        fi

        echo "Updated static.host_ip to $host in $config_file"
    else
        echo "$config_file is not valid JSON. Please fix the file and try again."
    fi
else
    echo "Failed to determine host IP."
fi
