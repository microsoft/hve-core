// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import { catalogDigest, materializeBoundCases, materializeExecutionJourneys, materializeMethodCells, resolveCaseCatalog } from '../../../scripts/runtime_a11y/runner/case-catalog.mjs';

const root = resolve(import.meta.dirname, '../../../../../../..');
const catalog = JSON.parse(readFileSync(resolve(root, '.github/skills/accessibility/accessibility/scripts/runtime_a11y/screen-reader-cases.json'), 'utf8'));
const binding = JSON.parse(readFileSync(resolve(root, 'docs/docusaurus/a11y-screen-reader.bindings.json'), 'utf8'));

function copy(value) {
  return structuredClone(value);
}

test('HVE binding resolves 16 site cases, five presentation cases and integrity', () => {
  const resolved = resolveCaseCatalog(catalog, binding);
  assert.equal(resolved.length, 22);
  assert.equal(resolved.filter((entry) => entry.caseId.startsWith('HVE-NVDA-')).length, 16);
  assert.equal(resolved.filter((entry) => entry.caseId.startsWith('PRES-NVDA-')).length, 5);
  assert.ok(resolved.some((entry) => entry.caseId === 'SR-INTEGRITY-001'));
  assert.equal(binding.catalogDigest, catalogDigest(catalog));
});

test('resolver rejects duplicate case IDs and digest drift', () => {
  const duplicated = copy(catalog);
  duplicated.cases.push(copy(duplicated.cases[0]));
  assert.throws(() => resolveCaseCatalog(duplicated, { ...binding, catalogDigest: catalogDigest(duplicated) }), /Duplicate case ID/);
  assert.throws(() => resolveCaseCatalog(catalog, { ...binding, catalogDigest: 'sha256:' + '0'.repeat(64) }), /digest mismatch/);
});

test('resolver rejects missing target closure and secret-bearing keys', () => {
  const missing = copy(binding);
  delete missing.targets['presentation.currentSlide'];
  assert.throws(() => resolveCaseCatalog(catalog, missing), /Unbound target/);
  const secret = copy(binding);
  secret.storageState = 'auth.json';
  assert.throws(() => resolveCaseCatalog(catalog, secret), /Forbidden secret-bearing binding key/);
});

test('materialized cases expose routes and targets but fail closed without recipes', () => {
  const cases = materializeBoundCases(catalog, binding);
  const presentation = cases.find((entry) => entry.caseId === 'PRES-NVDA-001');
  assert.equal(presentation.automationEligible, true);
  assert.equal(presentation.targets[0].route, '/hve-core/slides/{slug}.html');
  assert.ok(presentation.targets.some((target) => target.targetRef === 'presentation.currentSlide'));
  assert.equal(presentation.automationExclusionReason, null);
  // Every committed case is bound, so the exclusion path uses a fixture.
  const stripped = copy(binding);
  stripped.caseBindings['HVE-NVDA-003'] = { targetRefs: ['search.seeAll'] };
  const unbound = materializeBoundCases(catalog, stripped).find((entry) => entry.caseId === 'HVE-NVDA-003');
  assert.equal(unbound.automationEligible, false);
  assert.match(unbound.automationExclusionReason, /execution recipe/);
});

test('materialized execution journeys preserve case identity and explicit recipes', () => {
  const journeys = materializeExecutionJourneys(catalog, binding);
  assert.equal(journeys.length, 32);
  assert.deepEqual(journeys.map((entry) => entry.caseId), [
    'SR-INTEGRITY-001',
    'HVE-NVDA-001', 'HVE-NVDA-002', 'HVE-NVDA-002', 'HVE-NVDA-003', 'HVE-NVDA-004', 'HVE-NVDA-005', 'HVE-NVDA-006',
    'HVE-NVDA-007', 'HVE-NVDA-007', 'HVE-NVDA-008', 'HVE-NVDA-009', 'HVE-NVDA-010', 'HVE-NVDA-010',
    'HVE-NVDA-011', 'HVE-NVDA-012', 'HVE-NVDA-013',
    'HVE-NVDA-014', 'HVE-NVDA-015', 'HVE-NVDA-016', 'HVE-NVDA-016',
    'PRES-NVDA-001', 'PRES-NVDA-001', 'PRES-NVDA-002', 'PRES-NVDA-002', 'PRES-NVDA-002',
    'PRES-NVDA-003', 'PRES-NVDA-003', 'PRES-NVDA-003', 'PRES-NVDA-004', 'PRES-NVDA-005', 'PRES-NVDA-005',
  ]);
  assert.ok(journeys.every((entry) => entry.commands.length > 0 && entry.assertions.length > 0));
});

