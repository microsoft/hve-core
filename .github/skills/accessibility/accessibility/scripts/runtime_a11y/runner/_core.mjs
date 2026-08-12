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
  method = 'runtime-automation',
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
    method,
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
  method = 'runtime-automation',
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
      method,
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

// Axe analysis is available only when the result contains an evaluated
// violations array. A missing builder or thrown scan returns null upstream and
// must not be interpreted as a clean page.
export function contrastProbeEvaluation(axeResults) {
  if (!axeResults || !Array.isArray(axeResults.violations)) {
    return { status: 'candidate', violations: [], nodeCount: 0 };
  }

  const violations = axeResults.violations.filter(
    (violation) => violation?.id === 'color-contrast',
  );
  const nodeCount = violations.reduce(
    (count, violation) => count + (Array.isArray(violation.nodes) ? violation.nodes.length : 0),
    0,
  );
  return {
    status: nodeCount > 0 ? 'fail' : 'pass',
    violations,
    nodeCount,
  };
}

export function axeProbeEvaluation(axeResults, structuralCriteria = []) {
  const criterionToRules = new Map();
  if (!axeResults || !Array.isArray(axeResults.violations)) {
    return {
      available: false,
      violations: [],
      criterionToRules,
      statusByCriterion: Object.fromEntries(
        structuralCriteria.map((criterion) => [criterion, 'candidate']),
      ),
    };
  }

  for (const violation of axeResults.violations) {
    for (const tag of violation?.tags || []) {
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

  return {
    available: true,
    violations: axeResults.violations,
    criterionToRules,
    statusByCriterion: Object.fromEntries(
      structuralCriteria.map((criterion) => [
        criterion,
        criterionToRules.has(criterion) ? 'fail' : 'pass',
      ]),
    ),
  };
}

export function isForcedColorsIndicatorRisk(style) {
  if (!style || String(style.forcedColorAdjust || '').toLowerCase() !== 'none') {
    return false;
  }
  const noVisibleOutline = style.outlineStyle === 'none'
    || style.outlineWidth === '0px'
    || style.outlineColor === 'rgba(0, 0, 0, 0)';
  const usesBackgroundImage = Boolean(
    style.backgroundImage && style.backgroundImage !== 'none',
  );
  return noVisibleOutline && usesBackgroundImage;
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

// Interactive roles as announced by the virtual screen reader. A spoken phrase
// that is exactly one of these role tokens with no trailing accessible name
// indicates a control with a missing name (WCAG 4.1.2 Name, Role, Value).
const VSR_INTERACTIVE_ROLES = new Set([
  'button',
  'link',
  'checkbox',
  'radio',
  'combobox',
  'textbox',
  'searchbox',
  'menuitem',
  'menuitemcheckbox',
  'menuitemradio',
  'tab',
  'switch',
  'slider',
  'spinbutton',
  'option',
  'treeitem',
]);

function unwrapAxValue(value) {
  if (value && typeof value === 'object' && typeof value.value === 'string') {
    return value.value.trim();
  }
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeCdpAxNodes(nodes) {
  if (!Array.isArray(nodes) || nodes.length === 0) {
    return null;
  }
  if (nodes.some((node) => node?.ignored !== true && !(
    node?.role
    && typeof node.role === 'object'
    && typeof node.role.value === 'string'
  ))) {
    return null;
  }

  const byId = new Map(nodes.map((node) => [String(node.nodeId), node]));
  const referenced = new Set(
    nodes.flatMap((node) => (node.childIds || []).map((childId) => String(childId))),
  );
  const ordered = [];
  const visited = new Set();
  const visit = (node) => {
    const nodeId = String(node?.nodeId);
    if (!node || visited.has(nodeId)) {
      return;
    }
    visited.add(nodeId);
    ordered.push({
      ignored: node.ignored === true,
      name: unwrapAxValue(node.name),
      role: unwrapAxValue(node.role),
    });
    for (const childId of node.childIds || []) {
      visit(byId.get(String(childId)));
    }
  };

  for (const node of nodes.filter((candidate) => !referenced.has(String(candidate.nodeId)))) {
    visit(node);
  }
  for (const node of nodes) {
    visit(node);
  }
  return ordered;
}

function normalizeLegacyAxTree(root) {
  if (!root || typeof root !== 'object' || typeof root.role !== 'string') {
    return null;
  }
  const nodes = [];
  const visit = (node) => {
    if (!node || typeof node !== 'object') {
      return;
    }
    nodes.push({
      ignored: node.ignored === true,
      name: unwrapAxValue(node.name),
      role: unwrapAxValue(node.role),
    });
    for (const child of Array.isArray(node.children) ? node.children : []) {
      visit(child);
    }
  };
  visit(root);
  return nodes;
}

// Evaluate computed names from either the real flat CDP AXNode contract or a
// normalized legacy recursive snapshot. Unknown and empty evidence stays a
// candidate instead of becoming an authoritative pass.
export function ariaTreeNameEvaluation(accessibilityTree) {
  const source = accessibilityTree?.source === 'cdp' ? 'cdp' : 'legacy';
  const nodes = source === 'cdp'
    ? normalizeCdpAxNodes(accessibilityTree.nodes)
    : normalizeLegacyAxTree(accessibilityTree);
  if (!nodes || nodes.length === 0) {
    return { status: 'candidate', source, nodeCount: 0, namelessRoles: [] };
  }

  const namelessRoles = nodes
    .filter((node) => !node.ignored && VSR_INTERACTIVE_ROLES.has(node.role) && !node.name)
    .map((node) => node.role);
  return {
    status: namelessRoles.length > 0 ? 'fail' : 'pass',
    source,
    nodeCount: nodes.length,
    namelessRoles,
  };
}

// Given a virtual screen reader spokenPhraseLog, return the phrases that name an
// interactive control by role but carry no accessible name. Each phrase has the
// shape "role, name, ...extra"; a bare "role" with no name segment is a nameless
// control. Boundary phrases ("end of <role>, ...") are ignored.
export function findNamelessControls(phrases) {
  const nameless = [];
  for (const phrase of phrases || []) {
    if (typeof phrase !== 'string' || phrase.startsWith('end of ')) {
      continue;
    }
    const parts = phrase.split(', ');
    const role = parts[0].trim();
    const name = parts.slice(1).join(', ').trim();
    if (VSR_INTERACTIVE_ROLES.has(role) && name === '') {
      nameless.push(phrase);
    }
  }
  return nameless;
}

// Decide the WCAG 4.1.2 name/role status from a probe-virtual-sr snapshot. A
// snapshot that could not run is candidate (a lead, not a verdict); a snapshot
// with any nameless interactive control fails; otherwise it passes.
export function virtualSrNameRoleStatus(snapshot) {
  if (!snapshot || snapshot.ran !== true) {
    return 'candidate';
  }
  return (snapshot.namelessCount || 0) > 0 ? 'fail' : 'pass';
}

// Decide the WCAG 4.1.3 status-message status from a probe-live-region snapshot
// and the interaction state. A status message is expected only in error/open
// states; there, an absent region fails, a present-but-silent region only
// informs (partial), and a region that fired an update passes. In non-expecting
// states no status message is required, so the criterion is not failed.
export function liveRegionStatus(snapshot, state) {
  const expectsStatusMessage = /error|open/i.test(String(state || ''));
  if (!expectsStatusMessage) {
    return 'pass';
  }
  const hasRegion = Boolean(snapshot) && (snapshot.regionsNow || 0) > 0;
  if (!hasRegion) {
    return 'fail';
  }
  return snapshot.fired ? 'pass' : 'partial';
}

// Evaluate a normalized real-screen-reader capture against configured assertions.
// Missing expectations, unsupported platforms, unavailable AT, or adapter errors
// never produce a false pass; they return candidate unless the assertions are
// present and the run completed successfully.
export function realScreenReaderStatus(snapshot) {
  if (!snapshot || snapshot.ran !== true) {
    return 'candidate';
  }
  if (!Array.isArray(snapshot.assertions) || snapshot.assertions.length === 0) {
    return 'candidate';
  }
  const failed = snapshot.assertions.some((assertion) => assertion?.status === 'fail');
  if (failed) {
    return 'fail';
  }
  const pending = snapshot.assertions.some((assertion) => assertion?.status !== 'pass');
  return pending ? 'candidate' : 'pass';
}

// Emit a probe result document as pretty JSON on stdout.
export function emitProbeResult(payload) {
  console.log(JSON.stringify(payload, null, 2));
}
