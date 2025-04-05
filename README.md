# Local HTTP Server

A convenience NGINX app for local development. If you're struggling with managing the port
numbers for your local services, this project is for you. It lets you replace `localhost:52321`
with `localhost/myservice`.

## Installation

To install the local HTTP server, run the following command in your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/staa99/local-http-server/refs/tags/v1.0.0-beta.2/shell-scripts/install.sh | bash
```

You can override installation defaults by setting the following environment variables before running the command:
- `LHS_CONFIG_DIR`: This specifies the directory where the configuration file will be stored. 
  Default is `$HOME/.local-http-server`.
- `LHS_PORT`: This specifies the port on which the local HTTP server will listen. 
  Default is `80`. You can set this to any available port on your system.
- `LHS_INSTALL_DIR`: This specifies the directory where the local HTTP server will be installed. 
  Default is `$HOME/.local-http-server/bin`. This should be a directory where you have write permissions.



## Configuration

The configuration is stored by default at $HOME/.local-http-server/config.json

You can register service ports in the file by modifying the `ports` object. An example is added
during installation. The sample below registers a service called `lhs-test-service` with the port
`55455`. With this setup, any calls to `http://localhost/lhs-test-service` will be redirected to 
`http://localhost:55455`.

```json
{
  "ports": {
    "lhs-test-service": "55455"
  }
}
```

The host_ip static config is added during start-up, it corresponds to the IP of your local machine
on the docker network the NGINX container is running on (determined by host.docker.internal).
This should usually not be necessary, but you can override it in the config file if  needed.
It's under the `static` section of the config.

_Only change this if you know what you're doing_

```json
{
  "static": {
    "host_ip": "192.168.65.254"
  }
}
```

## Dynamic Configuration

If you use a setup that involves using random IPs on startup, you can configure the local-http-server
on startup by sending the HTTP request:

```http request
POST http://localhost/local-http-server/register
Content-Type: application/json

{
    "service": "lhs-test-service",
    "port": "55455"
}
```

With this setup, any calls to `http://localhost/lhs-test-service` will be redirected to
`http://localhost:55455`.