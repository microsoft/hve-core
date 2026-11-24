// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { createInstanceRegistry } from '../lib/lifecycle.mjs';
import { createSessionLogServer } from '../lib/server.mjs';
import { OTHER_SESSION_ID, SESSION_ID, writeSession } from './fixtures.mjs';

const makeError = (code, message) => Object.assign(new Error(message), { code });

async function setup(t) {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-lifecycle-'));
    await writeSession(root, SESSION_ID);
    await writeSession(root, OTHER_SESSION_ID);
    const servers = [];
    const registry = createInstanceRegistry({
        makeError,
        createServer(record) {
            const server = createSessionLogServer({ root, rootSource: 'test', getCurrentSessionId: () => record.currentSessionId });
            servers.push(server);
            return server;
        },
    });
    t.after(async () => {
        await Promise.all(servers.map((server) => server.stop()));
        await fs.rm(root, { recursive: true, force: true });
    });
    return { registry, servers };
}

test('overlapping opens for one instance share a single server', async (t) => {
    const { registry, servers } = await setup(t);
    const [first, second] = await Promise.all([
        registry.open({ instanceId: 'a', currentSessionId: SESSION_ID }),
        registry.open({ instanceId: 'a', currentSessionId: SESSION_ID }),
    ]);
    assert.equal(first, second);
    assert.equal(servers.length, 1);
    assert.equal(servers.filter((server) => server.listening).length, 1);
});

test('a close during a pending open leaves no listening server', async (t) => {
    const { registry, servers } = await setup(t);
    const opening = registry.open({ instanceId: 'a', currentSessionId: SESSION_ID });
    const closing = registry.close('a');
    await assert.rejects(opening, { code: 'instance_closed' });
    await closing;
    assert.equal(registry.get('a'), undefined);
    assert.equal(servers.some((server) => server.listening), false);
});

test('a close after open stops the server and a reopen starts a new one', async (t) => {
    const { registry, servers } = await setup(t);
    const first = await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID });
    await registry.close('a');
    assert.equal(first.server.listening, false);
    const second = await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID });
    assert.notEqual(first, second);
    assert.equal(second.server.listening, true);
    assert.equal(servers.length, 2);
});

test('selection follows input, then the existing selection, then the current session', async (t) => {
    const { registry } = await setup(t);
    const record = await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID });
    assert.equal(record.server.selectedSessionId(), SESSION_ID);
    await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID, sessionId: OTHER_SESSION_ID });
    assert.equal(record.server.selectedSessionId(), OTHER_SESSION_ID);
    await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID });
    assert.equal(record.server.selectedSessionId(), OTHER_SESSION_ID);
    await registry.open({ instanceId: 'a', currentSessionId: SESSION_ID, sessionId: 'current' });
    assert.equal(record.server.selectedSessionId(), SESSION_ID);
    await assert.rejects(registry.open({ instanceId: 'a', currentSessionId: SESSION_ID, sessionId: 'nope' }), { code: 'invalid_input' });
});

test('a failed start reports server_unavailable and registers nothing', async () => {
    const registry = createInstanceRegistry({
        makeError,
        createServer: () => ({ listening: false, start: () => Promise.reject(new Error('EACCES /private/path')), stop: async () => {}, select: () => null }),
    });
    await assert.rejects(registry.open({ instanceId: 'a', currentSessionId: null }), (error) => error.code === 'server_unavailable' && !error.message.includes('/private'));
    assert.equal(registry.size, 0);
});

test('server start is single-flight and stop during start closes the listener', async (t) => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-start-'));
    t.after(() => fs.rm(root, { recursive: true, force: true }));
    const server = createSessionLogServer({ root, rootSource: 'test', getCurrentSessionId: () => null });
    const [a, b] = await Promise.all([server.start(), server.start()]);
    assert.equal(a, b);
    await server.stop();
    const starting = server.start();
    await server.stop();
    await assert.rejects(starting);
    assert.equal(server.listening, false);
});
