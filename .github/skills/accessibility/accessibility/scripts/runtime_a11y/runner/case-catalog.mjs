// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

import { assertArtifactId } from './validation.mjs';

const FORBIDDEN_KEYS = new Set(['authorization', 'cookie', 'cookies', 'credential', 'credentials', 'header', 'headers', 'password', 'storageState', 'token']);
const PRESENTATION_TARGETS = new Set(['presentation.root', 'presentation.currentSlide', 'presentation.inactiveSlides']);

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function catalogDigest(catalog) {
  return `sha256:${createHash('sha256').update(canonical(catalog)).digest('hex')}`;
}

function rejectForbiddenKeys(value, path = '$') {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    if (FORBIDDEN_KEYS.has(key)) throw new Error(`Forbidden secret-bearing binding key: ${path}.${key}`);
    rejectForbiddenKeys(child, `${path}.${key}`);
  }
}

function uniqueIds(values, label) {
  const ids = new Set();
  for (const value of values) {
    const id = assertArtifactId(value, label);
    if (ids.has(id)) throw new Error(`Duplicate ${label}: ${id}`);
    ids.add(id);
  }
  return ids;
}

export function resolveCaseCatalog(catalog, binding) {
  if (catalog?.schemaVersion !== '1.0.0' || binding?.schemaVersion !== '1.0.0') {
    throw new Error('Unsupported screen-reader catalog or binding schema version.');
  }
  rejectForbiddenKeys(binding);
  const cases = Array.isArray(catalog.cases) ? catalog.cases : [];
  const caseIds = uniqueIds(cases.map((entry) => entry.caseId), 'case ID');
  if (binding.catalogId !== catalog.catalogId) throw new Error('Binding catalog ID mismatch.');
  if (binding.catalogDigest !== catalogDigest(catalog)) throw new Error('Binding catalog digest mismatch.');
  const routeIds = uniqueIds(Object.keys(binding.routes || {}), 'route ID');
  const targetIds = uniqueIds(Object.keys(binding.targets || {}), 'target ID');
  for (const [targetId, target] of Object.entries(binding.targets || {})) {
    if (!routeIds.has(target.routeRef)) throw new Error(`Target ${targetId} has unknown route: ${target.routeRef}`);
    if (typeof target.selector !== 'string' || !target.selector.trim()) throw new Error(`Target ${targetId} requires a selector.`);
  }
  const bindingIds = uniqueIds(Object.keys(binding.caseBindings || {}), 'case binding ID');
  for (const caseId of caseIds) if (!bindingIds.has(caseId)) throw new Error(`Missing case binding: ${caseId}`);
  for (const caseId of bindingIds) if (!caseIds.has(caseId)) throw new Error(`Unknown case binding: ${caseId}`);
  for (const entry of cases) {
    const selected = binding.caseBindings[entry.caseId];
    const selectedTargets = uniqueIds(selected.targetRefs || [], `${entry.caseId} target reference`);
    for (const targetRef of entry.targetRefs) {
      if (!targetIds.has(targetRef) || !selectedTargets.has(targetRef)) throw new Error(`Unbound target ${targetRef} for ${entry.caseId}`);
    }
    if (entry.requiredCapabilities.includes('presentation')) {
      for (const targetRef of PRESENTATION_TARGETS) {
        if (entry.caseId === 'PRES-NVDA-001' && !selectedTargets.has(targetRef)) throw new Error(`${entry.caseId} requires ${targetRef}`);
      }
      if (!binding.product?.surfaceProfiles?.includes('presentation') || !binding.bundleDiscovery) {
        throw new Error(`${entry.caseId} requires a presentation profile and bundle discovery.`);
      }
    }
  }
  return cases.map((entry) => ({ ...entry, binding: binding.caseBindings[entry.caseId] }));
}

export function materializeBoundCases(catalog, binding) {
  return resolveCaseCatalog(catalog, binding).map((entry) => {
    const targets = entry.binding.targetRefs.map((targetRef) => ({
      targetRef,
      ...binding.targets[targetRef],
      route: binding.routes[binding.targets[targetRef].routeRef],
    }));
    const executions = Array.isArray(entry.binding.executions) ? entry.binding.executions : [];
    return {
      caseId: entry.caseId,
      outcomeClass: entry.outcomeClass,
      requiredCapabilities: entry.requiredCapabilities,
      states: entry.binding.states || entry.states,
      cadence: entry.cadence,
      promotion: entry.promotion,
      targets,
      executions,
      automationEligible: executions.length > 0,
      automationExclusionReason: executions.length > 0
        ? null
        : 'A downstream execution recipe with explicit actions and assertions is required.',
    };
  });
}

