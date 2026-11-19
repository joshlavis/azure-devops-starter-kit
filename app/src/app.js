'use strict';
// Request handler kept separate from the listener so tests can call it directly.
// Zero runtime dependencies: nothing to patch, nothing for a scanner to flag.

const os = require('node:os');

const startedAt = new Date();
let ready = true;

function setReady(value) {
  ready = Boolean(value);
}

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(payload);
}

function handler(req, res) {
  const url = new URL(req.url, 'http://localhost');

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return json(res, 405, { error: 'method not allowed' });
  }

  switch (url.pathname) {
    case '/':
      return json(res, 200, {
        message: 'Hello from the Azure DevOps Starter Kit',
        environment: process.env.APP_ENV || 'local',
        version: process.env.APP_VERSION || 'dev',
        host: os.hostname(),
      });
    case '/healthz':
      // Liveness: the process is up.
      return json(res, 200, { status: 'ok', uptimeSeconds: Math.round(process.uptime()) });
    case '/readyz':
      // Readiness: flip to false during shutdown so traffic drains.
      return json(res, ready ? 200 : 503, { ready, startedAt: startedAt.toISOString() });
    case '/info':
      // Shows which Azure wiring is present without leaking values.
      return json(res, 200, {
        keyVaultConfigured: Boolean(process.env.KEY_VAULT_URI),
        storageConfigured: Boolean(process.env.STORAGE_BLOB_ENDPOINT),
        appInsightsConfigured: Boolean(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING),
        managedIdentityConfigured: Boolean(process.env.AZURE_CLIENT_ID),
      });
    default:
      return json(res, 404, { error: 'not found', path: url.pathname });
  }
}

module.exports = { handler, setReady };
