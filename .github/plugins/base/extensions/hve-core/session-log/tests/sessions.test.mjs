// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { SessionCatalog, toTitle } from '../lib/sessions.mjs';
import { OTHER_SESSION_ID, SESSION_ID, writeSession } from './fixtures.mjs';
import { symlinkOrSkip } from './helpers.mjs';

async function tempRoot(t) {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-catalog-'));
    t.after(() => fs.rm(root, { recursive: true, force: true }));
    return root;
}

const CLIENTS = [
    ['github/autopilot', 'GitHub Copilot app'],
    ['github/cli', 'Copilot CLI'],
    ['vscode', 'VS Code'],
    ['vscode-agent-host', 'VS Code (Copilot harness)'],
];

test('lists sessions with events, newest first, and skips empty or invalid folders', async (t) => {
    const root = await tempRoot(t);
    await writeSession(root, SESSION_ID, { yaml: 'name: Newer\nupdated_at: 2026-02-01T00:00:00Z\nclient_name: github/cli' });
    await writeSession(root, OTHER_SESSION_ID, { yaml: 'summary: Older\nupdated_at: 2026-01-01T00:00:00Z' });
    await fs.utimes(path.join(root, OTHER_SESSION_ID, 'events.jsonl'), new Date('2026-01-01'), new Date('2026-01-01'));
    await fs.utimes(path.join(root, SESSION_ID, 'events.jsonl'), new Date('2026-01-01'), new Date('2026-01-01'));
    await fs.mkdir(path.join(root, '99999999-2222-4333-8444-555555555555'));
    // Not a session ID; a name Windows also accepts, unlike the host's colon-separated drafts.
    await fs.mkdir(path.join(root, 'pending-session-draft-abc'));
    await fs.writeFile(path.join(root, `${SESSION_ID}.lock`), '');

    const catalog = new SessionCatalog(root, { isPidAlive: () => false });
    const sessions = await catalog.list();
    assert.deepEqual(sessions.map((session) => session.title), ['Newer', 'Older']);
    assert.equal(sessions[0].clientLabel, 'Copilot CLI');
    assert.equal(sessions[1].summary, 'Older');
});

test('maps every observed host client to a label', async (t) => {
    const root = await tempRoot(t);
    for (const [index, [client, label]] of CLIENTS.entries()) {
        const id = `${String(index).repeat(8)}-2222-4333-8444-555555555555`;
        await writeSession(root, id, { yaml: `name: Session ${index}\nclient_name: ${client}` });
        const record = await new SessionCatalog(root).get(id);
        assert.equal(record.client, client);
        assert.equal(record.clientLabel, label);
    }
});

test('falls back to the session ID when no name or summary is recorded', async (t) => {
    const root = await tempRoot(t);
    await writeSession(root, SESSION_ID, { yaml: 'id: x' });
    const record = await new SessionCatalog(root).get(SESSION_ID);
    assert.equal(record.title, SESSION_ID);
    assert.equal(toTitle('\n\n  first line  \nsecond'), 'first line');
    assert.equal(toTitle('x'.repeat(400)).length, 160);
});

test('marks a session active only when its lock PID is alive', async (t) => {
    const root = await tempRoot(t);
    await writeSession(root, SESSION_ID, { lockPid: 4242 });
    const alive = new SessionCatalog(root, { isPidAlive: (pid) => pid === 4242 });
    assert.equal((await alive.get(SESSION_ID)).active, true);
    const dead = new SessionCatalog(root, { isPidAlive: () => false });
    assert.equal((await dead.get(SESSION_ID)).active, false);
});

test('re-reads workspace.yaml only when it or the event log changes', async (t) => {
    const root = await tempRoot(t);
    await writeSession(root, SESSION_ID);
    const catalog = new SessionCatalog(root, { isPidAlive: () => false });
    await catalog.list();
    assert.equal(catalog.contentReads, 1);
    await catalog.list();
    assert.equal(catalog.contentReads, 1);
    await fs.appendFile(path.join(root, SESSION_ID, 'events.jsonl'), '{"type":"abort","data":{}}\n');
    await catalog.list();
    assert.equal(catalog.contentReads, 2);
});

test('returns an empty list when the root does not exist', async (t) => {
    const root = await tempRoot(t);
    assert.deepEqual(await new SessionCatalog(path.join(root, 'missing')).list(), []);
});

test('skips symlinked session folders and logs', async (t) => {
    const root = await tempRoot(t);
    const outside = await tempRoot(t);
    const outsideFolder = await writeSession(outside, SESSION_ID);
    if (!(await symlinkOrSkip(t, outsideFolder, path.join(root, SESSION_ID), 'dir'))) {
        return;
    }
    const folder = path.join(root, OTHER_SESSION_ID);
    await fs.mkdir(folder);
    await fs.symlink(path.join(outsideFolder, 'events.jsonl'), path.join(folder, 'events.jsonl'));
    const catalog = new SessionCatalog(root);
    assert.equal(await catalog.get(SESSION_ID), null);
    assert.equal(await catalog.get(OTHER_SESSION_ID), null);
    assert.deepEqual(await catalog.list(), []);
});

test('keeps unknown client names literal', async (t) => {
    const plainRoot = await tempRoot(t);
    await writeSession(plainRoot, SESSION_ID, { yaml: 'client_name: constructor\nname: Odd client' });
    const record = await new SessionCatalog(plainRoot).get(SESSION_ID);
    assert.equal(record.clientLabel, 'constructor');
});
