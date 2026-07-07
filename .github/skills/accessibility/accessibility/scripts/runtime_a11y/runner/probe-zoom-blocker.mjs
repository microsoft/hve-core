import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const viewport = document.querySelector('meta[name="viewport"]');
      const content = viewport ? viewport.getAttribute('content') || '' : '';
      const lower = content.toLowerCase();
      const userScalableNo = /user-scalable\s*=\s*no/i.test(lower);
      const maxScaleBelowOne = /maximum-scale\s*=\s*([0-9.]+)/i.exec(lower);
      const zoomBlocked = userScalableNo || (maxScaleBelowOne && Number(maxScaleBelowOne[1]) <= 1);

      return {
        content,
        zoomBlocked,
      };
    });

    return {
      probeId: 'probe-zoom-blocker',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.4.4',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.zoomBlocked ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.4.4 viewport=${snapshot.content}`,
          severity: 'moderate',
        },
        {
          criterionId: '1.4.10',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: 'candidate',
          method: 'runtime-automation',
          evidence: `1.4.10 viewport=${snapshot.content}`,
          severity: 'minor',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
