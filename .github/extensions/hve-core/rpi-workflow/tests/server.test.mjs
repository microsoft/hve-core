// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { ModelError, recordActivity, takeFeedback, upsertDecision } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { clientInfoFrom, createCanvasServer, MAX_BODY, renderShell } from '../lib/server.mjs';
import { createStore } from '../lib/store.mjs';

let tmp;
before(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-server-'));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

async function setup(name, { stage = 'research', deliver } = {}) {
    const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
    const session = await store.create(buildScenario(stage));
    const sent = [];
    const server = createCanvasServer({
        store,
        getSessionId: () => session.id,
        deliver: deliver ?? (async (request) => {
            sent.push(request);
        }),
    });
    const url = new URL(await server.start());
    return { store, server, url, sent, session };
}

function request(url, { method = 'GET', pathname = '/', body, headers = {}, raw } = {}) {
    return new Promise((resolve, reject) => {
        const payload = raw ?? (body === undefined ? undefined : JSON.stringify(body));
        const req = http.request({ host: '127.0.0.1', port: url.port, method, path: pathname, headers: { ...(payload !== undefined ? { 'content-type': 'application/json' } : {}), ...headers } }, (res) => {
            let text = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                text += chunk;
            });
            res.on('end', () => {
                let json = null;
                try {
                    json = JSON.parse(text);
                } catch {
                    json = null;
                }
                resolve({ status: res.statusCode, headers: res.headers, text, json });
            });
        });
        req.on('error', reject);
        if (payload !== undefined) req.write(payload);
        req.end();
    });
}

describe('request guards', () => {
    it('rejects unexpected hosts, cross-site API calls, wrong types, and large bodies', async () => {
        const { server, url, store } = await setup('guards');
        assert.equal((await request(url, { pathname: '/api/state', headers: { host: 'evil.example:80' } })).status, 421);
        assert.equal((await request(url, { pathname: '/api/state', headers: { 'sec-fetch-site': 'cross-site' } })).status, 403);
        assert.equal((await request(url, { pathname: '/api/state', headers: { 'sec-fetch-site': 'same-origin' } })).status, 200);
        assert.equal((await request(url, { pathname: '/api/state' })).status, 200);
        const wrongType = await request(url, { method: 'POST', pathname: '/api/feedback', raw: '{}', headers: { 'content-type': 'text/plain' } });
        assert.equal(wrongType.status, 415);
        const big = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'x'.repeat(MAX_BODY) } });
        assert.equal(big.status, 413);
        const sectionSize = await request(url, { method: 'POST', pathname: '/api/section', body: { sectionId: 'research-summary', markdown: 'y'.repeat(30000), baseRevision: 1 } });
        assert.equal(sectionSize.status, 200);
        assert.equal((await request(url, { pathname: '/ui/secret.mjs' })).status, 404);
        assert.equal((await request(url, { method: 'DELETE', pathname: '/api/state' })).status, 405);
        assert.equal((await request(url, { pathname: '/api/nope' })).status, 404);
        const headers = (await request(url, { pathname: '/api/state' })).headers;
        assert.match(headers['content-security-policy'], /default-src 'none'/);
        assert.equal(headers['cross-origin-resource-policy'], 'same-origin');
        await server.stop();
        store.close();
    });
});

