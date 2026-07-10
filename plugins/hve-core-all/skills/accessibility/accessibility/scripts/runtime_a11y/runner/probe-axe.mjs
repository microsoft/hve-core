import { buildProbeResults, emitProbeResult, injectAxe, redactUrl, runProbeWithPage } from './_shared.mjs';
import { tagToCriterion } from './_core.mjs';

export async function runProbe() {
  const payload = await runProbeWithPage(async ({ page, surface, state, targetUrl }) => {
    const axeResults = await injectAxe(page);
    const snapshot = await page.evaluate(() => ({
      title: document.title || '',
      landmarks: document.querySelectorAll('main, nav, header, footer, [role="main"]').length,
      focusables: document.querySelectorAll('a, button, input, select, textarea, [tabindex]').length,
    }));

    const violations = axeResults?.violations || [];
    // Map each implicated WCAG criterion to the axe rule ids that flagged it.
    const criterionToRules = new Map();
    for (const violation of violations) {
      for (const tag of violation.tags || []) {
        const criterion = tagToCriterion(tag);
        if (!criterion) {
          continue;
        }
        if (!criterionToRules.has(criterion)) {
          criterionToRules.set(criterion, new Set());
        }
        criterionToRules.get(criterion).add(violation.id);
      }
    }

    const surfaceId = surface?.id || 'unknown';
    const evidence = {
      targetUrl,
      snapshot,
      axeViolations: violations.length,
      violationRuleIds: violations.map((v) => v.id).slice(0, 15),
    };

    // The probe's nominal structural decides pass unless axe implicated them.
    const structuralDecides = ['1.3.1', '2.4.1', '2.4.2', '3.1.1'];
    const statusByCriterion = {};
    for (const criterion of structuralDecides) {
      statusByCriterion[criterion] = criterionToRules.has(criterion) ? 'fail' : 'pass';
    }

    const results = await buildProbeResults({
      probeId: 'probe-axe',
      surfaceId,
      state,
      evidence: `${targetUrl} ${JSON.stringify(evidence)}`,
      decideStatus: 'pass',
      informStatus: 'candidate',
      statusByCriterion,
    });

    // Emit an authoritative fail for every axe-implicated criterion not already
    // covered by the probe's structural decides, so real violations surface
    // under their true criterion (for example aria-allowed-attr -> 4.1.2).
    const covered = new Set(results.map((r) => r.criterionId));
    for (const [criterion, rules] of criterionToRules) {
      if (covered.has(criterion)) {
        continue;
      }
      results.push({
        criterionId: criterion,
        framework: 'wcag-22',
        surfaceId,
        state,
        status: 'fail',
        method: 'runtime-automation',
        evidence: `probe-axe ${redactUrl(targetUrl)} axe rules: ${[...rules].join(', ')}`,
        severity: 'serious',
      });
    }

    return {
      probeId: 'probe-axe',
      runAt: new Date().toISOString(),
      baseUrl: targetUrl,
      results,
    };
  });

  emitProbeResult(payload);
}
