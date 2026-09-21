// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { emitProbeResult, redactUrl, runProbeWithPage } from './_shared.mjs';
import { resolveDestinationUrl } from './route.mjs';

export const MAX_REDIRECT_HOPS = 5;

const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

// HEAD-hostile endpoints answer 405/501 rather than throwing, so a GET retry
// keeps a valid GET-only URL from being reported broken.
const GET_FALLBACK_STATUSES = new Set([405, 501]);

function readStatus(response) {
  return typeof response?.status === 'function' ? response.status() : 0;
}

async function requestWithoutRedirects(request, url, timeout) {
  const options = { timeout, maxRedirects: 0 };
  let response;
  try {
    response = await request.head(url, options);
  } catch {
    return request.get(url, options);
  }
  if (GET_FALLBACK_STATUSES.has(readStatus(response))) {
    return request.get(url, options);
  }
  return response;
}

export async function checkLinkWithRedirects(
  request,
  initialUrl,
  { timeout = 3000, maxRedirectHops = MAX_REDIRECT_HOPS } = {},
) {
  let currentUrl = initialUrl;
  const visited = new Set([currentUrl]);
  let redirects = 0;

  while (true) {
    let response;
    try {
      response = await requestWithoutRedirects(request, currentUrl, timeout);
    } catch {
      return { broken: true, reason: 'request-failed', redirects };
    }

    const status = typeof response?.status === 'function' ? response.status() : 0;
    if (!REDIRECT_STATUSES.has(status)) {
      return {
        broken: !response || status >= 400,
        reason: !response ? 'missing-response' : null,
        status,
        redirects,
      };
    }
    if (redirects >= maxRedirectHops) {
      return { broken: true, reason: 'redirect-limit', status, redirects };
    }

    const headers = typeof response?.headers === 'function' ? response.headers() : {};
    const locationEntry = Object.entries(headers || {}).find(
      ([name]) => name.toLowerCase() === 'location',
    );
    if (!locationEntry?.[1]) {
      return { broken: true, reason: 'redirect-location-missing', status, redirects };
    }

    let nextUrl;
    try {
      nextUrl = resolveDestinationUrl(locationEntry[1], currentUrl);
    } catch {
      return { broken: true, reason: 'redirect-policy', status, redirects };
    }
    if (visited.has(nextUrl)) {
      return { broken: true, reason: 'redirect-loop', status, redirects };
    }

    visited.add(nextUrl);
    currentUrl = nextUrl;
    redirects += 1;
  }
}

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, context, surface, state, targetUrl }) => {
    const hrefs = await page.evaluate((resolvedUrl) => {
      const seen = new Set();
      const links = [];
      for (const anchor of document.querySelectorAll('a[href]')) {
        const rawHref = anchor.getAttribute('href');
        if (!rawHref) {
          continue;
        }
        try {
          const absoluteUrl = new URL(rawHref, resolvedUrl).toString();
          const { origin } = new URL(absoluteUrl);
          const { origin: baseOrigin } = new URL(resolvedUrl);
          if (origin !== baseOrigin) {
            continue;
          }
          if (!seen.has(absoluteUrl)) {
            seen.add(absoluteUrl);
            links.push(absoluteUrl);
          }
        } catch {
          // Ignore malformed hrefs.
        }
      }
      return links.slice(0, 40);
    }, targetUrl);

    const brokenLinks = [];
    for (const linkUrl of hrefs) {
      const result = await checkLinkWithRedirects(context.request, linkUrl);
      if (result.broken) {
        brokenLinks.push(linkUrl);
      }
    }

    const hasBroken = brokenLinks.length > 0;

    return {
      probeId: 'probe-broken-links',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: 'DEFECT:broken-link',
          framework: 'defect-scan',
          surfaceId: surface?.id || 'unknown',
          state,
          status: hasBroken ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: JSON.stringify({
            checkedCount: hrefs.length,
            brokenCount: brokenLinks.length,
            brokenLinks: brokenLinks.slice(0, 10).map((value) => redactUrl(value)),
          }),
          severity: hasBroken ? 'serious' : 'minor',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