export function materializeExecutionJourneys(catalog, binding) {
  return materializeBoundCases(catalog, binding).flatMap((entry) => entry.executions.map((execution) => ({
    ...execution,
    id: execution.id,
    caseId: entry.caseId,
    title: execution.title || entry.caseId,
    metadata: {
      caseId: entry.caseId,
      catalogId: catalog.catalogId,
      bindingProfileId: binding.bindingProfileId,
    },
  })));
}

// Declares the method that carries a capability rather than a rule of its own.
const METHOD_CAPABILITY = 'real-nvda';

// Closed rule map from a declared capability to the observable execution shape
// that can decide it. A capability absent from this map is rejected, so a new
// capability cannot silently pass with no evidence obligation.
const CAPABILITY_RULES = Object.freeze({
  'action-scoped-speech': {
    captureMode: 'action',
    triggerAfterDriverStart: true,
    evidenceTypes: ['actionSpeech'],
    resultSource: 'action-speech',
    stateProof: 'required',
  },
  'structured-node-assertions': {
    assertionTypes: ['nodeMatches', 'nodeAbsent'],
    evidenceTypes: ['accessibilityTree'],
    resultSource: 'accessibility-tree',
    stateProof: 'not-required',
  },
  'negative-assertions': {
    assertionTypes: ['nodeAbsent', 'notContains'],
    resultSource: 'accessibility-tree',
    stateProof: 'not-required',
  },
  keyboard: {
    commandKinds: ['key', 'type'],
    triggerActions: ['press', 'type'],
    resultSource: 'accessibility-tree',
    stateProof: 'required',
  },
  'table-navigation': {
    commandValues: ['moveToNextColumn', 'moveToPreviousColumn', 'moveToNextRow', 'moveToPreviousRow', 'nextTable', 'previousTable'],
    evidenceTypes: ['accessibilityTree'],
    resultSource: 'accessibility-tree',
    stateProof: 'not-required',
  },
  'heading-navigation': {
    commandValues: ['nextHeading', 'previousHeading'],
    evidenceTypes: ['accessibilityTree'],
    resultSource: 'accessibility-tree',
    stateProof: 'not-required',
  },
  presentation: {
    evidenceTypes: ['accessibilityTree', 'actionSpeech'],
    resultSource: 'accessibility-tree',
    stateProof: 'required',
  },
});

// A state whose whole point is an exposed control state is only decided by an
// assertion that tests that state, not by any assertion from the same family.
const STATE_PROPOSITIONS = Object.freeze({
  fullscreen: {
    describe: 'the fullscreen control must expose its pressed state',
    satisfied: (execution) => (execution.assertions || []).some(
      (assertion) => assertion?.expected && typeof assertion.expected.pressed === 'boolean',
    ),
  },
});

function assertionEvidenceTypes(execution) {
  return (execution.assertions || []).map((assertion) => assertion?.evidenceType || 'speech');
}

function ruleGap(rule, execution) {
  if (rule.captureMode && execution.captureMode !== rule.captureMode) {
    return `capture mode must be ${rule.captureMode}`;
  }
  if (rule.triggerAfterDriverStart && !execution.triggerAfterDriverStart) {
    return 'the trigger must run after the driver starts';
  }
  if (rule.evidenceTypes) {
    const present = assertionEvidenceTypes(execution);
    if (!rule.evidenceTypes.some((type) => present.includes(type))) {
      return `an assertion must use ${rule.evidenceTypes.join(' or ')} evidence`;
    }
  }
  if (rule.assertionTypes) {
    const types = (execution.assertions || []).map((assertion) => assertion?.type);
    if (!rule.assertionTypes.some((type) => types.includes(type))) {
      return `an assertion must use ${rule.assertionTypes.join(' or ')}`;
    }
  }
  if (rule.commandValues) {
    const values = (execution.commands || []).map((command) => command?.value);
    if (!rule.commandValues.some((value) => values.includes(value))) {
      return `a command must use ${rule.commandValues.join(', ')}`;
    }
  }
  if (rule.commandKinds || rule.triggerActions) {
    const kinds = (execution.commands || []).map((command) => command?.kind);
    const sequence = Array.isArray(execution.triggerSequence) ? execution.triggerSequence : [execution.trigger];
    const actions = sequence.map((step) => step?.action);
    const byCommand = (rule.commandKinds || []).some((kind) => kinds.includes(kind));
    const byTrigger = (rule.triggerActions || []).some((action) => actions.includes(action));
    if (!byCommand && !byTrigger) {
      const accepted = [...new Set([...(rule.commandKinds || []), ...(rule.triggerActions || [])])];
      return `the recipe must drive the surface with ${accepted.join(' or ')}`;
    }
  }
  return null;
}