test('named HVE and presentation recipes satisfy their declared capabilities', () => {
  const { cells, uncovered } = materializeMethodCells(catalog, binding);
  const covered = new Set(cells.map((cell) => `${cell.caseId}|${cell.state}|${cell.capability}`));

  // Each recipe named by the closure work now decides its own capability.
  for (const key of [
    'HVE-NVDA-001|activated|keyboard',
    'HVE-NVDA-006|initial|table-navigation',
    'HVE-NVDA-008|suggestions|action-scoped-speech',
    'PRES-NVDA-001|current|presentation',
    'PRES-NVDA-003|dialog|presentation',
    'PRES-NVDA-003|reading|presentation',
    'PRES-NVDA-003|fullscreen|presentation',
  ]) {
    assert.ok(covered.has(key), `expected ${key} to be covered`);
  }
  assert.ok(uncovered.every((item) => item.reason === 'No execution recipe covers this state.'
    || item.reason === 'No execution recipe decides this case with representative screen-reader evidence.'));
});

test('a case declaring real NVDA reports a representative gap when only browser evidence decides it', () => {
  const result = methodCellFixture(
    { requiredCapabilities: ['real-nvda', 'structured-node-assertions'] },
    { assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'main' } }] },
  );

  // The tree assertion still decides its own capability, but it is browser
  // evidence and cannot satisfy the declared screen-reader obligation.
  assert.equal(result.cells.length, 1);
  assert.equal(result.cells[0].method, 'playwright');
  assert.equal(result.cells[0].probe, 'probe-browser-state');
  assert.deepEqual(result.uncovered, [{
    caseId: 'FIX-001',
    state: 'initial',
    capability: 'real-nvda',
    method: 'real-at',
    reason: 'No execution recipe decides this case with representative screen-reader evidence.',
  }]);
});

function methodCellFixture(caseOverrides, executionOverrides) {
  const fixtureCatalog = {
    schemaVersion: '1.0.0',
    catalogId: 'fixture-catalog',
    cases: [{
      caseId: 'FIX-001',
      outcomeClass: 'announcement',
      requiredCapabilities: ['real-nvda'],
      targetRefs: ['target.one'],
      states: ['initial'],
      privacyClass: 'ordinary',
      cadence: 'both',
      promotion: 'candidate-until-calibrated',
      ...caseOverrides,
    }],
  };
  const fixtureBinding = {
    schemaVersion: '1.0.0',
    bindingProfileId: 'fixture-binding',
    catalogId: 'fixture-catalog',
    catalogDigest: catalogDigest(fixtureCatalog),
    product: { name: 'fixture', surfaceProfiles: ['document', 'presentation'] },
    bundleDiscovery: { metadataSource: 'fixture.json', servedRouteTemplate: '/{slug}.html' },
    routes: { 'route.home': '/' },
    targets: { 'target.one': { routeRef: 'route.home', selector: 'main' } },
    caseBindings: {
      'FIX-001': {
        targetRefs: ['target.one'],
        executions: [{
          id: 'fixture-execution',
          route: '/',
          surfaceId: 'home',
          state: 'initial',
          trigger: { action: 'focus', target: 'main' },
          commands: [{ kind: 'pause', durationMs: 100 }],
          assertions: [{ type: 'contains', evidenceType: 'speech', value: 'anything' }],
          ...executionOverrides,
        }],
      },
    },
  };
  return materializeMethodCells(fixtureCatalog, fixtureBinding);
}

test('a fullscreen state is decided only by an assertion that tests its pressed state', () => {
  const caseOverrides = { requiredCapabilities: ['presentation'], states: ['fullscreen'] };
  const weak = methodCellFixture(caseOverrides, {
    state: 'fullscreen',
    assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'button', nameContains: 'screen' } }],
  });
  const decisive = methodCellFixture(caseOverrides, {
    state: 'fullscreen',
    assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'button', name: 'Exit full screen', pressed: true } }],
  });

  assert.equal(weak.cells.length, 0);
  assert.match(weak.uncovered[0].reason, /must expose its pressed state/);
  assert.equal(decisive.cells.length, 1);
  assert.equal(decisive.uncovered.length, 0);
});

test('method cells separate deterministic browser and representative-AT methods', () => {
  const realAt = methodCellFixture(
    { requiredCapabilities: ['real-nvda', 'action-scoped-speech'] },
    {
      captureMode: 'action',
      triggerAfterDriverStart: true,
      assertions: [{ type: 'contains', evidenceType: 'actionSpeech', value: 'results' }],
    },
  );
  const browser = methodCellFixture(
    { requiredCapabilities: ['structured-node-assertions'] },
    { assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'main' } }] },
  );

  assert.equal(realAt.cells.length, 1);
  assert.deepEqual(realAt.cells[0], {
    caseId: 'FIX-001',
    executionId: 'fixture-execution',
    state: 'initial',
    capability: 'action-scoped-speech',
    method: 'real-at',
    probe: 'probe-screen-reader',
    resultSource: 'action-speech',
    stateProof: 'required',
  });
  assert.equal(realAt.uncovered.length, 0);
  assert.equal(browser.cells[0].method, 'playwright');
  assert.equal(browser.cells[0].probe, 'probe-browser-state');
});

