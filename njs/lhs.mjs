import fs from "fs";

const configFile = process.env.LHS_CONFIG_FILE || "config.json";

async function proxy(r) {
  const hostIp = await getHostIp();
  const uriSplit = r.uri.split("/");
  const service = uriSplit[1]; // Extract the first path segment after the root
  const path = "/" + uriSplit.slice(2).join("/");

  if (!service) {
    const config = await loadConfig();
    r.return(
      200,
      JSON.stringify({
        message:
          "Local HTTP server is running. Please specify a valid URI to route to the respective service",
        config,
      }),
    );
  }

  const port = await getPortNumber(service);
  if (!port) {
    r.error(`LHS_LOG_LINE: ${service} is not configured`);
    r.return(
      404,
      JSON.stringify({
        error: "Not Found",
        message: `No backend configured for ${service}. Please check your configuration.`,
      }),
    );
    return;
  }

  const serviceUrl = `/internal-service/${port}/${hostIp}${path}`; // Construct the service
  r.log("LHS_LOG_LINE: Proxying request to " + serviceUrl); // Log the proxy action
  r.internalRedirect(serviceUrl, r.requestBuffer);
}

async function register(r) {
  const body = JSON.parse(r.requestText);

  // Lock the file
  const fd = fs.openSync(configFile, "r+");

  try {
    const config = await loadConfig();

    fs.writeFileSync(
      configFile,
      JSON.stringify({
        ...config,
        ports: {
          ...config.ports,
          // Register the new service and port
          [body.service]: body.port,
        },
      }),
    );

    r.log(
      "LHS_LOG_LINE: Registered new service " +
        body.service +
        " on port " +
        body.port,
    );

    // Update the shared memory for the new service
    ngx.shared.ports.set(body.service, body.port);

    r.return(
      200,
      JSON.stringify({
        status: "successful",
        message: `${body.service} is now registered on ${body.port}`,
      }),
    );
  } finally {
    // Unlock the file
    fs.closeSync(fd);
  }
}

async function config() {
  try {
    const config = await loadConfig();
    return {
      status: "successful",
      config,
    };
  } catch (error) {
    ngx.log(ngx.ERROR, "LHS_LOG_LINE: Failed to load configuration - ", error);
    return {
      status: "failed",
      message: "Unable to load configuration",
    };
  }
}

async function getPortNumber(service) {
  const port = ngx.shared.ports.get(service);
  if (port) {
    return port;
  }

  await loadConfig();
  return ngx.shared.ports.get(service);
}

async function getHostIp() {
  const hostIp = ngx.shared.static.get("host_ip");
  if (hostIp) {
    return hostIp;
  }

  await loadConfig();
  return ngx.shared.static.get("host_ip");
}

async function loadConfig() {
  const configText = await fs.promises.readFile(configFile, "utf8");
  const config = JSON.parse(configText);

  const zones = Object.entries(config);
  for (let i = 0; i < zones.length; i++) {
    const zone = zones[i][0];
    const zoneConfig = Object.entries(zones[i][1]);

    for (let i = 0; i < zoneConfig.length; i++) {
      const entry = zoneConfig[i];
      ngx.shared[zone].set(entry[0], entry[1]);
    }
  }

  return config;
}

export default { proxy };
