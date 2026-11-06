// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import test from 'node:test';

import { agentNameKey as libAgentNameKey } from '../lib/indexer.mjs';
import { agentNameKey, canvasSource, compactionTokens, contextSpec, detailSort, filterContextItems, prettyJson, schemaType, sectionChangeText, sortDetailItems } from '../ui/render.mjs';

const tools = [{ name: 'view', count: 3 }, { name: 'bash', count: 10 }, { name: 'grep', count: 3 }, { name: 'Edit2', count: 0 }, { name: 'edit10', count: 0 }];
const spec = { id: 'tools', nameOf: (item) => item.name, count: { of: (item) => item.count, most: 'Most calls', fewest: 'Fewest calls' } };

test('details sort by count, name, and source order without mutating items', () => {
    const before = JSON.stringify(tools);
    assert.deepEqual(sortDetailItems(tools, { key: 'count', dir: 'desc' }, spec).map((item) => item.name), ['bash', 'grep', 'view', 'Edit2', 'edit10']);
    assert.deepEqual(sortDetailItems(tools, { key: 'count', dir: 'asc' }, spec).map((item) => item.name), ['Edit2', 'edit10', 'grep', 'view', 'bash']);
    assert.deepEqual(sortDetailItems(tools, { key: 'name', dir: 'asc' }, spec).map((item) => item.name), ['bash', 'Edit2', 'edit10', 'grep', 'view']);
    assert.deepEqual(sortDetailItems(tools, { key: 'name', dir: 'desc' }, spec).map((item) => item.name), ['view', 'grep', 'edit10', 'Edit2', 'bash']);
    assert.deepEqual(sortDetailItems(tools, { key: 'order', dir: 'asc' }, spec).map((item) => item.name), tools.map((item) => item.name));
    assert.equal(sortDetailItems(tools, { key: 'count', dir: 'desc' }, { nameOf: spec.nameOf })[0].name, 'view');
    assert.equal(JSON.stringify(tools), before);
});

test('details sort defaults follow the group and ignore choices it cannot apply', () => {
    const state = { sort: new Map() };
    assert.deepEqual(detailSort(spec, state), { key: 'count', dir: 'desc' });
    assert.deepEqual(detailSort({ id: 'plugins' }, state), { key: 'name', dir: 'asc' });
    assert.deepEqual(detailSort({ id: 'sections', order: 'Prompt order', count: spec.count }, state), { key: 'order', dir: 'asc' });
    state.sort.set('plugins', { key: 'count', dir: 'asc' });
    assert.deepEqual(detailSort({ id: 'plugins' }, state), { key: 'name', dir: 'asc' });
    state.sort.set('tools', { key: 'name', dir: 'desc' });
    assert.deepEqual(detailSort(spec, state), { key: 'name', dir: 'desc' });
});

test('schema types read as short descriptions', () => {
    assert.equal(schemaType({ type: 'string' }), 'string');
    assert.equal(schemaType({ type: ['string', 'null'] }), 'string | null');
    assert.equal(schemaType({ type: 'array', items: { type: 'string' } }), 'array of string');
    assert.equal(schemaType({ enum: ['a', 'b'] }), 'one of "a", "b"');
    assert.equal(schemaType({ anyOf: [{ type: 'number' }, { type: 'null' }] }), 'number | null');
    assert.equal(schemaType({ const: 'x' }), 'exactly "x"');
    assert.equal(schemaType({ properties: {} }), 'object');
    assert.equal(schemaType(null), 'any');
    assert.ok(schemaType({ enum: ['x'.repeat(200)] }).length <= 120);
});

test('page and extension agent name matching agree', () => {
    for (const value of ['hve-core:rpi-plan-critic', 'RPI Plan Critic', 'explore', null, 'a:b:C d']) {
        assert.equal(agentNameKey(value), libAgentNameKey(value));
    }
});

