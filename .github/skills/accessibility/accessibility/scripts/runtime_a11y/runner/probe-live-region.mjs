import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    await page.addInitScript(() => {
      window.__runtimeA11yLiveRegionState = [];
      const observer = new MutationObserver((mutations) => {
        window.__runtimeA11yLiveRegionState = mutations.slice(0, 5).map((mutation) => ({
          type: mutation.type,
          target: mutation.target?.nodeName || '',
        }));
      });
      observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    });

    const snapshot = await page.evaluate(() => ({
      liveRegions: document.querySelectorAll('[aria-live], [role="status"], [role="alert"]').length,
      hasStatus: document.querySelector('[role="status"], [role="alert"]') !== null,
      mutations: window.__runtimeA11yLiveRegionState || [],
    }));
    const expectsStatusMessage = /error|open/i.test(state);
    const hasDefect = expectsStatusMessage && snapshot.liveRegions === 0;

    const results = await buildProbeResults({
      probeId: 'probe-live-region',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-live-region',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
