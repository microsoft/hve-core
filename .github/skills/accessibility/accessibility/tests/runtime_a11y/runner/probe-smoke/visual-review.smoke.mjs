// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Browser smoke tests for the deterministic visual-review executor. These use a
// temporary local run root and the same executor path used by the runtime CLI so
// the implementation is exercised in a real browser without requiring a model.
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { createServer } from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';

import { captureVisualReviewEvidence } from '../../../../scripts/runtime_a11y/runner/visual-review-executor.mjs';

let tempDir;
let originalBaseUrl;
let originalRunRoot;
let server;
const inlineDocument = '<!doctype html><html><head><meta charset="utf-8"><title>Smoke</title></head><body><main><h1>Accessibility</h1><button>Search</button><p>Local visual review smoke</p></main></body></html>';

before(async () => {
  tempDir = await mkdtemp(path.join(os.tmpdir(), 'visual-review-smoke-'));
  originalBaseUrl = process.env.RUNTIME_A11Y_BASE_URL;
  originalRunRoot = process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
  server = createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    response.end(inlineDocument);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  process.env.RUNTIME_A11Y_BASE_URL = `http://127.0.0.1:${port}`;
  process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = tempDir;
});

after(async () => {
  if (originalBaseUrl === undefined) {
    delete process.env.RUNTIME_A11Y_BASE_URL;
  } else {
    process.env.RUNTIME_A11Y_BASE_URL = originalBaseUrl;
  }
  if (originalRunRoot === undefined) {
    delete process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
  } else {
    process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = originalRunRoot;
  }
  await new Promise((resolve) => server.close(resolve));
  await rm(tempDir, { recursive: true, force: true });
});

test('visual-review smoke: captures deterministic evidence for the local loopback matrix', async () => {
  const payload = await captureVisualReviewEvidence({
    visualReview: {
      routes: [
        { path: '/', surfaceId: 'home' },
        { path: '/search?query=accessibility', surfaceId: 'search-results' },
      ],
    },
    surfaces: [
      {
        id: 'home',
        route: '/',
      },
      {
        id: 'search-results',
        route: '/search?query=accessibility',
      },
    ],
    baseUrl: inlineDocument,
  });

  assert.equal(payload.command, 'capture-visual-review');
  assert.ok(payload.runs.length >= 2);
  for (const run of payload.runs) {
    assert.ok(run.screenshotPath);
    assert.ok(run.measurementPath);
    assert.ok(run.tracePath);
    assert.ok(run.deterministicMetrics);
  }
});
