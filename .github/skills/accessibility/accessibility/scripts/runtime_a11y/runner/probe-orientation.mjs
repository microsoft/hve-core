import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const stylesheets = Array.from(document.styleSheets);
      const cssText = stylesheets.map((sheet) => {
        try {
          return Array.from(sheet.cssRules || []).map((rule) => rule.cssText).join(' ');
        } catch {
          return '';
        }
      }).join(' ');
      const hasPortraitLock = /orientation\s*:\s*portrait/i.test(cssText);
      const hasLandscapeLock = /orientation\s*:\s*landscape/i.test(cssText);
      const hasDisplayNone = /display\s*:\s*none/i.test(cssText);
      const hasVisibilityHidden = /visibility\s*:\s*hidden/i.test(cssText);

      return {
        hasPortraitLock,
        hasLandscapeLock,
        hasDisplayNone,
        hasVisibilityHidden,
      };
    });

    const hasLock = snapshot.hasPortraitLock || snapshot.hasLandscapeLock;

    return {
      probeId: 'probe-orientation',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.3.4',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: hasLock ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.3.4 orientation lock=${hasLock}`,
          severity: 'moderate',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
