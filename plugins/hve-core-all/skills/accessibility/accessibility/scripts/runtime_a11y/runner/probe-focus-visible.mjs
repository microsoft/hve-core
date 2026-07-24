import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const focusable = document.querySelector('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"]), [role="button"]');
      if (focusable) {
        focusable.focus();
      }
      const active = document.activeElement;
      const style = active ? window.getComputedStyle(active) : null;
      const outlineStyle = style?.outlineStyle || '';
      const boxShadow = style?.boxShadow || '';
      const hasVisibleIndicator = Boolean((outlineStyle && outlineStyle !== 'none') || (boxShadow && boxShadow !== 'none' && boxShadow !== 'initial'));
      return {
        activeTag: active?.tagName || '',
        focusTarget: focusable?.tagName.toLowerCase() || '',
        outlineStyle,
        outlineWidth: style?.outlineWidth || '',
        boxShadow,
        hasVisibleIndicator,
      };
    });
    const hasDefect = Boolean(snapshot.focusTarget && !snapshot.hasVisibleIndicator);

    const results = await buildProbeResults({
      probeId: 'probe-focus-visible',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-focus-visible',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
