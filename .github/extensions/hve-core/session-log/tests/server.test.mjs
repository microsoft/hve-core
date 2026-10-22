// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { CONTENT_SECURITY_POLICY, createSessionLogServer } from '../lib/server.mjs';
import { buildCompactionEvents, COMPACTION_REQUEST, OTHER_SESSION_ID, SESSION_ID, SUBAGENT_ID, writeSession } from './fixtures.mjs';
import { request } from './helpers.mjs';

async function listFiles(dir) {
    const out = [];
    for (const entry of await fs.readdir(dir, { withFileTypes: true, recursive: true })) {
        if (entry.isFile()) {
            out.push(path.join(entry.parentPath ?? entry.path, entry.name));
        }
    }
    return out.sort();
}

async function startServer(t, options = {}) {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'session-log-server-'));
    await writeSession(root, SESSION_ID, options.events ? { events: options.events } : {});
    await writeSession(root, OTHER_SESSION_ID, { yaml: 'name: Other' });
    const filesBefore = await listFiles(root);
    let current = SESSION_ID;
    const server = createSessionLogServer({
        root,
        rootSource: 'test',
        getCurrentSessionId: () => current,
        liveInventory: options.liveInventory ?? null,
        ...options.serverOptions,
    });
    const url = await server.start();
    t.after(async () => {
        await server.stop();
        await fs.rm(root, { recursive: true, force: true });
    });
    return { root, url, server, filesBefore, setCurrent: (value) => { current = value; } };
}

test('serves the page shell with security headers and no CORS', async (t) => {
    const { url } = await startServer(t);
    const res = await request(url, '/');
    assert.equal(res.status, 200);
    assert.match(res.headers['content-type'], /text\/html/);
    assert.equal(res.headers['content-security-policy'], CONTENT_SECURITY_POLICY);
    assert.match(CONTENT_SECURITY_POLICY, /script-src 'self'/);
    assert.equal(res.headers['x-content-type-options'], 'nosniff');
    assert.equal(res.headers['referrer-policy'], 'no-referrer');
    assert.equal(res.headers['access-control-allow-origin'], undefined);
    const css = await request(url, '/ui/styles.css');
    assert.equal(css.status, 200);
    assert.match(css.headers['content-type'], /text\/css/);
});

test('rejects unexpected Host headers on every route', async (t) => {
    const { url } = await startServer(t);
    for (const route of ['/', '/ui/app.mjs', '/api/state']) {
        const res = await request(url, route, { headers: { Host: 'evil.example:80' } });
        assert.equal(res.status, 421, route);
    }
    const localhost = await request(url, '/api/state', { headers: { Host: `localhost:${new URL(url).port}` } });
    assert.equal(localhost.status, 200);
});

test('applies Fetch Metadata checks to API routes only', async (t) => {
    const { url } = await startServer(t);
    const crossApi = await request(url, '/api/state', { headers: { 'Sec-Fetch-Site': 'cross-site' } });
    assert.equal(crossApi.status, 403);
    const sameApi = await request(url, '/api/state', { headers: { 'Sec-Fetch-Site': 'same-origin' } });
    assert.equal(sameApi.status, 200);
    const crossShell = await request(url, '/', { headers: { 'Sec-Fetch-Site': 'cross-site', 'Sec-Fetch-Dest': 'iframe' } });
    assert.equal(crossShell.status, 200);
});

test('serves only allowlisted static files and rejects traversal', async (t) => {
    const { url } = await startServer(t);
    for (const route of ['/ui/../lib/server.mjs', '/lib/server.mjs', '/ui/%2e%2e/extension.mjs', '/README.md', '/tests/fixtures.mjs']) {
        const res = await request(url, route);
        assert.equal(res.status, 404, route);
    }
});

test('enforces methods and JSON content type', async (t) => {
    const { url } = await startServer(t);
    assert.equal((await request(url, '/api/state', { method: 'DELETE' })).status, 405);
    assert.equal((await request(url, '/', { method: 'POST' })).status, 405);
    assert.equal((await request(url, '/api/nope')).status, 404);
    const wrongType = await request(url, '/api/select', { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: '{}' });
    assert.equal(wrongType.status, 415);
    const tooLarge = await request(url, '/api/select', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sessionId: 'x'.repeat(5000) }) });
    assert.equal(tooLarge.status, 413);
});

