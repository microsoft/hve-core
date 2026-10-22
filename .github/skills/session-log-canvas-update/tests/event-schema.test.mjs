// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { buildSnapshot, compareVersions, DEFAULT_INDEXER_PATH, diffShapes, extractShapes, findSchemas, loadHandled, main, renderMarkdown } from '../scripts/event-schema.mjs';

function schemaWith(events, extraDefs = {}) {
    const definitions = { ...extraDefs };
    const anyOf = [];
    for (const [type, { data, ephemeral, name }] of Object.entries(events)) {
        const eventName = name ?? `${type.replace(/[^a-z]/gi, '')}Event`;
        definitions[eventName] = {
            type: 'object',
            properties: {
                id: { type: 'string' },
                type: { type: 'string', const: type },
                ...(ephemeral === undefined ? {} : { ephemeral: ephemeral ? { type: 'boolean', const: true } : { type: 'boolean' } }),
                ...(data ? { data } : {}),
            },
            required: ['id', 'type', 'data'],
        };
        anyOf.push({ $ref: `#/definitions/${eventName}` });
    }
    definitions.SessionEvent = { anyOf };
    return { $ref: '#/definitions/SessionEvent', definitions };
}

const BASE = schemaWith({
    'tool.execution_start': {
        data: { $ref: '#/definitions/ToolStartData' },
    },
    'session.idle': { ephemeral: true, data: { type: 'object', properties: { reason: { type: 'string' } } } },
    abort: { data: { type: 'object', properties: { reason: { type: 'string' } }, required: ['reason'] } },
}, {
    ToolStartData: {
        type: 'object',
        properties: {
            toolCallId: { type: 'string' },
            arguments: { type: 'object', additionalProperties: { type: 'string' } },
            mode: { enum: ['a', 'b'] },
            parts: { type: 'array', items: { $ref: '#/definitions/Part' } },
            node: { $ref: '#/definitions/Node' },
        },
        required: ['toolCallId'],
    },
    Part: { type: 'object', properties: { text: { type: 'string' } } },
    Node: { type: 'object', properties: { child: { $ref: '#/definitions/Node' }, label: { anyOf: [{ type: 'string' }, { type: 'null' }] } } },
});

test('extracts data field paths with signatures, required flags, and ephemeral status', () => {
    const shapes = extractShapes(BASE);
    assert.deepEqual(Object.keys(shapes), ['abort', 'session.idle', 'tool.execution_start']);
    assert.equal(shapes['session.idle'].ephemeral, true);
    assert.equal(shapes.abort.ephemeral, false);
    const fields = shapes['tool.execution_start'].fields;
    assert.equal(fields.data, 'object required');
    assert.equal(fields['data.toolCallId'], 'string required');
    assert.equal(fields['data.arguments.*'], 'string');
    assert.equal(fields['data.mode'], 'enum("a"|"b")');
    assert.equal(fields['data.parts'], 'array<object>');
    assert.equal(fields['data.parts[].text'], 'string');
    assert.equal(fields['data.node.label'], 'null | string');
    assert.equal(fields['data.node.child'], 'ref(Node)');
    assert.equal(shapes.abort.fields['data.reason'], 'string required');
});

test('skips event types and keys that are not plain identifiers', () => {
    const shapes = extractShapes(schemaWith({
        'bad type!': { data: { type: 'object' } },
        ok: { data: { type: 'object', properties: { 'weird key': { type: 'string' }, fine: { type: 'string' } } } },
    }));
    assert.deepEqual(Object.keys(shapes), ['ok']);
    assert.deepEqual(Object.keys(shapes.ok.fields), ['data', 'data.fine']);
});

