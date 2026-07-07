import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const refresh = document.querySelector('meta[http-equiv="refresh"]');
      const content = refresh ? refresh.getAttribute('content') || '' : '';
      const numericTimeout = /\b(\d+)(\s|$)/.exec(content);

      return {
        content,
        numericTimeout: numericTimeout ? Number(numericTimeout[1]) : null,
      };
    });

    return {
      probeId: 'probe-timing',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '2.2.1',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.numericTimeout !== null ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `2.2.1 refresh content=${snapshot.content}`,
          severity: 'moderate',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
