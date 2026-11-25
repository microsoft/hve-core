// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { CONTENT_SECURITY_POLICY, createSessionLogServer } from '../lib/server.mjs';
import { AGENT_BODY, buildCompactionEvents, buildInventoryEvents, COMPACTION_REQUEST, NESTED_ID, OTHER_SESSION_ID, SESSION_ID, SUBAGENT_ID, writeSession } from './fixtures.mjs';
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
    assert.deepEqual(Object.keys(inventory).sort(), ['agent', 'currentAgent', 'inventoryVersion', 'isLive', 'model', 'recorded', 'sections', 'sessionId']);
    assert.deepEqual(Object.keys(inventory.recorded).sort(), ['agentKey', 'customAgent', 'systemPrompt']);
    assert.equal(inventory.sections.find((section) => section.id === 'skills').status, 'reconstructed');
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

test('uses live inventory only for the current session, and agent-level lists only for its main agent', async (t) => {
    let calls = 0;
    const { url } = await startServer(t, { liveInventory: async () => { calls += 1; return { agents: { status: 'live', items: [{ name: 'live-agent' }] } }; } });
    const current = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=root`)).json();
    assert.equal(current.isLive, true);
    assert.deepEqual(current.sections.map((section) => section.id), ['tools', 'skills', 'agents', 'subagents', 'canvases', 'instructions', 'mcp', 'hooks', 'plugins', 'extensions']);
    assert.equal(current.sections.find((section) => section.id === 'agents').items[0].name, 'live-agent');
    const other = (await request(url, `/api/inventory?session=${OTHER_SESSION_ID}&agent=root`)).json();
    assert.equal(other.isLive, false);
    assert.equal(other.sections.find((section) => section.id === 'agents').status, 'partial');
    const sub = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=${SUBAGENT_ID}`)).json();
    assert.equal(sub.isLive, false);
    assert.equal(sub.sections.find((section) => section.id === 'agents').status, 'live');
    assert.equal(sub.sections.find((section) => section.id === 'tools').status, 'partial');
    assert.equal(calls, 2);
});

