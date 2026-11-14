// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { advanceCursor, retryDelay } from '../ui/sync.mjs';

test('at the tail the cursor counts delivered entries and keeps its version while pages remain', () => {
    const cursor = { total: 40, version: 7 };
    const firstPage = { total: 340, version: 9, next: 240, more: true };
    const drained = advanceCursor(cursor, firstPage, true);
    assert.deepEqual(drained, { total: 240, version: 7 });

    const lastPage = { total: 340, version: 9, next: 340, more: false };
    assert.deepEqual(advanceCursor(drained, lastPage, true), { total: 340, version: 9 });
});

test('away from the tail the cursor takes the advertised total and version', () => {
    assert.deepEqual(advanceCursor({ total: 40, version: 7 }, { total: 340, version: 9, next: 240, more: true }, false), { total: 340, version: 9 });
});

test('the cursor never moves backward and tolerates answers without a delivered count', () => {
    assert.deepEqual(advanceCursor({ total: 50, version: 7 }, { total: 45, version: 8, next: 45, more: false }, true), { total: 50, version: 8 });
    assert.deepEqual(advanceCursor({ total: 40, version: 7 }, { total: 42, version: 8 }, true), { total: 42, version: 8 });
});

test('retries back off from two seconds to at most thirty', () => {
    assert.deepEqual([1, 2, 3, 4, 5, 9].map(retryDelay), [2000, 4000, 8000, 16000, 30000, 30000]);
    assert.equal(retryDelay(0), 2000);
});
