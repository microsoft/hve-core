import { buildProbeResults, emitProbeResult, injectAxe, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const axeResults = await injectAxe(page);
    const snapshot = await page.evaluate(() => {
      const body = document.body;
      const style = body ? window.getComputedStyle(body) : null;
      return {
        color: style?.color || '',
        backgroundColor: style?.backgroundColor || '',
        fontSize: style?.fontSize || '',
      };
    });
    const colorContrastViolations = (axeResults?.violations || []).filter((violation) => violation.id === 'color-contrast');
    const hasDefect = colorContrastViolations.reduce((count, violation) => count + ((violation.nodes || []).length), 0) > 0;

    const results = await buildProbeResults({
      probeId: 'probe-contrast',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify({ snapshot, colorContrastViolations: colorContrastViolations.length, colorContrastNodes: colorContrastViolations.reduce((count, violation) => count + ((violation.nodes || []).length), 0) })}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'partial',
    });

    return {
      probeId: 'probe-contrast',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
