import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const headingLevels = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6')).map(
        (el) => Number(el.tagName.substring(1)),
      );
      const hasSkippedHeading = headingLevels.some((level, index) => index > 0 && level - headingLevels[index - 1] > 1);
      return {
        title: document.title || '',
        lang: document.documentElement.getAttribute('lang') || '',
        landmarks: document.querySelectorAll(
          'main, nav, header, footer, aside, [role="main"], [role="navigation"], [role="banner"], [role="contentinfo"]',
        ).length,
        headingLevels,
        hasSkippedHeading,
        h1Count: document.querySelectorAll('h1').length,
        skipLinks: document.querySelectorAll('a[href^="#"]').length,
      };
    });
    const hasDefect = snapshot.h1Count === 0 || snapshot.hasSkippedHeading || !snapshot.lang.trim() || snapshot.landmarks === 0;

    const statusByCriterion = {
      '1.3.1': snapshot.h1Count === 0 || snapshot.hasSkippedHeading ? 'fail' : 'pass',
      '2.4.1': snapshot.landmarks === 0 && snapshot.skipLinks === 0 ? 'fail' : 'pass',
      '2.4.2': snapshot.title.trim() ? 'pass' : 'fail',
      '3.1.1': snapshot.lang.trim() ? 'pass' : 'fail',
    };

    const results = await buildProbeResults({
      probeId: 'probe-structure-crawl',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'candidate',
      statusByCriterion,
    });

    return {
      probeId: 'probe-structure-crawl',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
