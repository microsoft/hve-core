// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { buildProbeResults, emitProbeResult, runProbeWithPage, snapshotAccessibilityTree } from './_shared.mjs';
import { ariaTreeNameEvaluation } from './_core.mjs';

export async function buildAriaTreeProbePayload({
  accessibilityTree,
  snapshot,
  surfaceId,
  state,
  targetUrl,
}) {
  const evaluation = ariaTreeNameEvaluation(accessibilityTree);
  const evidencePayload = {
    snapshot,
    accessibilityTreeSource: evaluation.source,
    accessibilityNodeCount: evaluation.nodeCount,
    treeIssueCount: evaluation.namelessRoles.length,
    namelessRoles: evaluation.namelessRoles.slice(0, 10),
    // Capped to avoid bloating evidence payloads on complex pages.
    accessibilityTreeSample: JSON.stringify(accessibilityTree).slice(0, 2000),
  };
  const results = await buildProbeResults({
    probeId: 'probe-aria-tree',
    surfaceId,
    state,
    evidence: `${targetUrl} ${JSON.stringify(evidencePayload)}`,
    decideStatus: evaluation.status,
    informStatus: 'partial',
  });

  return {
    probeId: 'probe-aria-tree',
    runAt: new Date().toISOString(),
    baseUrl: targetUrl,
    results,
  };
}

export async function runProbe(dependencies = {}) {
  const executeWithPage = dependencies.runProbeWithPage || runProbeWithPage;
  const captureTree = dependencies.snapshotAccessibilityTree
    || snapshotAccessibilityTree;
  const emit = dependencies.emitProbeResult || emitProbeResult;
  const payload = await executeWithPage(async ({ page, surface, state, targetUrl }) => {
    const accessibilityTree = await captureTree(page);
    const snapshot = await page.evaluate(() => ({
      roles: document.querySelectorAll('[role]').length,
      labels: document.querySelectorAll('[aria-label], [aria-labelledby], label').length,
      accessibleNameCount: document.querySelectorAll('[aria-label], [aria-labelledby], [name]').length,
    }));
    return buildAriaTreeProbePayload({
      accessibilityTree,
      snapshot,
      surfaceId: surface?.id || 'unknown',
      state,
      targetUrl,
    });
  });

  emit(payload);
  return payload;
}
