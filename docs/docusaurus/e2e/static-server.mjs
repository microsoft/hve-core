// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import express from 'express';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

// Production-grade static server for the e2e suite.
//
// Serves the built Docusaurus output under the site baseUrl (/hve-core/) with
// compression and keep-alive so many concurrent Playwright workers can hit it
// without the connection resets seen when driving the lightweight
// `docusaurus serve` preview server under load.

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const buildDir = path.resolve(currentDir, '..', 'build');
const BASE = '/hve-core/';
const PORT = Number(process.env.PORT ?? 3001);
const HOST = process.env.HOST ?? '127.0.0.1';

function readPositiveInteger(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw.trim() === '') {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    console.error(`[e2e static server] ${name} must be a positive integer, received "${raw}".`);
    process.exit(1);
  }
  return value;
}

// Request budget for every filesystem-backed route. The default ceiling is
// deliberately high because all parallel Playwright workers share one loopback
// address, so a production-sized limit would throttle the suite rather than an
// abusive client. The overrides let a test drive a deterministic 429.
const RATE_LIMIT_WINDOW_MS = readPositiveInteger('RATE_LIMIT_WINDOW_MS', 60_000);
const RATE_LIMIT_MAX = readPositiveInteger('RATE_LIMIT_MAX', 100_000);

// Fail loudly when the build output is missing rather than serving 404s that
// surface downstream as opaque navigation failures. Callers must build first.
if (!fs.existsSync(path.join(buildDir, 'index.html'))) {
  console.error(
    `[e2e static server] build output not found at ${buildDir}. Run "npm run build" first.`,
  );
  process.exit(1);
}

// Resolve the 404 page per request rather than caching it at startup.
// Docusaurus emits content-hashed asset filenames, so a server that outlives a
// rebuild would keep serving HTML that references bundles the rebuild deleted.
// Measured on this suite: the route then loaded no JS, never set
// data-has-hydrated, and all nine e2e tests on it timed out in
// waitForHydration before reaching their own assertions.
const notFoundPage = path.join(buildDir, '404.html');

const app = express();
app.use(compression());

// Applied before any static or not-found handler so no filesystem read is served
// outside the budget.
app.use(
  rateLimit({
    windowMs: RATE_LIMIT_WINDOW_MS,
    limit: RATE_LIMIT_MAX,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
  }),
);

// Serve the static build under the configured baseUrl. Directory requests
// resolve to their index.html, matching Docusaurus trailing-slash routes.
app.use(
  BASE,
  express.static(buildDir, {
    extensions: ['html'],
    index: 'index.html',
    fallthrough: true,
  }),
);

// Convenience redirect from the server root to the baseUrl.
app.get('/', (_req, res) => res.redirect(BASE));

// Unknown routes render the Docusaurus 404 template with a 404 status,
// mirroring production behavior for the not-found page.
app.use((_req, res, next) => {
  res.status(404).sendFile(notFoundPage, (error) => {
    if (error) {
      next(error);
    }
  });
});

const server = app.listen(PORT, HOST, () => {
  console.log(`[e2e static server] serving ${buildDir} at http://${HOST}:${PORT}${BASE}`);
});

// Tolerate long-lived connections from parallel workers.
server.keepAliveTimeout = 60_000;
server.headersTimeout = 65_000;
