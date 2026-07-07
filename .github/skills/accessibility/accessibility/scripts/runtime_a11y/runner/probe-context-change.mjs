import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const controls = Array.from(document.querySelectorAll('*'));
      const onFocus = [];
      const onChange = [];

      for (const control of controls) {
        const attrs = control.getAttributeNames ? control.getAttributeNames() : [];
        if (attrs.some((name) => name === 'onfocus' || name === 'onchange')) {
          const value = (control.getAttribute('onfocus') || control.getAttribute('onchange') || '').toLowerCase();
          if (value.includes('location') || value.includes('window.open') || value.includes('form.submit') || value.includes('submit(')) {
            if (control.hasAttribute('onfocus')) {
              onFocus.push(control.tagName.toLowerCase());
            }
            if (control.hasAttribute('onchange')) {
              onChange.push(control.tagName.toLowerCase());
            }
          }
        }
      }

      const selectNavigations = Array.from(document.querySelectorAll('select[onchange]')).filter((control) => {
        const value = (control.getAttribute('onchange') || '').toLowerCase();
        return value.includes('location') || value.includes('window.location') || value.includes('window.open') || value.includes('submit(');
      });

      return {
        onFocusCount: onFocus.length,
        onChangeCount: onChange.length + selectNavigations.length,
      };
    });

    return {
      probeId: 'probe-context-change',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '3.2.1',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.onFocusCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `3.2.1 focus context changes=${snapshot.onFocusCount}`,
          severity: 'moderate',
        },
        {
          criterionId: '3.2.2',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.onChangeCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `3.2.2 change context changes=${snapshot.onChangeCount}`,
          severity: 'moderate',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