test('validates query parameters with 400 errors', async (t) => {
    const { url } = await startServer(t);
    const cases = [
        '/api/summary?session=../../etc',
        '/api/summary',
        `/api/entries?session=${SESSION_ID}&limit=0`,
        `/api/entries?session=${SESSION_ID}&from=-1`,
        `/api/entries?session=${SESSION_ID}&agent=..%2F`,
        `/api/entries?session=${SESSION_ID}&anchorTool=${encodeURIComponent('a b')}`,
        `/api/outline?session=${SESSION_ID}&status=bogus`,
        `/api/detail?session=${SESSION_ID}&seq=abc`,
        `/api/field?session=${SESSION_ID}&seq=1&part=99&path=data.content&start=0`,
        `/api/field?session=${SESSION_ID}&seq=1&part=0&path=__proto__.x&start=0`,
        `/api/field?session=${SESSION_ID}&seq=1&part=0&start=0`,
        `/api/detail?session=${SESSION_ID}&seq=1&hook=-1`,
        `/api/detail?session=${SESSION_ID}&seq=1&hook=abc`,
    ];
    for (const route of cases) {
        const res = await request(url, route);
        assert.equal(res.status, 400, route);
        assert.equal(res.json().error.code, 'invalid_input', route);
    }
    const unknown = await request(url, '/api/summary?session=99999999-2222-4333-8444-555555555555');
    assert.equal(unknown.status, 404);
    assert.equal(unknown.json().error.code, 'session_not_found');
    const missingAgent = await request(url, `/api/entries?session=${SESSION_ID}&agent=eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee`);
    assert.equal(missingAgent.status, 404);
});

