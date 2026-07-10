import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const focusables = Array.from(document.querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"]), [role="button"]'));
      const riskyIndicators = focusables.filter((element) => {
        const style = window.getComputedStyle(element);
        const noVisibleOutline = style.outlineStyle === 'none' || style.outlineWidth === '0px' || style.outlineColor === 'rgba(0, 0, 0, 0)';
        const forcedColorAdjust = style.forcedColorAdjust;
        const usesBackgroundImage = Boolean(style.backgroundImage && style.backgroundImage !== 'none');
        return !forcedColorAdjust && noVisibleOutline && usesBackgroundImage;
      });
      return {
        forcedColors: window.matchMedia('(forced-colors: active)').matches,
        colorScheme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
        activeElement: document.activeElement?.tagName || '',
        focusableCount: focusables.length,
        riskyIndicators: riskyIndicators.length,
      };
    });
    const hasDefect = snapshot.forcedColors && snapshot.riskyIndicators > 0;

    const results = await buildProbeResults({
      probeId: 'probe-forced-colors',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-forced-colors',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
