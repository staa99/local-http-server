import fs from "fs";

const configFile = process.env.LHS_CONFIG_FILE || "config.json";

async function proxy(r) {
  const hostIp = await getHostIp();
  const uriSplit = r.uri.split("/");
  const service = uriSplit[1]; // Extract the first path segment after the root
  const path = "/" + uriSplit.slice(2).join("/");

  if (!service) {
    const config = await loadConfig();
    return jsonResponse(r, 200, {
      message:
        "Local HTTP server is running. Please specify a valid URI to route to the respective service",
      config,
    });
  }

  const port = await getPortNumber(service);
  if (!port) {
    r.error(`LHS_LOG_LINE: ${service} is not configured`);
    return jsonResponse(r, 404, {
      status: "failed",
      message: `No backend configured for ${service}. Please check your configuration.`,
    });
  }

  const serviceUrl = `/internal-service/${port}/${hostIp}${path}`;
  r.log("LHS_LOG_LINE: Proxying request to " + serviceUrl);
  r.internalRedirect(serviceUrl, r.requestBuffer);
}

async function register(r) {
  const body = getRegisterPayload(r);
  if (!body) {
    // the response is handled already
    return;
  }

  // Lock the file
  const fd = fs.openSync(configFile, "r+");
  try {
    const config = await loadConfig();
    if (!config.ports) {
      config.ports = {};
    }

    config.ports[body.service] = body.port;
    fs.writeFileSync(configFile, JSON.stringify(config));
    r.log(
      `LHS_LOG_LINE: Registered service ${body.service} on port ${body.port}`,
    );

    // Update the shared memory for the new service
    ngx.shared.ports.set(body.service, body.port);
    return jsonResponse(r, 200, {
      status: "successful",
      message: `${body.service} is now registered on port ${body.port}`,
    });
  } finally {
    // Unlock the file
    fs.closeSync(fd);
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
  const config = JSON.parse(configText || "{}");

  const zones = Object.entries(config);
  for (let i = 0; i < zones.length; i++) {
    const zone = zones[i][0];
    const zoneConfig = Object.entries(zones[i][1]);

    for (let i = 0; i < zoneConfig.length; i++) {
      const entry = zoneConfig[i];
      ngx.shared[zone].set(entry[0].toString(), entry[1].toString());
    }
  }

  return config;
}

function getRegisterPayload(r) {
  let body;
  try {
    body = JSON.parse(r.requestText);
  } catch (e) {
    r.error(`LHS_LOG_LINE: Invalid request body: ${r.requestText}`);
    return jsonResponse(r, 400, {
      status: "failed",
      message: "Invalid request body. Please provide a valid JSON.",
    });
  }

  if (!body.service || !/^([a-zA-Z0-9_-]+)$/.test(body.service)) {
    r.error(
      `LHS_LOG_LINE: Invalid service name: ${body.service}. Service names can only contain alphanumeric characters, hyphens, and underscores.`,
    );
    return jsonResponse(r, 400, {
      status: "failed",
      message:
        "Invalid service name. Service names can only contain alphanumeric characters, hyphens, and underscores.",
    });
  }

  const port = Number(body.port);
  if (Number.isNaN(port) || port <= 0 || port > 65535) {
    r.error(
      `LHS_LOG_LINE: Invalid port number: ${body.port}. Port must be a number between 1 and 65535.`,
    );
    return jsonResponse(r, 400, {
      status: "failed",
      message:
        "Invalid port number. Port must be a number between 1 and 65535.",
    });
  }

  body.port = port.toString(10);
  return body;
}

function jsonResponse(r, status, body) {
  r.headersOut["Content-Type"] = "application/json";
  body = JSON.stringify(body);
  r.return(status, body);
}

export default { proxy, register };
