'use strict';
const http = require('node:http');
const { handler, setReady } = require('./app');

const port = Number(process.env.PORT || 8080);
const server = http.createServer(handler);

server.listen(port, () => {
  console.log(JSON.stringify({ level: 'info', msg: 'listening', port, env: process.env.APP_ENV || 'local' }));
});

// Graceful shutdown: Container Apps sends SIGTERM before stopping a replica.
function shutdown(signal) {
  console.log(JSON.stringify({ level: 'info', msg: 'shutting down', signal }));
  setReady(false);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
