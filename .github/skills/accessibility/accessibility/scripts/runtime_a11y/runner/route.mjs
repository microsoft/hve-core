// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

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
