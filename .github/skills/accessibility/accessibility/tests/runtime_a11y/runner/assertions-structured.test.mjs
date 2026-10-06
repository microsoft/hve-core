// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { evaluateAssertion } from '../../../scripts/runtime_a11y/runner/assertions.mjs';

const tree = {
  role: 'WebArea',
  name: 'Deck',
  children: [
    { role: 'group', name: 'Welcome 1 of 4', roledescription: 'slide' },
    { role: 'button', name: 'Next slide', disabled: false },
  ],
};

test('nodeMatches binds properties and cardinality to one node', () => {
  const result = evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: 'group', nameContains: 'Welcome', roledescription: 'slide' },
    minCount: 1, maxCount: 1,
  }, { accessibilityTree: tree });
  assert.equal(result.status, 'pass');
});

test('nodeMatches does not combine properties from different nodes', () => {
  const result = evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: 'button', nameContains: 'Welcome' },
  }, { accessibilityTree: tree });
  assert.equal(result.status, 'fail');
});

test('nodeMatches treats omitted maxCount as unbounded', () => {
  const result = evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: ['group', 'button'] }, minCount: 1,
  }, { accessibilityTree: tree });
  assert.equal(result.status, 'pass');
});

test('nodeAbsent and notContains decide negative expectations', () => {
  assert.equal(evaluateAssertion({
    type: 'nodeAbsent', evidenceType: 'accessibilityTree',
    expected: { role: 'group', nameContains: 'Hidden slide' },
  }, { accessibilityTree: tree }).status, 'pass');
  assert.equal(evaluateAssertion({
    type: 'notContains', evidenceType: 'actionSpeech', value: 'expanded',
  }, { actionSpeech: ['Search edit'] }).status, 'pass');
});

test('nodeMatches unwraps Chrome CDP AX values and properties', () => {
  const cdpTree = {
    source: 'cdp',
    nodes: [
      {
        nodeId: '230',
        role: { type: 'role', value: 'main' },
        name: { type: 'computedString', value: 'HVE Core updates presentation' },
        properties: [
          { name: 'roledescription', value: { type: 'string', value: 'presentation' } },
        ],
      },
      {
        nodeId: '3',
        role: { type: 'role', value: 'button' },
        name: { type: 'computedString', value: 'Reading view' },
        properties: [
          { name: 'pressed', value: { type: 'tristate', value: 'true' } },
        ],
      },
      {
        nodeId: '1',
        role: { type: 'role', value: 'group' },
        name: { type: 'computedString', value: 'HVE Core updates, 1 of 26' },
        properties: [
          { name: 'roledescription', value: { type: 'string', value: 'slide' } },
        ],
      },
    ],
  };

  assert.equal(evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: 'main', nameContains: 'presentation', roledescription: 'presentation' },
  }, { accessibilityTree: cdpTree }).status, 'pass');
  assert.equal(evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: 'group', nameContains: '1 of 26', roledescription: 'slide' },
  }, { accessibilityTree: cdpTree }).status, 'pass');
  assert.equal(evaluateAssertion({
    type: 'nodeMatches', evidenceType: 'accessibilityTree',
    expected: { role: 'button', name: 'Reading view', pressed: true },
  }, { accessibilityTree: cdpTree }).status, 'pass');
});