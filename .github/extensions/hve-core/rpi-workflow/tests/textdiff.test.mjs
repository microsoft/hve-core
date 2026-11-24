// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { lineDiff, unifiedDiff } from '../lib/textdiff.mjs';

describe('line diff', () => {
    it('keeps, removes, and adds lines with removals first', () => {
        assert.deepEqual(lineDiff('a\nb\nc', 'a\nx\nc'), [
            { type: ' ', text: 'a' },
            { type: '-', text: 'b' },
            { type: '+', text: 'x' },
            { type: ' ', text: 'c' },
        ]);
        assert.deepEqual(lineDiff('', 'new'), [{ type: '-', text: '' }, { type: '+', text: 'new' }]);
        assert.deepEqual(lineDiff('same', 'same'), [{ type: ' ', text: 'same' }]);
    });

    it('finds the longest common run inside a change', () => {
        const ops = lineDiff('1\n2\n3\n4\n5', '1\n3\n4\n6\n5');
        assert.deepEqual(ops.map((op) => `${op.type}${op.text}`), [' 1', '-2', ' 3', ' 4', '+6', ' 5']);
    });

    it('replaces every line when inputs are too large to compare', () => {
        const a = Array.from({ length: 1200 }, (_, i) => `a${i}`).join('\n');
        const b = Array.from({ length: 1200 }, (_, i) => `b${i}`).join('\n');
        const ops = lineDiff(a, b);
        assert.equal(ops.filter((op) => op.type === '-').length, 1200);
        assert.equal(ops.filter((op) => op.type === '+').length, 1200);
        assert.equal(ops.findIndex((op) => op.type === '+'), 1200);
    });
});

describe('unified diff', () => {
    it('writes hunks with two lines of context and counts', () => {
        const before = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'].join('\n');
        const after = ['one', 'TWO', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven'].join('\n');
        const diff = unifiedDiff(before, after);
        assert.equal(diff.added, 2);
        assert.equal(diff.removed, 1);
        assert.equal(diff.text, [
            '@@ -1,4 +1,4 @@',
            ' one',
            '-two',
            '+TWO',
            ' three',
            ' four',
            '@@ -9,2 +9,3 @@',
            ' nine',
            ' ten',
            '+eleven',
        ].join('\n'));
    });

    it('merges nearby changes, handles pure insertions, and is empty for equal text', () => {
        assert.equal(unifiedDiff('a\nb\nc\nd', 'a\nB\nc\nD').text, '@@ -1,4 +1,4 @@\n a\n-b\n+B\n c\n-d\n+D');
        assert.equal(unifiedDiff('a', 'z\na').text, '@@ -1,1 +1,2 @@\n+z\n a');
        assert.equal(unifiedDiff('a', '').text, '@@ -1,1 +1,1 @@\n-a\n+');
        assert.deepEqual(unifiedDiff('same\ntext', 'same\ntext'), { text: '', added: 0, removed: 0 });
    });
});
