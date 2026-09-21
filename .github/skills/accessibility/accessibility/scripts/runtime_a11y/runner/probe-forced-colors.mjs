// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { buildProbeResults, emitProbeResult, runProbeWithPage } from './_shared.mjs';
import { isForcedColorsIndicatorRisk } from './_core.mjs';

export async function captureForcedColorsSnapshot(page) {
  return page.evaluate(() => {
    const focusables = Array.from(document.querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"]), [role="button"]'));
    const indicatorStyles = focusables.map((element) => {
      const style = window.getComputedStyle(element);
      return {
        backgroundImage: style.backgroundImage,
        forcedColorAdjust: style.forcedColorAdjust,
        outlineColor: style.outlineColor,
        outlineStyle: style.outlineStyle,
        outlineWidth: style.outlineWidth,
      };
    });
    return {
      forcedColors: window.matchMedia('(forced-colors: active)').matches,
      colorScheme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
      activeElement: document.activeElement?.tagName || '',
      focusableCount: focusables.length,
      indicatorStyles,
    };
  });
}

export async function buildForcedColorsProbePayload({
  snapshot,
  surfaceId,
  state,
  targetUrl,
}) {
  const riskyIndicators = (snapshot?.indicatorStyles || [])
    .filter(isForcedColorsIndicatorRisk).length;
  const evidenceSnapshot = {
    ...snapshot,
    indicatorStyles: undefined,
    riskyIndicators,
  };
  const hasDefect = snapshot?.forcedColors === true && riskyIndicators > 0;

  const results = await buildProbeResults({
    probeId: 'probe-forced-colors',
    surfaceId,
    state,
    evidence: `${targetUrl} ${JSON.stringify(evidenceSnapshot)}`,
    decideStatus: hasDefect ? 'fail' : 'pass',
    informStatus: 'partial',
  });

  return {
    probeId: 'probe-forced-colors',
    runAt: new Date().toISOString(),
    baseUrl: targetUrl,
    results,
  };
}

export async function runProbe(dependencies = {}) {
  const executeWithPage = dependencies.runProbeWithPage || runProbeWithPage;
  const captureSnapshot = dependencies.captureForcedColorsSnapshot
    || captureForcedColorsSnapshot;
  const emit = dependencies.emitProbeResult || emitProbeResult;
  const payload = await executeWithPage(async ({ page, surface, state, targetUrl }) => {
    const snapshot = await captureSnapshot(page);
    return buildForcedColorsProbePayload({
      snapshot,
      surfaceId: surface?.id || 'unknown',
      state,
      targetUrl,
    });
  });

  emit(payload);
  return payload;
}
