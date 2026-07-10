import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const controls = Array.from(document.querySelectorAll('input:not([type="hidden"]), select, textarea'));
      const unlabeled = [];

      for (const control of controls) {
        const hasLabel = Array.from(document.querySelectorAll('label')).some((label) => label.htmlFor && label.htmlFor === control.id) ||
          Array.from(document.querySelectorAll('label')).some((label) => label.contains(control)) ||
          control.getAttribute('aria-label') ||
          control.getAttribute('aria-labelledby');

        if (!hasLabel) {
          unlabeled.push(control.tagName.toLowerCase());
        }
      }

      return {
        unlabeledControlCount: unlabeled.length,
      };
    });

    return {
      probeId: 'probe-forms',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '3.3.2',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.unlabeledControlCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `3.3.2 unlabeled controls=${snapshot.unlabeledControlCount}`,
          severity: 'serious',
        },
        {
          criterionId: '3.3.1',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: 'candidate',
          method: 'runtime-automation',
          evidence: `3.3.1 informs from unlabeled controls=${snapshot.unlabeledControlCount}`,
          severity: 'moderate',
        },
        {
          criterionId: '3.3.3',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: 'candidate',
          method: 'runtime-automation',
          evidence: `3.3.3 informs from unlabeled controls=${snapshot.unlabeledControlCount}`,
          severity: 'moderate',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
