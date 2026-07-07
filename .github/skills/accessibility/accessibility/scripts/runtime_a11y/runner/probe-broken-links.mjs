import { emitProbeResult, redactUrl, runProbeWithPage } from './_shared.mjs';

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
      try {
        const response = await context.request.head(linkUrl, { timeout: 3000 }).catch(async () => context.request.get(linkUrl, { timeout: 3000 }));
        const status = typeof response?.status === 'function' ? response.status() : 0;
        if (!response || status >= 400) {
          brokenLinks.push(linkUrl);
        }
      } catch {
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
