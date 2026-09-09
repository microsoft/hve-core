// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { assertHttpUrl } from './validation.mjs';

// Resolves a configured route against the validated base origin.
//
// A route path is a path, never a destination. Navigating a scheme-bearing or
// protocol-relative value verbatim would leave the origin the loopback guard
// approved, so those forms are rejected rather than followed. The Python-side
// target guard runs before control reaches any navigator and never sees a
// per-surface route, so this check is the only thing standing between a
// configured route and a different origin.
export function resolveRouteUrl(rawTarget, baseUrl) {
  const target = typeof rawTarget === 'string' ? rawTarget.trim() : '';
  if (!target) {
    return new URL('/', baseUrl).toString();
  }
  if (target.startsWith('//') || /^[a-z][a-z\d+.-]*:/i.test(target)) {
    throw new Error(
      `Route paths must be relative to the configured base URL: ${target}`,
    );
  }
  const base = new URL(baseUrl);
  const resolved = new URL(target, base);
  if (resolved.origin !== base.origin) {
    throw new Error(
      `Route paths must resolve inside the configured origin ${base.origin}: ${target}`,
    );
  }
  return resolved.toString();
}

export function resolveDestinationUrl(rawTarget, baseUrl) {
  const target = typeof rawTarget === 'string' ? rawTarget : '';
  assertHttpUrl(baseUrl, 'Runtime base URL');
  if (!target || /[\u0000-\u0020\u007f]/.test(target)) {
    throw new Error('Navigation destinations must be non-empty HTTP(S) URLs without whitespace or control characters.');
  }
  if (target.startsWith('//')) {
    throw new Error('Navigation destinations must not be protocol-relative.');
  }
  if (/^[a-z][a-z\d+.-]*:/i.test(target) && !/^https?:\/\//i.test(target)) {
    throw new Error('Navigation destinations must use HTTP(S).');
  }

  const base = new URL(baseUrl);
  let resolved;
  try {
    resolved = new URL(target, base);
  } catch {
    throw new Error('Navigation destinations must be relative or absolute HTTP(S) URLs.');
  }
  assertHttpUrl(resolved.toString(), 'Navigation destination');
  if (resolved.origin !== base.origin) {
    throw new Error(
      `Navigation destinations must resolve inside the configured origin ${base.origin}.`,
    );
  }
  return resolved.toString();
}
