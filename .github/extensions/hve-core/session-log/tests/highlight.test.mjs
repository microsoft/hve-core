// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { appendJson, appendTagged, looksLikeJson } from '../ui/highlight.mjs';
import { fakeDocument } from './helpers.mjs';

function highlight(text) {
    const root = fakeDocument.createElement('code');
    appendJson(root, text, fakeDocument);
    return root;
}

test('tokens get key, string, number, literal, and punctuation classes', () => {
    const root = highlight(JSON.stringify({ path: 'a.ts', count: 3, ok: true, none: null, list: [1.5e3] }, null, 2));
    const classes = new Set(root.elements().map((element) => element.className));
    for (const name of ['tok-key', 'tok-str', 'tok-num', 'tok-bool', 'tok-null', 'tok-punc']) {
        assert.ok(classes.has(name), name);
    }
    assert.equal(root.textContent, JSON.stringify({ path: 'a.ts', count: 3, ok: true, none: null, list: [1.5e3] }, null, 2));
});

test('hostile text stays text and only spans are created', () => {
    const root = highlight('{"<img src=x onerror=alert(1)>": "<script>alert(1)</script>"}');
    assert.deepEqual([...new Set(root.elements().map((element) => element.tagName))], ['SPAN']);
    assert.ok(root.textContent.includes('<script>'));
});

test('cut and unbalanced input highlights in linear time', () => {
    const started = performance.now();
    highlight(`"${'\\\\'.repeat(50000)}${'a'.repeat(50000)}`);
    highlight(`{"k": "${'x'.repeat(100000)}`);
    assert.ok(performance.now() - started < 200);
});

test('detects JSON-shaped text only', () => {
    assert.equal(looksLikeJson('  {"a": 1}'), true);
    assert.equal(looksLikeJson('[1, 2]'), true);
    assert.equal(looksLikeJson('npm test'), false);
    assert.equal(looksLikeJson(''), false);
});

test('system prompt tags are highlighted as text-only spans in linear time', () => {
    const root = fakeDocument.createElement('code');
    appendTagged(root, '<skills>\n<skill name="a">x < y</skill>\n</skills>', fakeDocument);
    assert.deepEqual(root.elements().map((element) => element.textContent), ['<skills>', '<skill name="a">', '</skill>', '</skills>']);
    assert.equal(root.textContent, '<skills>\n<skill name="a">x < y</skill>\n</skills>');
    const started = performance.now();
    appendTagged(fakeDocument.createElement('code'), `<a ${'x'.repeat(200000)}`, fakeDocument);
    assert.ok(performance.now() - started < 200);
});
