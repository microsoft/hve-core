// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createInstanceRegistry } from '../lib/lifecycle.mjs';
import { openCanvas } from '../lib/open.mjs';
import { createSourceController } from '../lib/sources.mjs';
import { createStore } from '../lib/store.mjs';
import { CHILD_TASK, ROOT_TASK, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';
import { scratchFolder } from './helpers/scratch.mjs';

class FakeCanvasError extends Error {
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}
const makeError = (code, message) => new FakeCanvasError(code, message);
const asCanvasError = (error) => (error instanceof FakeCanvasError ? error : makeError('storage_failed', error.message));

const HOST = '3f2e1d0c-9b8a-4f7e-8d6c-5b4a39281706';
const FIRST = '0c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
const SECOND = '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b';

/** A page server stand-in: it listens once started and takes the calls the open path makes. */
function fakeServer() {
    let listening = false;
    const server = {
        url: 'http://127.0.0.1:1/?k=test',
        address: 'http://127.0.0.1:1/',
        streamClients: 0,
        get listening() {
            return listening;
        },
        async start() {
            listening = true;
            return server.url;
        },
        async stop() {
            listening = false;
        },
        rebind() {},
        notifyReload() {},
        focus() {
            return { delivered: false };
        },
    };
    return server;
}

let tmp;
let repo;
before(async () => {
    tmp = await scratchFolder('open');
    repo = await writeFixtureWorkspace(path.join(tmp, 'repo'));
});
after(() => fs.rm(tmp, { recursive: true, force: true }));

/** The open path's dependencies over a fresh store; every instance it opens is tracked so its memory is written before the test ends. */
function canvasOpener(name) {
    const store = createStore({ root: path.join(tmp, name) });
    const sources = createSourceController({ store, sessionRoot: () => path.join(tmp, name, 'session-state'), ownSessionId: () => HOST, intervalMs: 60000 });
    const registry = createInstanceRegistry({ makeError, createServer: () => fakeServer() });
    const deps = { registry, store, sources, makeError, asCanvasError };
    const records = new Set();
    const open = async (ctx) => {
        const result = await openCanvas({ sessionId: HOST, ...ctx }, deps);
        const record = registry.get(ctx.instanceId);
        if (record) records.add(record);
        return result;
    };
    const close = async (instanceId) => {
        const record = registry.get(instanceId);
        if (record) await sources.settled(record);
        await registry.close(instanceId);
    };
    const done = async () => {
        for (const record of records) await sources.settled(record);
        store.close();
    };
    return { store, registry, open, close, done };
}

describe('opening a canvas with the picker\'s sessions', () => {
    it('opens a canvas that shows no session for a list alone, names no input that did not apply, and keeps the list', async (t) => {
        const canvas = canvasOpener('list-alone');
        t.after(() => canvas.done());
        const result = await canvas.open({ instanceId: 'i1', input: { sessions: [FIRST] } });
        assert.match(result.status, /^Not connected to an RPI session/);
        assert.doesNotMatch(result.status, /input was not applied/);
        assert.deepEqual(canvas.registry.get('i1').sessions, [FIRST]);
        assert.equal(canvas.registry.get('i1').source.kind, 'none');
    });

    it('opens a task with a list, as the task alone opens it, and keeps the list on the instance', async (t) => {
        const canvas = canvasOpener('list-with-task');
        t.after(() => canvas.done());
        const opened = await canvas.open({ instanceId: 'i1', input: { sessions: [FIRST, FIRST.toUpperCase()], task: 'current' }, session: { workingDirectory: repo } });
        assert.match(opened.status, /^RPI session: /);
        assert.equal(canvas.registry.get('i1').source.taskId, ROOT_TASK);
        assert.deepEqual(canvas.registry.get('i1').sessions, [FIRST], 'the list is lowercased and without repeats');
    });

    it('applies a new list on an open of an instance that is already open, and keeps the view it shows', async (t) => {
        const canvas = canvasOpener('already-open');
        t.after(() => canvas.done());
        await canvas.open({ instanceId: 'i1', input: { task: 'current' }, session: { workingDirectory: repo } });
        const record = canvas.registry.get('i1');
        const kept = await canvas.open({ instanceId: 'i1', input: { sessions: [SECOND] } });
        assert.match(kept.status, /^RPI session: /, 'the open keeps the task shown');
        assert.equal(canvas.registry.get('i1'), record, 'the same instance answers');
        assert.equal(record.source.taskId, ROOT_TASK);
        assert.deepEqual(record.sessions, [SECOND]);
        await canvas.open({ instanceId: 'i1', input: { task: CHILD_TASK, sessions: [FIRST] }, session: { workingDirectory: repo } });
        assert.deepEqual(record.sessions, [FIRST], 'an open with another input applies the list too');
    });

    it('restores a remembered canvas for a list alone, without saying the input did not apply, and applies the list', async (t) => {
        const canvas = canvasOpener('reopen-alone');
        t.after(() => canvas.done());
        await canvas.open({ instanceId: 'i1', input: { task: 'current' }, session: { workingDirectory: repo } });
        await canvas.close('i1');
        const reopened = await canvas.open({ instanceId: 'i1', input: { sessions: [SECOND] }, session: { workingDirectory: repo } });
        assert.match(reopened.status, /reopened where this canvas was\)/);
        assert.doesNotMatch(reopened.status, /input was not applied/);
        assert.equal(canvas.registry.get('i1').source.taskId, ROOT_TASK, 'the canvas returns to the task it showed');
        assert.deepEqual(canvas.registry.get('i1').sessions, [SECOND]);
    });

    it('says the other input did not apply on a reopen that carries one, and still applies the list', async (t) => {
        const canvas = canvasOpener('reopen-other');
        t.after(() => canvas.done());
        await canvas.open({ instanceId: 'i1', input: { task: 'current' }, session: { workingDirectory: repo } });
        await canvas.close('i1');
        const reopened = await canvas.open({ instanceId: 'i1', input: { task: CHILD_TASK, sessions: [FIRST] }, session: { workingDirectory: repo } });
        assert.match(reopened.status, /its input was not applied/);
        assert.deepEqual(canvas.registry.get('i1').sessions, [FIRST]);
    });

    it('refuses an open whose list is not a list of session IDs, before the canvas changes', async (t) => {
        const canvas = canvasOpener('refused');
        t.after(() => canvas.done());
        await assert.rejects(canvas.open({ instanceId: 'i2', input: { sessions: ['not-a-session'] } }), { code: 'invalid_input' });
        assert.equal(canvas.registry.get('i2'), undefined);
    });
});
