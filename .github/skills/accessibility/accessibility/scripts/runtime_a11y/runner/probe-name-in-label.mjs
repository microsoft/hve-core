import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const controls = Array.from(
        document.querySelectorAll(
          'a[aria-label], button[aria-label], input[aria-label], [role="button"][aria-label]',
        ),
      );
      const mismatches = controls.filter((el) => {
        const accessibleName = (el.getAttribute('aria-label') || '').trim().toLowerCase();
        const visibleText = (el.textContent || '').trim().toLowerCase();
        return visibleText && accessibleName && !accessibleName.includes(visibleText);
      });
      return {
        labeledControls: controls.length,
        labelInNameMismatches: mismatches.length,
      };
    });
    const hasDefect = snapshot.labelInNameMismatches > 0;

    const results = await buildProbeResults({
      probeId: 'probe-name-in-label',
      surfaceId: surface?.id || 'unknown',
      state,
      evidence: `${targetUrl} ${JSON.stringify(snapshot)}`,
      decideStatus: hasDefect ? 'fail' : 'pass',
      informStatus: 'candidate',
    });

    return {
      probeId: 'probe-name-in-label',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
