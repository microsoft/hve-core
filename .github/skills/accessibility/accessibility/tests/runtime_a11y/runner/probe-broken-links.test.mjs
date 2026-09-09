// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  checkLinkWithRedirects,
  MAX_REDIRECT_HOPS,
} from '../../../scripts/runtime_a11y/runner/probe-broken-links.mjs';

function response(status, headers = {}) {
  return {
    status: () => status,
    headers: () => headers,
  };
}

function sequenceRequest(responses) {
  const calls = [];
  const queue = [...responses];
  return {
    calls,
    request: {
      async head(url, options) {
        calls.push({ method: 'HEAD', url, options });
        const next = queue.shift();
        if (next instanceof Error) {
          throw next;
        }
        return next;
      },
      async get(url, options) {
        calls.push({ method: 'GET', url, options });
        const next = queue.shift();
        if (next instanceof Error) {
          throw next;
        }
        return next;
      },
    },
  };
}

test('checkLinkWithRedirects follows bounded same-origin redirects', async () => {
  const { request, calls } = sequenceRequest([
    response(302, { location: '/next' }),
    response(301, { Location: 'final' }),
    response(200),
  ]);

  const result = await checkLinkWithRedirects(
    request,
    'https://example.com/start',
  );

  assert.deepEqual(result, {
    broken: false,
    reason: null,
    status: 200,
    redirects: 2,
  });
  assert.deepEqual(calls.map(({ url }) => url), [
    'https://example.com/start',
    'https://example.com/next',
    'https://example.com/final',
  ]);
  assert.equal(calls.every(({ options }) => options.maxRedirects === 0), true);
});

test('checkLinkWithRedirects blocks an off-origin hop before requesting it', async () => {
  const { request, calls } = sequenceRequest([
    response(302, { location: 'https://attacker.example/path' }),
  ]);

  const result = await checkLinkWithRedirects(
    request,
    'https://example.com/start',
  );

  assert.equal(result.broken, true);
  assert.equal(result.reason, 'redirect-policy');
  assert.deepEqual(calls.map(({ url }) => url), ['https://example.com/start']);
});

test('checkLinkWithRedirects stops before requesting beyond the hop limit', async () => {
  const { request, calls } = sequenceRequest([
    response(302, { location: '/one' }),
    response(302, { location: '/two' }),
  ]);

  const result = await checkLinkWithRedirects(
    request,
    'https://example.com/start',
    { maxRedirectHops: 1 },
  );

  assert.equal(result.broken, true);
  assert.equal(result.reason, 'redirect-limit');
  assert.deepEqual(calls.map(({ url }) => url), [
    'https://example.com/start',
    'https://example.com/one',
  ]);
});

test('checkLinkWithRedirects detects loops and missing locations', async () => {
  const loop = sequenceRequest([response(302, { location: '/start' })]);
  const loopResult = await checkLinkWithRedirects(
    loop.request,
    'https://example.com/start',
  );
  assert.equal(loopResult.reason, 'redirect-loop');

  const missing = sequenceRequest([response(302)]);
  const missingResult = await checkLinkWithRedirects(
    missing.request,
    'https://example.com/start',
  );
  assert.equal(missingResult.reason, 'redirect-location-missing');
});

test('checkLinkWithRedirects falls back from HEAD to GET without redirects', async () => {
  const { request, calls } = sequenceRequest([
    new Error('HEAD unavailable'),
    response(404),
  ]);

  const result = await checkLinkWithRedirects(
    request,
    'https://example.com/missing',
  );

  assert.equal(result.broken, true);
  assert.equal(result.status, 404);
  assert.deepEqual(calls.map(({ method }) => method), ['HEAD', 'GET']);
  assert.equal(calls.every(({ options }) => options.maxRedirects === 0), true);
});

test('the default redirect limit remains five hops', () => {
  assert.equal(MAX_REDIRECT_HOPS, 5);
});

test('checkLinkWithRedirects retries with GET when HEAD is not allowed', async () => {
  for (const headStatus of [405, 501]) {
    const { request, calls } = sequenceRequest([
      response(headStatus),
      response(200),
    ]);

    const result = await checkLinkWithRedirects(
      request,
      'https://example.com/get-only',
    );

    assert.equal(result.broken, false, `status ${headStatus} should retry with GET`);
    assert.equal(result.status, 200);
    assert.deepEqual(calls.map(({ method }) => method), ['HEAD', 'GET']);
  }
});

test('checkLinkWithRedirects does not retry a genuine client error', async () => {
  const { request, calls } = sequenceRequest([response(404)]);

  const result = await checkLinkWithRedirects(request, 'https://example.com/missing');

  assert.equal(result.broken, true);
  assert.equal(result.status, 404);
  assert.deepEqual(calls.map(({ method }) => method), ['HEAD']);
});
