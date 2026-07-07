import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const focusables = Array.from(document.querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"]), [role="button"]'));
      const observations = [];

      for (const element of focusables.slice(0, 5)) {
        element.focus();
        const rect = element.getBoundingClientRect();
        const pointX = Math.min(Math.max(rect.left + 1, 0), window.innerWidth - 1);
        const pointY = Math.min(Math.max(rect.top + 1, 0), window.innerHeight - 1);
        const covering = document.elementFromPoint(pointX, pointY);
        const coveringStyle = covering ? window.getComputedStyle(covering) : null;
        const isCovered = Boolean(
          covering &&
            covering !== element &&
            ['fixed', 'sticky'].includes(coveringStyle?.position || '') &&
            rect.top >= 0 &&
            rect.left >= 0 &&
            rect.bottom <= window.innerHeight &&
            rect.right <= window.innerWidth,
        );
        const outOfViewport = rect.top < 0 || rect.left < 0 || rect.bottom > window.innerHeight || rect.right > window.innerWidth;
        observations.push({
          tagName: element.tagName.toLowerCase(),
          rect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          isCovered,
          outOfViewport,
        });
      }

      return {
        focusableCount: focusables.length,
        obscuredCount: observations.filter((entry) => entry.isCovered || entry.outOfViewport).length,
        observations,
      };
    });
    const hasDefect = snapshot.obscuredCount > 0;

    const results = await buildProbeResults({
      probeId: 'probe-focus-obscured',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-focus-obscured',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