test('method cells reject a capability with no evidence rule', () => {
  assert.throws(
    () => methodCellFixture({ requiredCapabilities: ['real-nvda', 'invented-capability'] }, {}),
    /no evidence rule: invented-capability/,
  );
});

test('method cells report an uncovered state rather than promoting it', () => {
  const result = methodCellFixture(
    { requiredCapabilities: ['structured-node-assertions'], states: ['initial', 'missing'] },
    { assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'main' } }] },
  );

  assert.equal(result.cells.length, 1);
  assert.deepEqual(result.uncovered, [{
    caseId: 'FIX-001',
    state: 'missing',
    capability: 'structured-node-assertions',
    method: 'playwright',
    reason: 'No execution recipe covers this state.',
  }]);
});

const CAPABILITY_CASES = [
  {
    capability: 'action-scoped-speech',
    invalid: { assertions: [{ type: 'contains', evidenceType: 'actionSpeech', value: 'x' }] },
    valid: {
      captureMode: 'action',
      triggerAfterDriverStart: true,
      assertions: [{ type: 'contains', evidenceType: 'actionSpeech', value: 'x' }],
    },
    reason: /capture mode must be action/,
  },
  {
    capability: 'structured-node-assertions',
    invalid: { assertions: [{ type: 'contains', evidenceType: 'speech', value: 'x' }] },
    valid: { assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'main' } }] },
    reason: /accessibilityTree evidence/,
  },
  {
    capability: 'negative-assertions',
    invalid: { assertions: [{ type: 'contains', evidenceType: 'accessibilityTree', value: 'x' }] },
    valid: { assertions: [{ type: 'nodeAbsent', evidenceType: 'accessibilityTree', expected: { role: 'dialog' } }] },
    reason: /nodeAbsent or notContains/,
  },
  {
    capability: 'keyboard',
    invalid: { trigger: { action: 'click', target: 'main' } },
    valid: { trigger: { action: 'click', target: 'main' }, commands: [{ kind: 'key', value: 'Tab' }] },
    reason: /drive the surface with key or type or press/,
  },
  {
    capability: 'table-navigation',
    invalid: {
      commands: [{ kind: 'pause', durationMs: 100 }],
      assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'table' } }],
    },
    valid: {
      commands: [{ kind: 'perform', value: 'moveToNextColumn' }],
      assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'table' } }],
    },
    reason: /moveToNextColumn/,
  },
  {
    capability: 'heading-navigation',
    invalid: {
      commands: [{ kind: 'pause', durationMs: 100 }],
      assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'heading' } }],
    },
    valid: {
      commands: [{ kind: 'navigate', value: 'nextHeading' }],
      assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'heading' } }],
    },
    reason: /nextHeading/,
  },
  {
    capability: 'presentation',
    invalid: { assertions: [{ type: 'contains', evidenceType: 'speech', value: 'x' }] },
    valid: { assertions: [{ type: 'nodeMatches', evidenceType: 'accessibilityTree', expected: { role: 'group' } }] },
    reason: /accessibilityTree or actionSpeech evidence/,
  },
];

for (const entry of CAPABILITY_CASES) {
  test(`method cells enforce the ${entry.capability} evidence rule`, () => {
    const caseOverrides = { requiredCapabilities: [entry.capability] };
    const invalid = methodCellFixture(caseOverrides, entry.invalid);
    assert.equal(invalid.cells.length, 0);
    assert.equal(invalid.uncovered.length, 1);
    assert.match(invalid.uncovered[0].reason, entry.reason);

    const valid = methodCellFixture(caseOverrides, entry.valid);
    assert.equal(valid.uncovered.length, 0);
    assert.equal(valid.cells[0].capability, entry.capability);
  });
}

test('every site case is covered and remaining gaps belong to the presentation surface', () => {
  const { cells, uncovered } = materializeMethodCells(catalog, binding);

  assert.equal(uncovered.filter((item) => item.caseId.startsWith('HVE-NVDA-')).length, 0);
  assert.ok(uncovered.every((item) => item.caseId.startsWith('PRES-NVDA-')));
  // Representative evidence is speech-decided, so it stays a minority of cells.
  assert.ok(cells.some((cell) => cell.method === 'real-at'));
  assert.ok(cells.some((cell) => cell.method === 'playwright'));
});

test('HVE method cells report honest coverage instead of existence-only eligibility', () => {
  const result = materializeMethodCells(catalog, binding);

  assert.ok(result.cells.length > 0);
  assert.ok(result.uncovered.length > 0);
  // Every emitted cell names the execution that decides it, so a browser cell
  // cannot stand in for a representative-AT obligation.
  assert.ok(result.cells.every((cell) => cell.executionId && cell.method && cell.probe));
  assert.ok(result.uncovered.every((item) => item.reason.length > 0));
});