'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { handler, setReady } = require('../src/app');

let server;
let base;

before(async () => {
  server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET / returns greeting', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.match(body.message, /Starter Kit/);
});

test('GET /healthz is ok', async () => {
  const res = await fetch(`${base}/healthz`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).status, 'ok');
});

test('GET /readyz follows readiness flag', async () => {
  assert.equal((await fetch(`${base}/readyz`)).status, 200);
  setReady(false);
  assert.equal((await fetch(`${base}/readyz`)).status, 503);
  setReady(true);
});

test('GET /info never leaks values', async () => {
  process.env.KEY_VAULT_URI = 'https://example.vault.azure.net/';
  const body = await (await fetch(`${base}/info`)).json();
  assert.equal(body.keyVaultConfigured, true);
  assert.ok(!JSON.stringify(body).includes('vault.azure.net'));
});

test('unknown path is 404 and POST is 405', async () => {
  assert.equal((await fetch(`${base}/nope`)).status, 404);
  assert.equal((await fetch(`${base}/`, { method: 'POST' })).status, 405);
});
