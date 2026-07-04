import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const controls = Array.from(document.querySelectorAll('input, textarea, select'));
      const missingAutocomplete = [];

      for (const control of controls) {
        const nameId = `${control.name || ''} ${control.id || ''} ${control.type || ''}`.toLowerCase();
        const isSensitive = ['name', 'email', 'tel', 'phone', 'address', 'zip', 'postal', 'cc', 'card'].some((token) => nameId.includes(token));
        if (!isSensitive) {
          continue;
        }

        const autocomplete = (control.getAttribute('autocomplete') || '').trim().toLowerCase();
        const hasAppropriateAutocomplete = autocomplete && (
          autocomplete.includes('name') ||
          autocomplete.includes('email') ||
          autocomplete.includes('tel') ||
          autocomplete.includes('street-address') ||
          autocomplete.includes('postal-code') ||
          autocomplete.includes('cc-number') ||
          autocomplete.includes('cc-exp')
        );

        if (!hasAppropriateAutocomplete) {
          missingAutocomplete.push(control.tagName.toLowerCase());
        }
      }

      return {
        missingAutocompleteCount: missingAutocomplete.length,
      };
    });

    return {
      probeId: 'probe-input-purpose',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '1.3.5',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.missingAutocompleteCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `1.3.5 missing autocomplete=${snapshot.missingAutocompleteCount}`,
          severity: 'moderate',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
