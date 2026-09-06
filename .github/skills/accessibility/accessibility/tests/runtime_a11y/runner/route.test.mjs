// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveTargetUrl } from '../../../scripts/runtime_a11y/runner/_shared.mjs';
import { resolveDestinationUrl, resolveRouteUrl } from '../../../scripts/runtime_a11y/runner/route.mjs';
import { resolveRouteUrl as visualReviewResolver } from '../../../scripts/runtime_a11y/runner/visual-review-executor.mjs';

const BASE = 'http://127.0.0.1:3000';

const HOSTILE_ROUTES = [
  '//attacker.example/',
  'https://attacker.example/',
  'http://attacker.example/',
  'javascript:alert(1)',
];

test('every navigation path rejects the same hostile routes', () => {
  for (const route of HOSTILE_ROUTES) {
    assert.throws(() => resolveRouteUrl(route, BASE), undefined, route);
    assert.throws(() => visualReviewResolver(route, BASE), undefined, route);
    assert.throws(() => resolveTargetUrl(BASE, { route }), undefined, route);
  }
});

test('the visual review path and the shared resolver are the same function', () => {
  assert.equal(visualReviewResolver, resolveRouteUrl);
});

test('ordinary relative routes still resolve', () => {
  assert.equal(resolveRouteUrl('/docs', BASE), 'http://127.0.0.1:3000/docs');
  assert.equal(resolveRouteUrl('docs', BASE), 'http://127.0.0.1:3000/docs');
  assert.equal(resolveRouteUrl('', BASE), 'http://127.0.0.1:3000/');
  assert.equal(resolveTargetUrl(BASE, { route: '/docs' }), 'http://127.0.0.1:3000/docs');
});

test('a surface with no route keeps the base url', () => {
  assert.equal(resolveTargetUrl(BASE, {}), BASE);
});

test('trigger destinations accept relative and absolute same-origin HTTP URLs', () => {
  assert.equal(resolveDestinationUrl('/next', BASE), 'http://127.0.0.1:3000/next');
  assert.equal(
    resolveDestinationUrl('http://127.0.0.1:3000/next', BASE),
    'http://127.0.0.1:3000/next',
  );
});

test('trigger destinations reject unsupported and off-origin values', () => {
  for (const target of [
    '//attacker.example/path',
    'https://attacker.example/path',
    'file:///tmp/page.html',
    'javascript:alert(1)',
    'http:ambiguous',
    'https://user:password@127.0.0.1:3000/path',
    '/bad path',
  ]) {
    assert.throws(() => resolveDestinationUrl(target, BASE), undefined, target);
  }
});