test('inventory counts part returns only counts and rejects other parts', async (t) => {
    const { url } = await startServer(t);
    const counts = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=root&part=counts`)).json();
    assert.deepEqual(Object.keys(counts).sort(), ['agent', 'counts', 'inventoryVersion', 'sessionId']);
    const bash = counts.counts.tools.find((row) => row[0] === 'bash');
    assert.deepEqual(bash, ['bash', 1, 1, '1 call']);
    assert.equal((await request(url, `/api/inventory?session=${SESSION_ID}&agent=root&part=lists`)).status, 400);
});

test('inventory sections use live catalogs for the session that opened the canvas', async (t) => {
    const catalogKinds = [];
    const { url } = await startServer(t, { serverOptions: {
        liveDefinitions: {
            sessionId: () => SESSION_ID,
            lookup: async () => ({ status: 'not-found', item: null }),
            catalog: async (kind) => {
                catalogKinds.push(kind);
                if (kind === 'tool') {
                    return { status: 'live', items: [{ name: 'bash', description: 'Runs commands', mcpServerName: null, deferLoading: false }, { name: 'web', description: 'Fetches', mcpServerName: 'net', deferLoading: true }] };
                }
                if (kind === 'canvas') {
                    return { status: 'live', items: [{ canvasId: 'demo-board', displayName: 'Demo Board', description: 'Cards', extensionId: 'project:demo', extensionName: 'demo', actions: ['add'] }] };
                }
                return { status: 'live', items: [{ name: 'researcher', description: 'Finds docs', builtIn: false }] };
            },
        },
    } });
    const inventory = (await request(url, `/api/inventory?session=${SESSION_ID}&agent=root`)).json();
    assert.deepEqual(catalogKinds.sort(), ['canvas', 'subagent', 'tool']);
    const sections = Object.fromEntries(inventory.sections.map((section) => [section.id, section]));
    assert.equal(sections.tools.status, 'live');
    const web = sections.tools.items.find((row) => row.key === 'web');
    assert.deepEqual(web.badges.map((badge) => badge.text), ['MCP · net', 'On demand']);
    assert.ok(sections.tools.items.some((row) => row.key === 'view' && row.description === 'Called earlier; not offered now.'));
    assert.equal(sections.canvases.items[0].name, 'Demo Board');
    assert.deepEqual(sections.subagents.items.map((row) => [row.name, row.count]), [['researcher', 1], ['explore', 1]]);
    const other = (await request(url, `/api/inventory?session=${OTHER_SESSION_ID}&agent=root`)).json();
    assert.equal(other.sections.find((section) => section.id === 'tools').status === 'live', false);
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

test('definition route validates input and merges recorded and live definitions', async (t) => {
    const lookups = [];
    let liveSession = SESSION_ID;
    const liveDefinitions = {
        sessionId: () => liveSession,
        lookup: async (kind, name) => {
            lookups.push(`${kind}:${name}`);
            if (kind === 'agent') {
                return { status: 'live', item: { id: 'plugin:researcher', name: 'researcher', displayName: 'Researcher' }, listing: '- **researcher**: Finds docs' };
            }
            return { status: 'live', item: { name } };
        },
    };
    const { url } = await startServer(t, { serverOptions: { liveDefinitions } });
    const base = `/api/definition?session=${SESSION_ID}&agent=root`;
    assert.equal((await request(url, `${base}&kind=widget&name=bash`)).status, 400);
    assert.equal((await request(url, `${base}&kind=tool`)).status, 400);
    assert.equal((await request(url, `${base}&kind=tool&name=${'x'.repeat(401)}`)).status, 400);
    assert.equal((await request(url, `${base}&kind=tool&name=a%0Ab`)).status, 400);

    const tool = (await request(url, `${base}&kind=tool&name=bash`)).json();
    assert.equal(tool.live.scope, 'this-session');
    assert.equal(tool.recorded.calls.count, 1);

    const agent = (await request(url, `${base}&kind=agent&name=Researcher`)).json();
    assert.equal(agent.live.listing, '- **researcher**: Finds docs');
    assert.deepEqual(agent.recorded.runs.map((run) => run.key), [SUBAGENT_ID]);

    const skill = (await request(url, `${base}&kind=skill&name=demo-skill`)).json();
    assert.ok(skill.recorded.invocations.latest.content.includes('skill body'));

    const other = `/api/definition?session=${OTHER_SESSION_ID}&agent=root`;
    const fallback = (await request(url, `${other}&kind=tool&name=bash`)).json();
    assert.equal(fallback.live.scope, 'live-session');
    const otherSkill = (await request(url, `${other}&kind=skill&name=demo-skill`)).json();
    assert.equal(otherSkill.live.status, 'not-applicable');
    assert.equal(lookups.includes('skill:demo-skill'), true);
    assert.equal(lookups.filter((item) => item === 'skill:demo-skill').length, 1);

    liveSession = null;
    const detached = (await request(url, `${base}&kind=tool&name=bash`)).json();
    assert.deepEqual(detached.live, { status: 'unavailable', item: null, scope: null });
});

test('agent instructions route returns the shown agent\'s instructions or not found', async (t) => {
    const { url } = await startServer(t, { events: buildInventoryEvents() });
    const main = (await request(url, `/api/agent-instructions?session=${SESSION_ID}&agent=root`)).json();
    assert.equal(main.form, 'main');
    const sub = (await request(url, `/api/agent-instructions?session=${SESSION_ID}&agent=${SUBAGENT_ID}`)).json();
    assert.equal(sub.form, 'subagent');
    assert.equal(sub.text, AGENT_BODY);
    const { url: plainUrl } = await startServer(t);
    const none = await request(plainUrl, `/api/agent-instructions?session=${SESSION_ID}&agent=${NESTED_ID}`);
    assert.equal(none.status, 404);
    assert.equal((await request(url, `/api/agent-instructions?session=${SESSION_ID}&agent=not-an-agent`)).status, 400);
});

const pollUrl = (cursor, extra = '') => `/api/poll?session=${SESSION_ID}&agent=root&since=${cursor.since}&v=${cursor.v}&epoch=${cursor.epoch}&sv=1${extra}`;

test('a poll from before the session index was evicted resets instead of reporting unchanged', async (t) => {
    const { url, root } = await startServer(t);
    const page = (await request(url, `/api/entries?session=${SESSION_ID}`)).json();
    // The index cache keeps three sessions, so three others evict this one.
    const others = [OTHER_SESSION_ID, '77777777-8888-4999-8aaa-bbbbbbbbbbbb', '88888888-9999-4aaa-8bbb-cccccccccccc'];
    for (const id of others) {
        await writeSession(root, id);
        assert.equal((await request(url, `/api/summary?session=${id}`)).status, 200);
    }
    await fs.appendFile(path.join(root, SESSION_ID, 'events.jsonl'), `${JSON.stringify({ type: 'assistant.message', data: { content: 'After eviction' }, timestamp: '2026-01-15T11:00:00.000Z' })}\n`);
    const polled = (await request(url, pollUrl({ since: page.total, v: page.version, epoch: page.epoch }))).json();
    assert.equal(polled.reset, true);
    assert.notEqual(polled.epoch, page.epoch);
});

test('poll pages a large batch and the delivered cursor drains the rest', async (t) => {
    const { url, root } = await startServer(t);
    const page = (await request(url, `/api/entries?session=${SESSION_ID}`)).json();
    const lines = Array.from({ length: 300 }, (_, i) => JSON.stringify({ type: 'user.message', data: { content: `bulk ${i}` }, timestamp: '2026-01-15T12:00:00.000Z' }));
    await fs.appendFile(path.join(root, SESSION_ID, 'events.jsonl'), `${lines.join('\n')}\n`);
    const cursor = { since: page.total, v: page.version, epoch: page.epoch };
    const first = (await request(url, pollUrl(cursor))).json();
    assert.equal(first.added.length, 200);
    assert.equal(first.more, true);
    assert.equal(first.next, page.total + 200);
    assert.equal(first.total, page.total + 300);

    // Acknowledging the advertised total and version would skip the undelivered entries.
    const skipped = (await request(url, pollUrl({ ...cursor, since: first.total, v: first.version }))).json();
    assert.equal(skipped.unchanged, true);
    const second = (await request(url, pollUrl({ ...cursor, since: first.next }))).json();
    assert.equal(second.added.length, 100);
    assert.equal(second.added.at(-1).body, 'bulk 299');
    assert.equal(second.more, false);
    assert.equal(second.next, second.total);
});

test('responses keep recorded fields named parts and leave out index offsets', async (t) => {
    const args = { parts: [{ text: 'hello' }], required: ['parts'] };
    const events = [
        { type: 'session.start', data: { sessionId: SESSION_ID }, timestamp: '2026-01-15T10:00:00.000Z' },
        { type: 'assistant.turn_start', data: { turnId: '0' }, timestamp: '2026-01-15T10:00:01.000Z' },
        { type: 'hook.start', data: { hookInvocationId: 'h1', hookType: 'preToolUse', input: {} }, timestamp: '2026-01-15T10:00:02.000Z' },
        { type: 'hook.end', data: { hookInvocationId: 'h1', hookType: 'preToolUse', success: true }, timestamp: '2026-01-15T10:00:03.000Z' },
        { type: 'tool.execution_start', data: { toolCallId: 'call-parts', toolName: 'compose', arguments: args }, timestamp: '2026-01-15T10:00:04.000Z' },
        { type: 'tool.execution_complete', data: { toolCallId: 'call-parts', success: true, result: { content: 'ok' } }, timestamp: '2026-01-15T10:00:05.000Z' },
    ];
    const schema = { type: 'object', properties: { parts: { type: 'array' } }, required: ['parts'] };
    const liveDefinitions = { sessionId: () => SESSION_ID, lookup: async (kind, name) => ({ status: 'live', item: { name, parameters: schema } }) };
    const { url } = await startServer(t, { events, serverOptions: { liveDefinitions } });

    const page = (await request(url, `/api/entries?session=${SESSION_ID}`)).json();
    assert.ok(page.entries.length > 0);
    for (const entry of page.entries) {
        assert.equal(Object.hasOwn(entry, 'parts'), false, `${entry.kind} entry exposes offsets`);
        for (const run of entry.hookRuns ?? []) {
            assert.equal(Object.hasOwn(run, 'parts'), false, 'hook run exposes offsets');
        }
    }
    assert.ok(page.entries.some((entry) => entry.hookRuns?.length));
    const tool = page.entries.find((entry) => entry.kind === 'tool');
    const detail = (await request(url, `/api/detail?session=${SESSION_ID}&agent=root&seq=${tool.seq}`)).json();
    assert.equal(Object.hasOwn(detail.entry, 'parts'), false);
    assert.deepEqual(detail.events[0].data.arguments, args);
    const definition = (await request(url, `/api/definition?session=${SESSION_ID}&agent=root&kind=tool&name=compose`)).json();
    assert.deepEqual(definition.live.item.parameters, schema);
});

test('every poll answer reports whether the session is active', async (t) => {
    const { url, root } = await startServer(t);
    const page = (await request(url, `/api/entries?session=${SESSION_ID}`)).json();
    const cursor = { since: page.total, v: page.version, epoch: page.epoch };
    assert.equal((await request(url, pollUrl(cursor))).json().active, false);
    const lock = path.join(root, SESSION_ID, `inuse.${process.pid}.lock`);
    await fs.writeFile(lock, String(process.pid));
    const live = (await request(url, pollUrl(cursor))).json();
    assert.equal(live.unchanged, true);
    assert.equal(live.active, true);
    await fs.rm(lock);
    assert.equal((await request(url, pollUrl(cursor))).json().active, false);
    assert.equal((await request(url, pollUrl({ ...cursor, epoch: 1 }))).json().active, false);
});
