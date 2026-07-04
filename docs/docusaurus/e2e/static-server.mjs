// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import express from 'express';
import compression from 'compression';

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

// Fail loudly when the build output is missing rather than serving 404s that
// surface downstream as opaque navigation failures. Callers must build first.
if (!fs.existsSync(path.join(buildDir, 'index.html'))) {
  console.error(
    `[e2e static server] build output not found at ${buildDir}. Run "npm run build" first.`,
  );
  process.exit(1);
}

const app = express();
app.use(compression());

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
app.use((_req, res) => {
  res.status(404).sendFile(path.join(buildDir, '404.html'));
});

const server = app.listen(PORT, HOST, () => {
  console.log(`[e2e static server] serving ${buildDir} at http://${HOST}:${PORT}${BASE}`);
});

// Tolerate long-lived connections from parallel workers.
server.keepAliveTimeout = 60_000;
server.headersTimeout = 65_000;
