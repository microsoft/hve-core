// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createCalibrationCheckpoint,
  validateCalibrationCheckpoint,
} from '../../../scripts/runtime_a11y/runner/calibration-checkpoint.mjs';
import { createCalibrationFixture } from './calibration-fixtures.mjs';

function buildCheckpoint(overrides = {}) {
  return createCalibrationCheckpoint({
    journeyId: 'search-results',
    ordinal: 0,
    profileFingerprint: { locale: 'en-US', verbosity: 'default' },
    provenance: { driver: 'guidepup' },
    artifactHashes: { visual: 'a' },
    classification: 'pass',
    ...overrides,
  });
}

test('calibration fixtures cover the required patterns and expected evidence', () => {
  const patterns = ['checkbox', 'tabs', 'modal', 'menu-button', 'combobox'];
  for (const pattern of patterns) {
    const fixture = createCalibrationFixture(pattern);
    assert.ok(fixture, `${pattern} fixture should exist`);
    assert.ok(fixture.expected.speech, `${pattern} speech expectation should exist`);
    assert.ok(fixture.expected.browserState, `${pattern} browser-state expectation should exist`);
    assert.ok(fixture.expected.accessibilityTree, `${pattern} accessibility-tree expectation should exist`);
  }
});

test('checkpoints use canonical recursive JSON serialization and SHA-256 hashes', () => {
  const first = buildCheckpoint({ artifactHashes: { visual: { nested: ['alpha', 'beta'], values: { order: 1 } } } });
  const second = buildCheckpoint({ artifactHashes: { visual: { values: { order: 1 }, nested: ['alpha', 'beta'] } } });

  assert.equal(first.hash, second.hash);
  assert.match(first.hash, /^[a-f0-9]{64}$/);
  assert.equal(validateCalibrationCheckpoint(first), true);
});

test('validateCalibrationCheckpoint rejects a checkpoint whose hash field is absent', () => {
  const { hash: _hash, ...withoutHash } = buildCheckpoint();

  assert.equal(validateCalibrationCheckpoint(withoutHash), false);
});

test('validateCalibrationCheckpoint rejects a tampered payload that retains its original hash', () => {
  const checkpoint = buildCheckpoint();
  const tampered = { ...checkpoint, classification: 'assertionFailure' };

  assert.equal(validateCalibrationCheckpoint(tampered), false);
});

test('validateCalibrationCheckpoint rejects a checkpoint whose hash is not a SHA-256 digest', () => {
  const checkpoint = buildCheckpoint();

  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, hash: 'not-a-digest' }), false);
  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, hash: true }), false);
});

test('validateCalibrationCheckpoint rejects checkpoints missing required provenance fields', () => {
  const checkpoint = buildCheckpoint();

  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, provenance: null }), false);
  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, profileFingerprint: null }), false);
  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, artifactHashes: null }), false);
  assert.equal(validateCalibrationCheckpoint({ ...checkpoint, ordinal: -1 }), false);
  assert.equal(validateCalibrationCheckpoint(null), false);
});