// Speech is the only evidence a screen reader itself produces. Accessibility-tree
// assertions describe what the browser exposes, so they cannot stand in for it.
const SPEECH_EVIDENCE_TYPES = new Set(['speech', 'normalizedSpeech', 'actionSpeech', 'actionNormalizedSpeech']);

function resolveEvidenceMethod(rule, execution) {
  if (rule.resultSource === 'action-speech') return 'real-at';
  return assertionEvidenceTypes(execution).some((type) => SPEECH_EVIDENCE_TYPES.has(type))
    ? 'real-at'
    : 'playwright';
}

export function materializeMethodCells(catalog, binding) {
  const cells = [];
  const uncovered = [];
  for (const entry of materializeBoundCases(catalog, binding)) {
    const declaresRealAt = entry.requiredCapabilities.includes(METHOD_CAPABILITY);
    const declaredStates = entry.states || [];
    let representativeCells = 0;
    for (const capability of entry.requiredCapabilities) {
      if (capability === METHOD_CAPABILITY) continue;
      const rule = CAPABILITY_RULES[capability];
      if (!rule) {
        throw new Error(`Unknown case capability has no evidence rule: ${capability} (${entry.caseId})`);
      }
      for (const state of declaredStates) {
        const matches = entry.executions.filter((execution) => execution.state === state);
        if (matches.length === 0) {
          uncovered.push({ caseId: entry.caseId, state, capability, method: declaresRealAt ? 'real-at' : 'playwright', reason: 'No execution recipe covers this state.' });
          continue;
        }
        // Complementary recipes may share a state, so each one that satisfies the
        // capability gets its own cell and the state is covered when any does.
        const gaps = [];
        let covered = false;
        for (const execution of matches) {
          const gap = ruleGap(rule, execution);
          if (gap) {
            gaps.push(`${execution.id} does not satisfy ${capability}: ${gap}`);
            continue;
          }
          const proposition = STATE_PROPOSITIONS[state];
          if (proposition && !proposition.satisfied(execution)) {
            gaps.push(`${execution.id} does not decide the ${state} state: ${proposition.describe}`);
            continue;
          }
          covered = true;
          const method = resolveEvidenceMethod(rule, execution);
          if (method === 'real-at') representativeCells += 1;
          cells.push({
            caseId: entry.caseId,
            executionId: execution.id,
            state,
            capability,
            method,
            probe: method === 'real-at' ? 'probe-screen-reader' : 'probe-browser-state',
            resultSource: rule.resultSource,
            stateProof: rule.stateProof,
          });
        }
        if (!covered) {
          uncovered.push({ caseId: entry.caseId, state, capability, method: declaresRealAt ? 'real-at' : 'playwright', reason: `${gaps.join('; ')}.` });
        }
      }
    }
    if (declaresRealAt && representativeCells === 0) {
      uncovered.push({
        caseId: entry.caseId,
        state: declaredStates[0] || 'initial',
        capability: METHOD_CAPABILITY,
        method: 'real-at',
        reason: 'No execution recipe decides this case with representative screen-reader evidence.',
      });
    }
  }
  const seen = new Set();
  for (const cell of cells) {
    const key = `${cell.caseId}|${cell.executionId}|${cell.state}|${cell.capability}|${cell.method}`;
    if (seen.has(key)) throw new Error(`Duplicate method cell mapping: ${key}`);
    seen.add(key);
  }
  return {
    schemaVersion: '1.0.0',
    catalogId: catalog.catalogId,
    bindingProfileId: binding.bindingProfileId,
    cells,
    uncovered,
  };
}

export function loadCaseCatalog(catalogPath, bindingPath) {
  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const binding = JSON.parse(readFileSync(bindingPath, 'utf8'));
  return { catalog, binding, resolvedCases: resolveCaseCatalog(catalog, binding) };
}