test('summary, entries, outline, detail, and field reads return session data', async (t) => {
    const { url } = await startServer(t);
    const summary = (await request(url, `/api/summary?session=${SESSION_ID}`)).json();
    assert.equal(summary.session.title, 'Review the demo README');
    assert.equal(summary.session.isCurrent, true);
    assert.equal(summary.session.start.copilotVersion, '9.9.9');

    const page = (await request(url, `/api/entries?session=${SESSION_ID}&limit=500`)).json();
    assert.ok(page.total > 10);
    assert.equal(page.entries.some((entry) => 'parts' in entry), false);
    assert.ok(page.entries.find((entry) => entry.kind === 'user').body.includes('review'));

    const anchored = (await request(url, `/api/entries?session=${SESSION_ID}&anchorTool=call-sub-view`)).json();
    assert.equal(anchored.agent, SUBAGENT_ID);
    assert.equal(anchored.entries[anchored.anchorIndex - anchored.from].toolCallId, 'call-sub-view');

    const outline = (await request(url, `/api/outline?session=${SESSION_ID}&status=failed`)).json();
    assert.deepEqual(outline.tools.map((tool) => tool.name), ['bash']);

    const system = page.entries.find((entry) => entry.kind === 'system');
    const detail = (await request(url, `/api/detail?session=${SESSION_ID}&seq=${system.seq}`)).json();
    assert.equal(detail.events[0].type, 'system.message');
    assert.equal('parts' in detail.entry, false);
    const field = (await request(url, `/api/field?session=${SESSION_ID}&seq=${system.seq}&part=0&path=data.content&start=10`)).json();
    assert.equal(field.start, 10);
    assert.equal(field.next, null);

    const inventory = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=root`)).json();
    assert.equal(inventory.isLive, false);
    assert.equal(inventory.skills.status, 'reconstructed');
});

test('poll reports unchanged, added, updated, and reset states', async (t) => {
    const { url, root } = await startServer(t);
    const page = (await request(url, `/api/entries?session=${SESSION_ID}`)).json();
    const base = `/api/poll?session=${SESSION_ID}&agent=root&since=${page.total}&v=${page.version}&epoch=${page.epoch}&sv=1`;
    const unchanged = (await request(url, base)).json();
    assert.equal(unchanged.unchanged, true);
    assert.equal(unchanged.state, null);

    await fs.appendFile(path.join(root, SESSION_ID, 'events.jsonl'), [
        JSON.stringify({ type: 'tool.execution_complete', data: { toolCallId: 'call-running', success: true, result: { content: 'ok' } }, timestamp: '2026-01-15T11:00:00.000Z' }),
        JSON.stringify({ type: 'assistant.message', data: { content: 'New message' }, timestamp: '2026-01-15T11:00:01.000Z' }),
    ].join('\n') + '\n');
    const changed = (await request(url, base)).json();
    assert.equal(changed.added.length, 1);
    assert.equal(changed.added[0].body, 'New message');
    assert.equal(changed.updated[0].status, 'succeeded');
    assert.equal(changed.updated[0].preview.output, 'ok');

    const reset = (await request(url, `/api/poll?session=${SESSION_ID}&agent=root&since=0&v=0&epoch=99&sv=1`)).json();
    assert.equal(reset.reset, true);
    const noSession = (await request(url, '/api/poll?sv=0')).json();
    assert.equal(noSession.state.selectedSessionId, SESSION_ID);
});

test('selection follows the current session until a session is chosen', async (t) => {
    const { url, server, setCurrent } = await startServer(t);
    let state = (await request(url, '/api/state')).json();
    assert.equal(state.followsCurrent, true);
    assert.equal(state.selectedSessionId, SESSION_ID);

    const post = (body) => request(url, '/api/select', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    state = (await post({ sessionId: OTHER_SESSION_ID })).json();
    assert.equal(state.selectedSessionId, OTHER_SESSION_ID);
    assert.equal(state.followsCurrent, false);
    setCurrent('22222222-2222-4333-8444-555555555555');
    assert.equal(server.selectedSessionId(), OTHER_SESSION_ID);

    state = (await post({ sessionId: 'current' })).json();
    assert.equal(state.selectedSessionId, '22222222-2222-4333-8444-555555555555');
    assert.equal((await post({ sessionId: 'not-a-session' })).status, 400);
    assert.equal(server.select(undefined), '22222222-2222-4333-8444-555555555555');
});

test('uses live inventory only for the current session root agent', async (t) => {
    let calls = 0;
    const { url } = await startServer(t, { liveInventory: async () => { calls += 1; return { agents: { status: 'live', items: [{ name: 'live-agent' }] } }; } });
    const current = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=root`)).json();
    assert.equal(current.isLive, true);
    assert.equal(current.agents.items[0].name, 'live-agent');
    const other = (await request(url, `/api/inventory?session=${OTHER_SESSION_ID}&agent=root`)).json();
    assert.equal(other.isLive, false);
    const sub = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=${SUBAGENT_ID}`)).json();
    assert.equal(sub.isLive, false);
    assert.equal(calls, 1);
});

test('reading session data creates no files under the session root', async (t) => {
    const { url, root, filesBefore } = await startServer(t);
    for (const route of ['/api/sessions', `/api/summary?session=${SESSION_ID}`, `/api/entries?session=${SESSION_ID}`, `/api/detail?session=${SESSION_ID}&seq=5`, `/api/poll?session=${SESSION_ID}&since=0&v=0&sv=0`]) {
        await request(url, route);
    }
    assert.deepEqual(await listFiles(root), filesBefore);
});

test('stops listening and can restart', async (t) => {
    const { server } = await startServer(t);
    assert.equal(server.listening, true);
    await server.stop();
    assert.equal(server.listening, false);
    assert.equal(server.url, null);
    const url = await server.start();
    assert.match(url, /^http:\/\/127\.0\.0\.1:\d+\/$/);
});

test('system prompt route returns sections with offsets, skills, and instructions', async (t) => {
    const { url } = await startServer(t);
    const prompt = (await request(url, `/api/system-prompt?session=${SESSION_ID}&agent=root`)).json();
    assert.ok(prompt.sections.length > 0);
    const tagged = prompt.sections.filter((section) => Number.isInteger(section.start));
    const field = (await request(url, `/api/field?session=${SESSION_ID}&seq=${prompt.seq}&part=0&path=data.content&start=${tagged[0].start}`)).json();
    assert.ok(field.text.startsWith(`<${tagged[0].name}>`));
    assert.ok(prompt.skills.some((skill) => skill.name === 'demo-skill'));
    assert.ok(prompt.instructions.length > 0);
    const missing = await request(url, `/api/system-prompt?session=${SESSION_ID}&agent=eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee`);
    assert.equal(missing.status, 404);
});

test('system prompt versions and compaction text are served on request', async (t) => {
    const { url } = await startServer(t, { events: buildCompactionEvents() });
    const summary = (await request(url, `/api/summary?session=${SESSION_ID}`)).json();
    const root = summary.agents.find((agent) => agent.key === 'root');
    assert.equal(root.systemPromptCount, 3);
    const first = (await request(url, `/api/system-prompt?session=${SESSION_ID}&agent=root&seq=${root.systemPromptVersions[0].seq}`)).json();
    assert.equal(first.version, 1);
    assert.equal((await request(url, `/api/system-prompt?session=${SESSION_ID}&agent=root&seq=0`)).status, 404);
    assert.equal((await request(url, `/api/system-prompt?session=${SESSION_ID}&agent=root&seq=x`)).status, 400);

    const outline = (await request(url, `/api/outline?session=${SESSION_ID}&agent=root`)).json();
    const late = outline.tools.filter((row) => row.kind === 'compaction').at(-1);
    const text = (await request(url, `/api/compaction?session=${SESSION_ID}&agent=root&seq=${late.seq}&which=request`)).json();
    assert.equal(text.text, COMPACTION_REQUEST);
    assert.equal(text.next, null);
    const earliest = outline.tools.find((row) => row.kind === 'compaction');
    assert.equal((await request(url, `/api/compaction?session=${SESSION_ID}&agent=root&seq=${earliest.seq}&which=request`)).status, 404);
    assert.equal((await request(url, `/api/compaction?session=${SESSION_ID}&agent=root&seq=${late.seq}&which=raw`)).status, 400);
    assert.equal((await request(url, `/api/compaction?session=${SESSION_ID}&agent=root&which=summary`)).status, 400);
});
