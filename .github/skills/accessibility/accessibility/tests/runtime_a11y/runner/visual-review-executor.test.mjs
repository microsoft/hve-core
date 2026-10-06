// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { mkdtemp, readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import {
  buildVisualReviewPlan,
  buildVisualReviewArtifactSegment,
  buildDeterministicMeasurementEnvelope,
  captureVisualReviewEvidence,
  resolveBrowserVersion,
  resolveRouteUrl,
} from '../../../scripts/runtime_a11y/runner/visual-review-executor.mjs';

test('buildVisualReviewArtifactSegment uses validated route, surface, and state IDs', () => {
  assert.equal(
    buildVisualReviewArtifactSegment({ path: '/search', surfaceId: 'search-results' }, 'zoom-200').join('/'),
    'search/search-results/zoom-200',
  );
  assert.throws(
    () => buildVisualReviewArtifactSegment({ surfaceId: 'search/results' }, 'zoom-200'),
    /Surface ID/,
  );
  assert.throws(
    () => buildVisualReviewArtifactSegment({ surfaceId: 'search-results' }, 'zoom 200'),
    /State ID/,
  );
  assert.notDeepEqual(
    buildVisualReviewArtifactSegment({ surfaceId: 'home-search' }, 'default'),
    buildVisualReviewArtifactSegment({ surfaceId: 'home' }, 'search-default'),
  );
});

test('buildVisualReviewArtifactSegment keeps distinct routes apart when surface and state match', () => {
  const first = buildVisualReviewArtifactSegment({ path: '/checkout/step-1', surfaceId: 'checkout' }, 'desktop');
  const second = buildVisualReviewArtifactSegment({ path: '/checkout/step-2', surfaceId: 'checkout' }, 'desktop');
  assert.notDeepEqual(first, second);
  assert.notEqual(first.join(':'), second.join(':'));

  // Routes that omit surfaceId all fall back to 'surface', so the route segment is the only separator.
  const anonymousFirst = buildVisualReviewArtifactSegment({ path: '/alpha' }, 'desktop');
  const anonymousSecond = buildVisualReviewArtifactSegment({ path: '/beta' }, 'desktop');
  assert.notDeepEqual(anonymousFirst, anonymousSecond);

  assert.deepEqual(
    buildVisualReviewArtifactSegment({ routeId: 'explicit-id', path: '/ignored', surfaceId: 'home' }, 'desktop'),
    ['explicit-id', 'home', 'desktop'],
  );
  assert.deepEqual(
    buildVisualReviewArtifactSegment({ path: '/' }, 'desktop'),
    ['root', 'surface', 'desktop'],
  );
});

test('resolveBrowserVersion uses the configured value or synchronous browser API', () => {
  const browser = {
    version() {
      return 'Chrome 140';
    },
  };

  assert.equal(resolveBrowserVersion(browser, 'configured'), 'configured');
  assert.equal(resolveBrowserVersion(browser, ''), 'Chrome 140');
  assert.equal(resolveBrowserVersion({ version() { throw new Error('closed'); } }, ''), 'unknown');
});

test('buildVisualReviewPlan uses the homepage and configured search route for the required state matrix', () => {
  const plan = buildVisualReviewPlan({
    visualReview: {
      routes: [
        { path: '/', surfaceId: 'home' },
        { path: '/search?query=accessibility', state: 'search-results', surfaceId: 'search-results' },
      ],
    },
  });

  assert.equal(plan.routes.length, 2);
  assert.deepEqual(plan.routes.map((route) => route.path), ['/', '/search?query=accessibility']);
  assert.deepEqual(plan.states.map((entry) => entry.state), ['desktop', 'reflow-320', 'zoom-200', 'text-spacing', 'forced-colors']);
});

