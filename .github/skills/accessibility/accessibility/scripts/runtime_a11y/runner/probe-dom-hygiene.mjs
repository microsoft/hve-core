import { emitProbeResult, redactUrl, runProbeWithPage } from './_shared.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await page.evaluate(() => {
      const idValues = Array.from(document.querySelectorAll('[id]')).map((element) => element.id).filter(Boolean);
      const duplicateIds = [];
      const seenIds = new Map();
      for (const idValue of idValues) {
        const count = seenIds.get(idValue) || 0;
        seenIds.set(idValue, count + 1);
      }
      for (const [idValue, count] of seenIds.entries()) {
        if (count > 1) {
          duplicateIds.push(idValue);
        }
      }

      const positiveTabIndexCount = Array.from(document.querySelectorAll('[tabindex]')).filter((element) => {
        const value = Number(element.getAttribute('tabindex'));
        return Number.isFinite(value) && value > 0;
      }).length;

      const landmarkCount = document.querySelectorAll('main, nav, header, footer, aside, [role="main"], [role="navigation"], [role="banner"], [role="contentinfo"], [role="complementary"]').length;
      const mainCount = document.querySelectorAll('main, [role="main"]').length;

      return {
        duplicateIds,
        positiveTabIndexCount,
        landmarkCount,
        mainCount,
      };
    });

    const results = [
      {
        criterionId: 'DEFECT:duplicate-id',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.duplicateIds.length > 0 ? 'fail' : 'pass',
        method: 'runtime-automation',
        // duplicateIds are page-derived strings; redact them before emitting so
        // this probe follows the same log-hygiene contract as the sibling probes.
        evidence: JSON.stringify({ duplicateIds: snapshot.duplicateIds.slice(0, 10).map((value) => redactUrl(value)) }),
        severity: snapshot.duplicateIds.length > 0 ? 'moderate' : 'minor',
      },
      {
        criterionId: 'DEFECT:positive-tabindex',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.positiveTabIndexCount > 0 ? 'fail' : 'pass',
        method: 'runtime-automation',
        evidence: JSON.stringify({ positiveTabIndexCount: snapshot.positiveTabIndexCount }),
        severity: snapshot.positiveTabIndexCount > 0 ? 'moderate' : 'minor',
      },
      {
        criterionId: 'DEFECT:missing-landmark',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.landmarkCount === 0 ? 'fail' : 'pass',
        method: 'runtime-automation',
        evidence: JSON.stringify({ landmarkCount: snapshot.landmarkCount }),
        severity: snapshot.landmarkCount === 0 ? 'serious' : 'minor',
      },
      {
        criterionId: 'DEFECT:duplicate-main',
        framework: 'defect-scan',
        surfaceId: surface?.id || 'unknown',
        state,
        status: snapshot.mainCount > 1 ? 'fail' : 'pass',
        method: 'runtime-automation',
        evidence: JSON.stringify({ mainCount: snapshot.mainCount }),
        severity: snapshot.mainCount > 1 ? 'serious' : 'minor',
      },
    ];

    return {
      probeId: 'probe-dom-hygiene',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