describe('page routes', () => {
    it('returns state and records user feedback with user-only transitions', async () => {
        const { server, url, store, session } = await setup('routes');
        const state = await request(url, { pathname: '/api/state' });
        assert.equal(state.json.session.id, session.id);
        assert.ok(state.json.view.needsYou.some((item) => item.id === 'D2'));
        const created = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both.' } });
        assert.equal(created.status, 200);
        assert.equal(created.json.item.state, 'queued');
        const sneaky = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: created.json.item.id, to: 'sent' } });
        assert.equal(sneaky.status, 409);
        const interpreted = state.json.session.feedback.find((item) => item.state === 'interpreted');
        const applied = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: interpreted.id, to: 'applied' } });
        assert.equal(applied.json.item.state, 'applied');
        const stored = await store.load(session.id);
        assert.equal(stored.scenario.userChanges, 2);
        await server.stop();
        store.close();
    });

    it('reports a section conflict with the current text', async () => {
        const { server, url, store, session } = await setup('conflict');
        const first = await request(url, { method: 'POST', pathname: '/api/section', body: { sectionId: 'finding-f3', markdown: 'Mine', baseRevision: 1 } });
        assert.equal(first.status, 200);
        const stale = await request(url, { method: 'POST', pathname: '/api/section', body: { sectionId: 'finding-f3', markdown: 'Stale', baseRevision: 1 } });
        assert.equal(stale.status, 409);
        assert.equal(stale.json.error.code, 'conflict');
        assert.equal(stale.json.error.section.markdown, 'Mine');
        const missing = await request(url, { method: 'POST', pathname: '/api/section', body: { sectionId: 'nope', markdown: 'x', baseRevision: 1 } });
        assert.equal(missing.status, 404);
        assert.ok((await store.load(session.id)).feedback.some((item) => item.kind === 'edit'));
        await server.stop();
        store.close();
    });

    it('sends exactly the previewed text, once, even after unrelated agent writes', async () => {
        const { server, url, store, sent, session } = await setup('delivery');
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const b = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'research-request', text: 'Second', target: { id: 'F4' } } });
        const ids = [a.json.item.id, b.json.item.id];
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids } });
        await store.update(session.id, (current) => recordActivity(current, { text: 'Edited the outbox' }, new Date().toISOString()), { by: 'agent' });
        const delivered = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids, mode: 'send', digest: preview.json.digest } });
        assert.equal(delivered.status, 200);
        assert.equal(sent.length, 1);
        assert.equal(sent[0].prompt, preview.json.prompt);
        assert.equal(sent[0].displayPrompt, preview.json.displayPrompt);
        assert.equal(sent[0].mode, 'send');
        const again = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids, mode: 'send', digest: preview.json.digest } });
        assert.equal(again.status, 409);
        assert.equal(sent.length, 1);

        const c = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Third', target: { id: 'D2' } } });
        const stalePreview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [c.json.item.id] } });
        await store.update(session.id, (current) => upsertDecision(current, { id: 'D2', title: 'Renamed conflict decision' }, new Date().toISOString()), { by: 'agent' });
        const stale = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [c.json.item.id], mode: 'attach', digest: stalePreview.json.digest } });
        assert.equal(stale.status, 409);
        assert.equal(stale.json.error.code, 'preview_stale');
        assert.match(stale.json.error.preview.prompt, /Renamed conflict decision/);
        assert.notEqual(stale.json.error.preview.digest, stalePreview.json.digest);
        assert.equal(sent.length, 1);
        const missing = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [c.json.item.id], mode: 'attach' } });
        assert.equal(missing.status, 409);
        await server.stop();
        store.close();
    });

    it('holds items while delivering and releases them when the host fails', async () => {
        let release;
        const gate = new Promise((resolve) => {
            release = resolve;
        });
        const slow = await setup('delivery-slow', { deliver: async () => {
            await gate;
            throw new ModelError('delivery_unavailable', 'No host.');
        } });
        const d = await request(slow.url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Fourth' } });
        const id = d.json.item.id;
        const preview = await request(slow.url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [id] } });
        const pending = request(slow.url, { method: 'POST', pathname: '/api/delivery', body: { ids: [id], mode: 'send', digest: preview.json.digest } });
        for (let i = 0; i < 100 && !(await slow.store.load(slow.session.id)).feedback.find((item) => item.id === id).deliveringSince; i += 1) {
            await new Promise((resolve) => setTimeout(resolve, 10));
        }
        const taken = await slow.store.update(slow.session.id, (current) => takeFeedback(current, new Date().toISOString()), { by: 'agent' });
        assert.ok(!taken.result.some((item) => item.id === id), 'a claimed item is not taken');
        release();
        const failed = await pending;
        assert.equal(failed.status, 503);
        const after = (await slow.store.load(slow.session.id)).feedback.find((item) => item.id === id);
        assert.equal(after.state, 'queued');
        assert.equal(after.deliveringSince, undefined);
        await slow.server.stop();
        slow.store.close();
    });

    it('saves preferences and validates client info', async () => {
        const { server, url, store } = await setup('prefs');
        const saved = await request(url, { method: 'POST', pathname: '/api/preferences', body: { theme: 'dark', contrast: 'more' } });
        assert.deepEqual(saved.json.preferences, { theme: 'dark', contrast: 'more' });
        assert.equal((await request(url, { method: 'POST', pathname: '/api/preferences', body: { theme: 'neon' } })).status, 400);
        await request(url, { method: 'POST', pathname: '/api/client-info', body: { scheme: 'dark', forcedColors: true, width: 1280, secret: 'ignored' } });
        assert.equal(server.clientInfo.scheme, 'dark');
        assert.equal(server.clientInfo.forcedColors, true);
        assert.equal('secret' in server.clientInfo, false);
        await server.stop();
        store.close();
    });
});

