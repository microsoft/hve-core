// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';

function stableStringify(value) {
  if (value === null || value === undefined) {
    return 'null';
  }
  if (typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((entry) => stableStringify(entry)).join(',')}]`;
  }
  const entries = Object.entries(value)
    .filter(([, entryValue]) => entryValue !== undefined)
    .sort(([leftKey], [rightKey]) => leftKey.localeCompare(rightKey));
  return `{${entries.map(([key, entryValue]) => `${JSON.stringify(key)}:${stableStringify(entryValue)}`).join(',')}}`;
}

function hashCheckpoint(checkpoint) {
  return createHash('sha256').update(stableStringify(checkpoint)).digest('hex');
}

export function createCalibrationCheckpoint({ journeyId, ordinal, profileFingerprint, provenance, artifactHashes, classification }) {
  const checkpoint = {
    journeyId,
    ordinal,
    profileFingerprint,
    provenance,
    artifactHashes,
    classification,
  };
  return {
    ...checkpoint,
    hash: hashCheckpoint(checkpoint),
  };
}

// Rejects a checkpoint whose hash is absent, malformed, or does not match its
// payload. An absent hash is a rejection, never a skipped comparison.
export function validateCalibrationCheckpoint(checkpoint) {
  if (!checkpoint || typeof checkpoint !== 'object' || Array.isArray(checkpoint)) {
    return false;
  }
  if (!checkpoint.journeyId || typeof checkpoint.ordinal !== 'number' || !Number.isInteger(checkpoint.ordinal) || checkpoint.ordinal < 0) {
    return false;
  }
  if (!checkpoint.provenance || !checkpoint.profileFingerprint || !checkpoint.artifactHashes) {
    return false;
  }
  if (typeof checkpoint.hash !== 'string' || !/^[a-f0-9]{64}$/.test(checkpoint.hash)) {
    return false;
  }
  const { hash: _hash, ...payload } = checkpoint;
  return checkpoint.hash === hashCheckpoint(payload);
}