test('diffs added, removed, and changed types and fields and flags handled types', () => {
    const next = schemaWith({
        'tool.execution_start': { data: { type: 'object', properties: { toolCallId: { type: 'integer' }, title: { type: 'string' } } } },
        'session.idle': { ephemeral: false, data: { type: 'object', properties: { reason: { type: 'string' } } } },
        'model.debug': { data: { type: 'object' } },
        'session.fresh': { ephemeral: true, data: { type: 'object' } },
    });
    const baseline = buildSnapshot(BASE, { version: '1.0.0' }, new Date(2026, 0, 2));
    const current = buildSnapshot(next, { package: '@github/copilot', version: '1.1.0', platform: 'linux-x64' }, new Date(2026, 0, 3));
    assert.equal(baseline.source.captured, '2026-01-02');
    const diff = diffShapes(baseline, current, { types: new Set(['tool.execution_start', 'abort', 'gone.type']), prefixes: ['model.'] });
    assert.deepEqual(diff.added.map((item) => [item.type, item.ephemeral, item.handled]), [['model.debug', false, true], ['session.fresh', true, false]]);
    assert.deepEqual(diff.removed.map((item) => [item.type, item.handled]), [['abort', true]]);
    const tool = diff.changed.find((item) => item.type === 'tool.execution_start');
    assert.equal(tool.handled, true);
    assert.deepEqual(tool.fieldsAdded.map((field) => field.field), ['data.title']);
    assert.ok(tool.fieldsRemoved.some((field) => field.field === 'data.arguments.*'));
    assert.deepEqual(tool.fieldsChanged.find((field) => field.field === 'data.toolCallId'), { field: 'data.toolCallId', from: 'string required', to: 'integer' });
    const idle = diff.changed.find((item) => item.type === 'session.idle');
    assert.equal(idle.ephemeralBefore, true);
    assert.equal(idle.ephemeral, false);
    assert.deepEqual(diff.handledNotInSchema, ['abort', 'gone.type']);

    const report = renderMarkdown(diff);
    assert.match(report, /\* Current: @github\/copilot 1\.1\.0 \(linux-x64\), captured 2026-01-03/);
    assert.match(report, /### `tool\.execution_start`/);
    assert.match(report, /Changed `data\.toolCallId`: `string required` to `integer`/);
    assert.match(report, /\| `model\.debug` \| yes \| yes \| 1 \|/);
    assert.match(report, /\* `abort` \(handled by the canvas\)/);
    assert.match(report, /## Handled types missing from the current schema/);
});

test('orders versions numerically across release lines', () => {
    const sorted = ['1.0.101', '0.0.420', '1.0.96-2', '1.0.96', '0.0.406'].sort(compareVersions);
    assert.deepEqual(sorted, ['0.0.406', '0.0.420', '1.0.96', '1.0.96-2', '1.0.101']);
});

async function homeWith(t, versions) {
    const home = await fs.mkdtemp(path.join(os.tmpdir(), 'event-schema-'));
    t.after(() => fs.rm(home, { recursive: true, force: true }));
    for (const [platform, folder, version, schema] of versions) {
        const root = path.join(home, 'pkg', platform, folder);
        await fs.mkdir(path.join(root, 'schemas'), { recursive: true });
        await fs.writeFile(path.join(root, 'schemas', 'session-events.schema.json'), JSON.stringify(schema));
        if (version) {
            await fs.writeFile(path.join(root, 'package.json'), JSON.stringify({ name: '@github/copilot', version }));
        }
    }
    await fs.mkdir(path.join(home, 'pkg', 'linux-x64', 'empty'), { recursive: true });
    return home;
}

test('finds installed schemas with package versions, oldest first and unversioned folders before any release', async (t) => {
    const home = await homeWith(t, [['linux-x64', '1.0.5', '1.0.5', BASE], ['universal', 'folder-only', null, BASE], ['linux-x64', '0.9.0', '0.9.0', BASE]]);
    const found = await findSchemas(home);
    assert.deepEqual(found.map((item) => [item.version, item.platform, item.package]), [['folder-only', 'universal', null], ['0.9.0', 'linux-x64', '@github/copilot'], ['1.0.5', 'linux-x64', '@github/copilot']]);
    assert.deepEqual(await findSchemas(path.join(home, 'missing')), []);
});

test('the command line lists, snapshots, and diffs without reading session logs', async (t) => {
    const next = schemaWith({ 'tool.execution_start': { data: { type: 'object', properties: { toolCallId: { type: 'string' } } } } });
    const home = await homeWith(t, [['linux-x64', '2.0.0', '2.0.0', next], ['linux-x64', '1.0.0', '1.0.0', BASE]]);
    await fs.mkdir(path.join(home, 'session-state', 'abc'), { recursive: true });
    await fs.writeFile(path.join(home, 'session-state', 'abc', 'events.jsonl'), 'not read\n');
    const baselinePath = path.join(home, 'out', 'event-shapes.json');
    const run = async (argv) => {
        let stdout = '';
        let stderr = '';
        const code = await main(argv, { env: { COPILOT_HOME: home }, stdout: (text) => { stdout += text; }, stderr: (text) => { stderr += text; }, baselinePath, now: new Date(2026, 4, 6) });
        return { code, stdout, stderr };
    };

    const list = await run(['list', '--json']);
    assert.equal(list.code, 0);
    assert.deepEqual(JSON.parse(list.stdout).map((item) => item.version), ['1.0.0', '2.0.0']);

    const write = await run(['snapshot', '--schema', '1.0.0', '--write']);
    assert.equal(write.code, 0);
    const saved = JSON.parse(await fs.readFile(baselinePath, 'utf8'));
    assert.deepEqual(saved.source, { package: '@github/copilot', version: '1.0.0', platform: 'linux-x64', captured: '2026-05-06' });

    const diff = await run(['diff', '--json']);
    assert.equal(diff.code, 0, diff.stderr);
    const parsed = JSON.parse(diff.stdout);
    assert.equal(parsed.current.version, '2.0.0');
    assert.ok(parsed.changed.some((item) => item.type === 'tool.execution_start' && item.handled));
    assert.ok(!diff.stdout.includes('not read'));

    const markdown = await run(['diff', '--schema', path.join(home, 'pkg', 'linux-x64', '2.0.0', 'schemas', 'session-events.schema.json')]);
    assert.match(markdown.stdout, /Current: @github\/copilot 2\.0\.0/);

    assert.equal((await run(['diff', '--schema', '9.9.9'])).code, 1);
    assert.equal((await run(['snapshot', '--schema'])).code, 2);
    assert.equal((await run(['nope'])).code, 2);
    await fs.writeFile(baselinePath, JSON.stringify({ format: 99 }));
    assert.match((await run(['diff'])).stderr, /not an event-shapes document/);
});

test('the canvas indexer exports the handled types the diff flags', async () => {
    const handled = await loadHandled(DEFAULT_INDEXER_PATH);
    assert.ok(handled.types.has('tool.execution_start'));
    assert.ok(handled.types.has('session.compaction_complete'));
    assert.deepEqual([...handled.prefixes], ['model.']);
});

test('the committed baseline is a valid event-shapes document without descriptions or local paths', async () => {
    const text = await fs.readFile(new URL('../assets/event-shapes.json', import.meta.url), 'utf8');
    const baseline = JSON.parse(text);
    assert.equal(baseline.format, 1);
    assert.ok(Object.keys(baseline.types).length > 50);
    assert.equal(/"description"/.test(text), false);
    assert.equal(/(?<![\w.-])\/Users\/|(?<![\w.-])\/home\/[a-z]|[A-Z]:\\\\Users/.test(text), false);
    const handled = await loadHandled(DEFAULT_INDEXER_PATH);
    for (const type of handled.types) {
        assert.ok(Object.hasOwn(baseline.types, type), `baseline lacks handled type ${type}`);
    }
});
