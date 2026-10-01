// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { buildProbeResults, emitProbeResult, injectAxe, redactUrl, runProbeWithPage } from './_shared.mjs';
import { axeProbeEvaluation } from './_core.mjs';

const STRUCTURAL_DECIDES = ['1.3.1', '2.4.1', '2.4.2', '3.1.1'];

export async function buildAxeProbePayload({
  axeResults,
  snapshot,
  surfaceId,
  state,
  targetUrl,
}) {
  const evaluation = axeProbeEvaluation(axeResults, STRUCTURAL_DECIDES);
  const evidence = {
    targetUrl,
    snapshot,
    axeAvailable: evaluation.available,
    axeViolations: evaluation.violations.length,
    violationRuleIds: evaluation.violations.map((violation) => violation.id).slice(0, 15),
  };
  const results = await buildProbeResults({
    probeId: 'probe-axe',
    surfaceId,
    state,
    evidence: `${targetUrl} ${JSON.stringify(evidence)}`,
    decideStatus: evaluation.available ? 'pass' : 'candidate',
    informStatus: 'candidate',
    statusByCriterion: evaluation.statusByCriterion,
  });

  // Emit an authoritative fail for every axe-implicated criterion not already
  // covered by the probe's structural decides, so real violations surface
  // under their true criterion (for example aria-allowed-attr -> 4.1.2).
  const covered = new Set(results.map((result) => result.criterionId));
  for (const [criterion, rules] of evaluation.criterionToRules) {
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
}

export async function runProbe(dependencies = {}) {
  const executeWithPage = dependencies.runProbeWithPage || runProbeWithPage;
  const analyzeWithAxe = dependencies.injectAxe || injectAxe;
  const emit = dependencies.emitProbeResult || emitProbeResult;
  const payload = await executeWithPage(async ({ page, surface, state, targetUrl }) => {
    const axeResults = await analyzeWithAxe(page);
    const snapshot = await page.evaluate(() => ({
      title: document.title || '',
      landmarks: document.querySelectorAll('main, nav, header, footer, [role="main"]').length,
      focusables: document.querySelectorAll('a, button, input, select, textarea, [tabindex]').length,
    }));
    return buildAxeProbePayload({
      axeResults,
      snapshot,
      surfaceId: surface?.id || 'unknown',
      state,
      targetUrl,
    });
  });

  emit(payload);
  return payload;
}
