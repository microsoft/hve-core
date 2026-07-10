// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Pure, browser-free helpers shared by the runtime probes. This module never
// imports Playwright so it can be unit-tested with `node --test` without a
// browser or node_modules.

import { readFile } from 'node:fs/promises';

const PROBE_MAP_URL = new URL('../probe-criteria-map.json', import.meta.url);

// Redact query strings and known secret parameters from a URL before logging.
export function redactUrl(value) {
  if (!value) {
    return '';
  }
  try {
    const url = new URL(value);
    const basePath = `${url.protocol}//${url.host}${url.pathname}`;
    return url.search ? `${basePath}?[redacted]` : basePath;
  } catch {
    return String(value).replace(
      /([?&](token|access_token|sig|code|auth)=)[^&\s]+/gi,
      '$1[redacted]',
    );
  }
}

// Load a single probe's decides/informs entry from probe-criteria-map.json.
export async function loadProbeCriteriaMap(probeId) {
  const payload = JSON.parse(await readFile(PROBE_MAP_URL, 'utf8'));
  const entry = (payload.probes || []).find((probe) => probe.probeId === probeId);
  if (!entry) {
    throw new Error(`Unknown probe id: ${probeId}`);
  }
  return entry;
}

// Build normalized result objects for a probe. `statusByCriterion` overrides the
// per-criterion status so a probe can report each criterion independently rather
// than applying one blanket verdict to every criterion it decides.
export async function buildProbeResults({
  probeId,
  surfaceId,
  state,
  evidence,
  decideStatus = 'pass',
  informStatus = 'candidate',
  statusByCriterion = null,
}) {
  const entry = await loadProbeCriteriaMap(probeId);
  return buildResultsFromEntry({
    entry,
    probeId,
    surfaceId,
    state,
    evidence,
    decideStatus,
    informStatus,
    statusByCriterion,
  });
}

// Pure result assembly split out from the async map read so it can be tested
// directly with a synthetic entry.
export function buildResultsFromEntry({
  entry,
  probeId,
  surfaceId,
  state,
  evidence,
  decideStatus = 'pass',
  informStatus = 'candidate',
  statusByCriterion = null,
}) {
  const results = [];
  const criteriaList = [
    ...(entry.decides || []).filter((item) => (item.states || []).includes(state)),
    ...(entry.informs || []).filter((item) => (item.states || []).includes(state)),
  ];

  for (const item of criteriaList) {
    const isInform = entry.informs?.some(
      (criterion) =>
        criterion.criterionId === item.criterionId &&
        criterion.framework === item.framework,
    );
    let status = isInform ? informStatus : decideStatus;
    if (
      statusByCriterion &&
      Object.prototype.hasOwnProperty.call(statusByCriterion, item.criterionId)
    ) {
      status = statusByCriterion[item.criterionId];
    }
    results.push({
      criterionId: item.criterionId,
      framework: item.framework,
      surfaceId,
      state,
      status,
      method: 'runtime-automation',
      evidence: `${probeId} evaluated ${redactUrl(evidence)} for ${item.criterionId}`,
      severity: item.criterionId === '2.5.8' ? 'moderate' : 'minor',
    });
  }

  return results;
}

// Map an axe `wcag###` tag to a dotted WCAG criterion id, e.g. wcag412 -> 4.1.2.
export function tagToCriterion(tag) {
  const match = /^wcag(\d)(\d)(\d+)$/.exec(tag);
  return match ? `${match[1]}.${match[2]}.${match[3]}` : null;
}

// Given the ordered focus-index sequence observed while pressing Tab, decide
// whether focus is genuinely trapped. Identity is a stable element index (or the
// string 'none' for the body/unmarked). A trap requires the same element index
// to hold focus across three consecutive presses; partial reachability alone is
// never treated as a trap.
export function computeTrapFromSequence(sequence) {
  const reachable = new Set();
  let trapped = false;
  let run = 1;
  for (let index = 0; index < sequence.length; index += 1) {
    const current = sequence[index];
    if (current !== 'none') {
      reachable.add(current);
    }
    if (index > 0 && current !== 'none' && current === sequence[index - 1]) {
      run += 1;
      if (run >= 3) {
        trapped = true;
      }
    } else {
      run = 1;
    }
  }
  return { trapped, reachableCount: reachable.size };
}

// Emit a probe result document as pretty JSON on stdout.
export function emitProbeResult(payload) {
  console.log(JSON.stringify(payload, null, 2));
}
