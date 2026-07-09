import { emitProbeResult, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('a[href]'));
      const ambiguousTerms = ['click here', 'read more', 'learn more', 'more', 'here', 'link'];
      const offending = [];
      const visibleTexts = new Map();

      for (const link of links) {
        const ariaLabel = (link.getAttribute('aria-label') || '').trim();
        const visibleText = (link.textContent || '').trim();
        const accessibleText = ariaLabel || visibleText;
        const normalizedText = accessibleText.toLowerCase().replace(/\s+/g, ' ');

        if (!accessibleText) {
          offending.push('empty');
          continue;
        }

        if (ambiguousTerms.includes(normalizedText)) {
          offending.push(`ambiguous:${normalizedText}`);
        }

        const key = visibleText.toLowerCase();
        if (!visibleTexts.has(key)) {
          visibleTexts.set(key, []);
        }
        visibleTexts.get(key).push(link.getAttribute('href') || '');
      }

      for (const values of visibleTexts.values()) {
        const uniqueHrefs = new Set(values);
        if (uniqueHrefs.size > 1) {
          offending.push(`duplicate:${values.length}`);
        }
      }

      return {
        offendingCount: offending.length,
      };
    });

    return {
      probeId: 'probe-link-purpose',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results: [
        {
          criterionId: '2.4.4',
          framework: 'wcag-22',
          surfaceId: surface?.id || 'unknown',
          state,
          status: snapshot.offendingCount > 0 ? 'fail' : 'pass',
          method: 'runtime-automation',
          evidence: `2.4.4 ambiguous or empty links=${snapshot.offendingCount}`,
          severity: 'serious',
        },
      ],
    };
  });

  emitProbeResult(payload);
}
