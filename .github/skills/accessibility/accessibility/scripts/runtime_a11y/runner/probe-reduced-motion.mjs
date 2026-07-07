import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => ({
      prefersReducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches,
      animatedElements: document.querySelectorAll('[style*="animation"], .animate, [data-animate]').length,
      infiniteAnimations: Array.from(document.querySelectorAll('*')).filter((el) => {
        const style = getComputedStyle(el);
        return style.animationIterationCount === 'infinite' && style.animationName !== 'none' && style.animationPlayState !== 'paused';
      }).length,
    }));
    const hasDefect = state.includes('reduced-motion') && snapshot.infiniteAnimations > 0;

    const results = await buildProbeResults({
      probeId: 'probe-reduced-motion',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'candidate',
    });

    return {
      probeId: 'probe-reduced-motion',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
