// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { buildProbeResults, emitProbeResult, injectAxe, runProbeWithPage } from './_shared.mjs';
import { contrastProbeEvaluation } from './_core.mjs';

export async function buildContrastProbePayload({
  axeResults,
  snapshot,
  surfaceId,
  state,
  targetUrl,
}) {
  const evaluation = contrastProbeEvaluation(axeResults);
  const results = await buildProbeResults({
    probeId: 'probe-contrast',
    surfaceId,
    state,
    evidence: `${targetUrl} ${JSON.stringify({
      snapshot,
      colorContrastViolations: evaluation.violations.length,
      colorContrastNodes: evaluation.nodeCount,
      axeAvailable: evaluation.status !== 'candidate',
    })}`,
    decideStatus: evaluation.status,
    informStatus: 'partial',
  });

  return {
    probeId: 'probe-contrast',
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
    const snapshot = await page.evaluate(() => {
      const body = document.body;
      const style = body ? window.getComputedStyle(body) : null;
      return {
        color: style?.color || '',
        backgroundColor: style?.backgroundColor || '',
        fontSize: style?.fontSize || '',
      };
    });
    return buildContrastProbePayload({
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
