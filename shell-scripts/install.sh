#!/bin/bash
set -e

config_dir=${LHS_CONFIG_DIR:-~/.local-http-server}
host_port=${LHS_PORT:-80}
config_file_name=config.json
config_file="$config_dir"/"$config_file_name"
install_dir=${LHS_INSTALL_DIR:-~/.local-http-server/bin}
launch_script="$install_dir/start.sh"

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

# Download the start script
mkdir -p "$install_dir"
if ! curl -sSL https://raw.githubusercontent.com/staa99/local-http-server/refs/tags/v1.0.0-beta.2/shell-scripts/start.sh > "$launch_script"; then
    echo "Failed to download the start script. Please check your internet connection."
    exit 1
fi

# Make the start script executable
if [ -f "$launch_script" ]; then
    chmod +x "$launch_script"
else
    echo "The start script was not downloaded successfully."
    exit 1
fi

# Get user's main shell (zsh, bash, etc)
user_shell=$(basename "$SHELL")

# add an alias for local-http-server to the user's shell configuration file
echo "# Added by local-http-server installation script
alias local-http-server='$launch_script'" >> "$HOME/.$user_shell"rc

source "$launch_script"

echo "
local-http-server installation completed successfully.

The configuration in stored at $config_file

Register services by adding ports in the config file under the 'ports' section. For example:

{
  \"ports\": {
    \"lhs-test-service\": \"55455\"
  }
}.

Verify your installation by running

  curl http://localhost:$host_port
"
