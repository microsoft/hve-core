import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
      fontSize: getComputedStyle(document.documentElement).fontSize,
    }));
    const hasDefect = snapshot.scrollWidth > snapshot.clientWidth + 1;

    const results = await buildProbeResults({
      probeId: 'probe-reflow-resize',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'candidate',
    });

    return {
      probeId: 'probe-reflow-resize',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