describe('event stream', () => {
    it('sends the revision on connect, after writes, and focus requests', async () => {
        const { server, url, store, session } = await setup('stream');
        const events = [];
        let resolveWait;
        let waitFor = null;
        const req = http.get({ host: '127.0.0.1', port: url.port, path: '/api/events' }, (res) => {
            assert.equal(res.headers['content-type'], 'text/event-stream; charset=utf-8');
            let buffer = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                buffer += chunk;
                let index;
                while ((index = buffer.indexOf('\n\n')) >= 0) {
                    const frame = buffer.slice(0, index);
                    buffer = buffer.slice(index + 2);
                    const event = /^event: (.+)$/m.exec(frame)?.[1];
                    const data = /^data: (.+)$/m.exec(frame)?.[1];
                    if (event) {
                        events.push({ event, data: JSON.parse(data) });
                        if (waitFor && waitFor(events.at(-1))) {
                            resolveWait();
                        }
                    }
                }
            });
        });
        const until = (predicate) => new Promise((resolve) => {
            if (events.some(predicate)) {
                resolve();
                return;
            }
            waitFor = predicate;
            resolveWait = resolve;
        });
        await until((e) => e.event === 'revision');
        assert.equal(events[0].data.revision, session.revision);
        await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Live' } });
        await until((e) => e.event === 'revision' && e.data.revision === session.revision + 1);
        server.focus({ phase: 'research', itemId: 'D2' });
        await until((e) => e.event === 'focus');
        assert.equal(events.find((e) => e.event === 'focus').data.itemId, 'D2');
        req.destroy();
        await server.stop();
        store.close();
    });
});

describe('helpers', () => {
    it('renders appearance into the shell with safe defaults', () => {
        const html = '<html lang="en" data-theme="__THEME__" data-contrast="__CONTRAST__">';
        assert.equal(renderShell(html, { theme: 'dark', contrast: 'more' }), '<html lang="en" data-theme="dark" data-contrast="more">');
        assert.equal(renderShell(html, { theme: '"><script>', contrast: 'x' }), '<html lang="en" data-theme="system" data-contrast="standard">');
    });

    it('keeps only known client info fields', () => {
        const info = clientInfoFrom({ scheme: 'purple', width: -5, height: 900, hostTokens: 'yes' });
        assert.equal(info.scheme, 'light');
        assert.equal(info.width, null);
        assert.equal(info.height, 900);
        assert.equal(info.hostTokens, false);
        assert.throws(() => clientInfoFrom([]), /object/);
    });
});