test('buildDeterministicMeasurementEnvelope includes geometry, overflow and focus metrics', () => {
  const envelope = buildDeterministicMeasurementEnvelope({
    viewport: { width: 1440, height: 900 },
    documentDimensions: { scrollWidth: 1600, clientWidth: 1440 },
    fixedOverlayCount: 2,
    interactiveOutsideViewport: [{ tag: 'button', text: 'Search' }],
    focusRectangleVisible: false,
    clippedTextCandidates: [{ text: 'Accessibility' }],
    overlapCandidates: [{ selector: 'header' }],
    overflowClassification: { code: 'allowed', table: 'allowed' },
  });

  assert.equal(envelope.documentDimensions.scrollWidth, 1600);
  assert.equal(envelope.metrics.rootHorizontalOverflow, true);
  assert.equal(envelope.metrics.fixedOverlayCount, 2);
  assert.equal(envelope.metrics.interactiveOutsideViewport.length, 1);
  assert.equal(envelope.metrics.focusRectangleVisible, false);
  assert.equal(envelope.metrics.allowedOverflow.code, 'allowed');
});

test('buildDeterministicMeasurementEnvelope defaults to the desktop viewport contract', () => {
  const envelope = buildDeterministicMeasurementEnvelope({});

  assert.deepEqual(envelope.viewport, { width: 1440, height: 900 });
});

test('captureVisualReviewEvidence writes a Playwright trace zip artifact and desktop measurements', async () => {
  const runRoot = await mkdtemp(path.join(os.tmpdir(), 'a11y-visual-review-'));
  process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = runRoot;
  const server = createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    response.end('<html><body><h1>Visual review</h1></body></html>');
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    const payload = await captureVisualReviewEvidence({
      visualReview: {
        routes: [{ path: '/', state: 'default', surfaceId: 'home' }],
        states: ['desktop'],
      },
      baseUrl: `http://127.0.0.1:${port}`,
    });

    const run = payload.runs[0];
    assert.ok(run);

    // The capture path records a failed capture as a run with a
    // "capture-failure" outcome rather than throwing, so a run object exists
    // either way. Assert the outcome before reading artifacts: otherwise a
    // failed capture surfaces as ENOENT on a file that was never written, and
    // the real reason -- which is already recorded here -- is discarded.
    const outcome = run.probeOutcomes?.[0];
    assert.equal(
      outcome?.status,
      'pass',
      `visual review capture did not succeed: ${outcome?.detail ?? 'no detail recorded'}`,
    );

    const artifactDir = path.join(runRoot, 'artifacts', 'root', 'home', 'desktop');
    const tracePath = path.join(artifactDir, 'trace.zip');
    const measurementPath = path.join(artifactDir, 'measurements.json');

    const traceStats = await stat(tracePath);
    const measurement = JSON.parse(await readFile(measurementPath, 'utf8'));
    assert.ok(traceStats.size > 0);
    assert.deepEqual(measurement.viewport, { width: 1440, height: 900 });
    assert.equal(run.browser.version, 'unknown');
    assert.deepEqual(run.viewport, { width: 1440, height: 900 });
  } finally {
    delete process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
    await new Promise((resolve) => server.close(resolve));
  }
});

test('captureVisualReviewEvidence records explicit capture failures for failed states', async () => {
  const runRoot = await mkdtemp(path.join(os.tmpdir(), 'a11y-visual-review-failure-'));
  process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = runRoot;

  try {
    const payload = await captureVisualReviewEvidence({
      visualReview: {
        routes: [{ path: '/', state: 'default', surfaceId: 'home' }],
        states: ['desktop'],
      },
      baseUrl: 'http://127.0.0.1:1',
    });

    assert.equal(payload.runs.length, 1);
    assert.equal(payload.runs[0].probeOutcomes[0].status, 'capture-failure');
  } finally {
    delete process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
  }
});

test('resolveRouteUrl rejects targets that leave the validated origin', () => {
  const base = 'http://127.0.0.1:3000';

  assert.equal(resolveRouteUrl('/search', base), 'http://127.0.0.1:3000/search');
  assert.equal(resolveRouteUrl('', base), 'http://127.0.0.1:3000/');
  assert.throws(() => resolveRouteUrl('http://evil.test/', base), /must be relative/);
  assert.throws(() => resolveRouteUrl('https://evil.test/', base), /must be relative/);
  assert.throws(() => resolveRouteUrl('data:text/html,<h1>x</h1>', base), /must be relative/);
  assert.throws(() => resolveRouteUrl('//evil.test/path', base), /must be relative/);
});
