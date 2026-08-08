// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import test from 'node:test';

import { ensureScreenReaderStopped } from '../../../scripts/runtime_a11y/runner/_shared.mjs';
import {
  digestPhrases,
  retainScreenReaderTranscript,
  transcriptRetentionEnabled,
} from '../../../scripts/runtime_a11y/runner/transcript.mjs';

test('a screen reader the operator was already running is never terminated', async () => {
  const terminated = [];
  const result = await ensureScreenReaderStopped({
    timeoutMs: 0,
    preexistingProcessIds: [4242],
    readProcessIds: async () => [4242],
    terminate: async (ids) => {
      terminated.push(...ids);
      return true;
    },
  });

  assert.deepEqual(terminated, []);
  assert.equal(result.stopped, true);
  assert.equal(result.terminated, false);
});

test('a remnant this run started is force-terminated', async () => {
  const terminated = [];
  let calls = 0;
  const result = await ensureScreenReaderStopped({
    timeoutMs: 0,
    preexistingProcessIds: [4242],
    readProcessIds: async () => (calls++ === 0 ? [4242, 9001] : [4242]),
    terminate: async (ids) => {
      terminated.push(...ids);
      return true;
    },
  });

  assert.deepEqual(terminated, [9001]);
  assert.equal(result.stopped, true);
  assert.equal(result.terminated, true);
});

test('an owned process that survives termination reports unverified cleanup', async () => {
  const result = await ensureScreenReaderStopped({
    timeoutMs: 0,
    preexistingProcessIds: [],
    readProcessIds: async () => [9001],
    terminate: async () => false,
  });

  assert.equal(result.stopped, false);
  assert.equal(result.reason, 'screen-reader-still-running');
});

test('unreadable process state fails closed', async () => {
  const result = await ensureScreenReaderStopped({
    timeoutMs: 0,
    readProcessIds: async () => null,
    terminate: async () => true,
  });

  assert.equal(result.stopped, false);
  assert.equal(result.reason, 'screen-reader-state-unreadable');
});

test('transcripts are not retained unless explicitly enabled', () => {
  assert.equal(transcriptRetentionEnabled({}), false);

  const record = retainScreenReaderTranscript(['button, Clear search'], {}, {});

  assert.equal(record.retained, false);
  assert.equal(record.path, null);
  assert.equal(record.phraseCount, 1);
  assert.equal(record.sha256, digestPhrases(['button, Clear search']));
});
