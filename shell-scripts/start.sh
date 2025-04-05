#!/bin/bash
set -e

config_dir=${LHS_CONFIG_DIR:-~/.local-http-server}
host_port=${LHS_PORT:-80}
config_file_name=config.json
config_file="$config_dir"/"$config_file_name"

mkdir -p "$config_dir"

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
  -p "$host_port":80 \
  -v "$config_dir":/app \
  -e LHS_CONFIG_FILE="$config_file_name" \
  staa99/local-http-server:latest

if jq empty "$config_file" > /dev/null 2>&1; then
  # Use jq to set the ports.lhs-test-service to "55455" if it's not set
  # This is set as a sample for configuration
  if ! jq -e '.ports."lhs-test-service"? // empty' "$config_file" | grep -q '.'; then
    jq '.ports."lhs-test-service"="55455"' "$config_file" > tmp.$$ && mv tmp.$$ "$config_file"
  fi

  host=$(docker container exec local-http-server sh -c "ping -c 1 host.docker.internal" | awk -F'[()]' '/PING/{print $2}')
  if [ -n "$host" ]; then
    # Use jq to update the JSON file
    jq --arg host "$host" '.static.host_ip = $host' "$config_file" > tmp.$$.json && mv tmp.$$.json "$config_file"
    echo "Updated static.host_ip to $host in $config_file"
  else
    echo "Failed to determine host IP. Configure the host IP address manually"
  fi
else
    echo "$config_file is not valid JSON. Please fix the file and try again."
fi