test('inspector rows describe section changes and compaction token savings', () => {
    assert.equal(sectionChangeText(null), '');
    assert.equal(sectionChangeText({ added: 1, removed: 0, resized: 0 }), 'section 1 added');
    assert.equal(sectionChangeText({ added: 2, removed: 1, resized: 3 }), 'sections 2 added, 1 removed, 3 resized');
    assert.equal(sectionChangeText({ added: 0, removed: 0, resized: 0 }), 'same sections');
    assert.equal(compactionTokens({ before: 76000, after: 9000 }), '76k to 9k tokens (−88%)');
    assert.equal(compactionTokens({ before: 92000, after: null }), '92k tokens');
    assert.equal(compactionTokens({ before: null, after: null }), '');
});

test('pretty JSON indents complete objects and leaves other text alone', () => {
    assert.equal(prettyJson('{"a":1,"b":[true,null]}'), '{\n  "a": 1,\n  "b": [\n    true,\n    null\n  ]\n}');
    assert.equal(prettyJson('["x"]'), '[\n  "x"\n]');
    assert.equal(prettyJson('{"cut": '), '{"cut": ');
    assert.equal(prettyJson('"just a string"'), '"just a string"');
    assert.equal(prettyJson('plain text'), 'plain text');
    const big = `[${'1,'.repeat(140 * 1024)}1]`;
    assert.equal(prettyJson(big), big);
});

test('context filter matches names, keys, descriptions, counts, and badges', () => {
    const items = [
        { key: 'bash', name: 'bash', description: 'Runs commands', countText: '3 calls', badges: [] },
        { key: 'browser-navigate', name: 'browser-navigate', description: null, countText: 'Not called', badges: [{ text: 'MCP · browser' }] },
        { key: 'x', name: 'Explore', description: 'Read-only', countText: '1 run', badges: [{ text: 'Built-in' }] },
    ];
    assert.deepEqual(filterContextItems(items, 'BROWSER').map((item) => item.key), ['browser-navigate']);
    assert.deepEqual(filterContextItems(items, 'built-in').map((item) => item.key), ['x']);
    assert.deepEqual(filterContextItems(items, 'commands').map((item) => item.key), ['bash']);
    assert.equal(filterContextItems(items, '  ').length, 3);
});

test('context sections sort by uses first, with labels per section', () => {
    const spec = contextSpec({ id: 'tools' });
    assert.deepEqual([spec.count.most, spec.count.fewest], ['Most calls', 'Fewest calls']);
    const state = { sort: new Map() };
    assert.deepEqual(detailSort(spec, state), { key: 'count', dir: 'desc' });
    const items = [{ name: 'b', count: 1 }, { name: 'a', count: 1 }, { name: 'c', count: 5 }];
    assert.deepEqual(sortDetailItems(items, detailSort(spec, state), spec).map((item) => item.name), ['c', 'a', 'b']);
    assert.deepEqual(contextSpec({ id: 'unknown' }).count.most, 'Most used');
});

test('canvas definitions prefer this session\'s live definition, then its recorded capabilities', () => {
    const recorded = { capabilities: { text: JSON.stringify({ canvasId: 'board', description: 'Recorded', actions: [{ name: 'old' }] }) } };
    const liveItem = { canvasId: 'board', description: 'Live', actions: [{ name: 'new' }] };

    const otherSession = canvasSource({ live: { item: liveItem, scope: 'live-session' }, recorded });
    assert.equal(otherSession.useLive, false);
    assert.equal(otherSession.source.description, 'Recorded');

    const thisSession = canvasSource({ live: { item: liveItem, scope: 'this-session' }, recorded });
    assert.equal(thisSession.useLive, true);
    assert.equal(thisSession.source.description, 'Live');

    const fallback = canvasSource({ live: { item: liveItem, scope: 'live-session' }, recorded: {} });
    assert.equal(fallback.useLive, true);
    assert.equal(fallback.source.description, 'Live');

    const unreadable = canvasSource({ live: { item: null, scope: null }, recorded: { capabilities: { text: '{not json' } } });
    assert.deepEqual(unreadable, { live: null, captured: null, useLive: false, source: null });
});
