// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, afterEach, before, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { agentEditSection, CLAIM_STALE_MS, claimDelivery, createFeedback, markDelivered, markDeliveryUncertain, ModelError, recordActivity, recordInterpretation, takeFeedback, upsertDecision } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { clientInfoFrom, createCanvasServer as newServer, MAX_BODY, renderShell } from '../lib/server.mjs';
import { createInboxRunner } from '../lib/inbox.mjs';
import { CANVAS_ID, createPanelOpener, panelInstanceId } from '../lib/panels.mjs';
import { createSourceController } from '../lib/sources.mjs';
import { storeIdFor } from '../lib/source/workspace.mjs';
import { createStore } from '../lib/store.mjs';
import { stopTracked, track } from './helpers/cleanup.mjs';
import { hostCanvas } from './helpers/host-canvas.mjs';
import { scratchFolder } from './helpers/scratch.mjs';
import { CHILD_TASK, childSession, FIXTURE_ROOT, PATHS, ROOT_TASK, rootSession, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

/** A canvas server that stops after the test even when an assertion fails. */
const createCanvasServer = (deps) => track(newServer(deps));

afterEach(stopTracked);

let tmp;
before(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-server-'));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

async function setup(name, { stage = 'research', deliver, pickups } = {}) {
    const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
    const session = await store.create(buildScenario(stage));
    const sent = [];
    const server = createCanvasServer({
        store,
        getSessionId: () => session.id,
        getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
        deliver: deliver ?? (async (request) => {
            sent.push(request);
        }),
        pickups,
    });
    const url = new URL(await server.start());
    return { store, server, url, sent, session };
}

/** Sends a request as the page would, with the canvas key from the page address unless `key` is false. */
function request(url, { method = 'GET', pathname = '/', body, headers = {}, raw, key = true } = {}) {
    return new Promise((resolve, reject) => {
        const payload = raw ?? (body === undefined ? undefined : JSON.stringify(body));
        const auth = key && pathname.startsWith('/api/') && url.searchParams.get('k') ? { 'x-rw-key': url.searchParams.get('k') } : {};
        const req = http.request({ host: '127.0.0.1', port: url.port, method, path: pathname, headers: { ...auth, ...(payload !== undefined ? { 'content-type': 'application/json' } : {}), ...headers } }, (res) => {
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
        const sectionSize = await request(url, { method: 'POST', pathname: '/api/suggestion', body: { sectionId: 'research-summary', markdown: 'y'.repeat(30000), baseRevision: 1 } });
        assert.equal(sectionSize.status, 200);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/section', body: {} })).status, 404, 'edits are suggestions now');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/checklist', body: { phase: 'research', itemId: 'R1', verdict: 'ok' } })).status, 404, 'the review checklist is gone');
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
        assert.deepEqual(state.json.canvas, { handle: '3WF0', instanceId: 'rpi-workflow-demo' });
        assert.ok(state.json.view.needsYou.some((item) => item.id === 'D2'));
        const created = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both.' } });
        assert.equal(created.status, 200);
        assert.equal(created.json.item.state, 'queued');
        const sneaky = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: created.json.item.id, to: 'sent' } });
        assert.equal(sneaky.status, 409);
        const interpreted = state.json.session.feedback.find((item) => item.state === 'interpreted');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: interpreted.id, to: 'applied' } })).status, 409, 'read-backs need no confirmation');
        const corrected = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: interpreted.id, to: 'corrected', correction: 'I meant the other one.' } });
        assert.equal(corrected.json.item.kind, 'correction');
        assert.equal(corrected.json.item.correctionOf, interpreted.id);
        const done = createFeedback(await store.load(session.id), { kind: 'comment', text: 'Applied already' }, new Date().toISOString());
        await store.update(session.id, () => recordInterpretation(takeFeedback(done.session, new Date().toISOString()).session, { feedbackId: done.result.id, text: 'Done.' }, new Date().toISOString()), { by: 'agent' });
        const fromHistory = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: done.result.id, to: 'corrected', correction: 'Not quite.' } });
        assert.equal(fromHistory.json.item.correctionOf, done.result.id, 'an item in the history can still be corrected');
        const stored = await store.load(session.id);
        assert.equal(stored.scenario.userChanges, 3);
        await server.stop();
        store.close();
    });

    it('records a suggestion, withdraws it, and reports a conflict with the current text', async () => {
        const { server, url, store, session } = await setup('conflict');
        const original = (await store.load(session.id)).sections['finding-f3'];
        const first = await request(url, { method: 'POST', pathname: '/api/suggestion', body: { sectionId: 'finding-f3', markdown: 'Mine', baseRevision: 1 } });
        assert.equal(first.status, 200);
        assert.match(first.json.feedbackId, /^FB-\d{3}$/);
        assert.deepEqual((await store.load(session.id)).sections['finding-f3'], original, 'the section keeps its text');
        const back = await request(url, { method: 'POST', pathname: '/api/suggestion', body: { sectionId: 'finding-f3', markdown: original.markdown, baseRevision: 1 } });
        assert.equal(back.json.withdrawn, first.json.feedbackId);
        await store.update(session.id, (current) => agentEditSection(current, { sectionId: 'finding-f3', markdown: 'Agent text' }, new Date().toISOString()), { by: 'agent' });
        const stale = await request(url, { method: 'POST', pathname: '/api/suggestion', body: { sectionId: 'finding-f3', markdown: 'Stale', baseRevision: 1 } });
        assert.equal(stale.status, 409);
        assert.equal(stale.json.error.code, 'conflict');
        assert.equal(stale.json.error.section.markdown, 'Agent text');
        const missing = await request(url, { method: 'POST', pathname: '/api/suggestion', body: { sectionId: 'nope', markdown: 'x', baseRevision: 1 } });
        assert.equal(missing.status, 404);
        await server.stop();
        store.close();
    });

    it('sends exactly the reviewed text as one message, once, even after unrelated agent writes', async () => {
        const { server, url, store, sent, session } = await setup('delivery');
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const b = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Second', target: { id: 'F4' } } });
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'research-request', text: 'x' } })).status, 400, 'the canvas creates only comments from typed input');
        const ids = [a.json.item.id, b.json.item.id];
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids } });
        assert.match(preview.json.prompt, /^RPI canvas 3WF0 sent 2 items/);
        assert.match(preview.json.prompt, /Canvas instance ID: rpi-workflow-demo\./);
        await store.update(session.id, (current) => recordActivity(current, { text: 'Edited the outbox' }, new Date().toISOString()), { by: 'agent' });
        const delivered = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids, digest: preview.json.digest, note: 'Start with F1.' } });
        assert.equal(delivered.status, 200);
        assert.deepEqual(delivered.json.delivered, ids);
        assert.equal(sent.length, 1);
        assert.equal(sent[0].prompt.replace('\n\nMessage from the user:\n   Start with F1.', ''), preview.json.prompt, 'the sent text is the reviewed text plus the message');
        assert.match(sent[0].prompt, /Message from the user:\n {3}Start with F1\./);
        assert.equal(sent[0].displayPrompt, 'Start with F1.\n\nRPI canvas 3WF0 sent 2 items: 2 comments.');
        assert.deepEqual(Object.keys(sent[0]).sort(), ['displayPrompt', 'ids', 'mode', 'prompt']);
        assert.equal(sent[0].mode, 'immediate', 'Send now reaches the agent at its next step');
        const again = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids, digest: preview.json.digest } });
        assert.equal(again.status, 409);
        assert.equal(sent.length, 1);
        const stored = await store.load(session.id);
        assert.ok(ids.every((id) => stored.feedback.find((item) => item.id === id).delivery === 'send'));

        const c = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Third', target: { id: 'D2' } } });
        assert.equal((await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [c.json.item.id], mode: 'attach', digest: 'x' } })).status, 400);
        const stalePreview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [c.json.item.id] } });
        await store.update(session.id, (current) => upsertDecision(current, { id: 'D2', title: 'Renamed conflict decision' }, new Date().toISOString()), { by: 'agent' });
        const stale = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [c.json.item.id], digest: stalePreview.json.digest } });
        assert.equal(stale.status, 409);
        assert.equal(stale.json.error.code, 'preview_stale');
        assert.match(stale.json.error.preview.prompt, /Renamed conflict decision/);
        assert.notEqual(stale.json.error.preview.digest, stalePreview.json.digest);
        assert.equal(sent.length, 1);
        const missing = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [c.json.item.id] } });
        assert.equal(missing.status, 409);
        await server.stop();
        store.close();
    });

    it('records the chat message ID on items sent now', async () => {
        const { server, url, store, session } = await setup('delivery-id', { deliver: async () => ({ messageId: 'msg-7' }) });
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [a.json.item.id] } });
        assert.equal((await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [a.json.item.id], digest: preview.json.digest } })).status, 200);
        const item = (await store.load(session.id)).feedback.find((entry) => entry.id === a.json.item.id);
        assert.equal(item.messageId, 'msg-7');
        assert.equal(item.state, 'sent');
        await server.stop();
        store.close();
    });

    it('tells the pickup tracker which items each sent message carried', async () => {
        const remembered = [];
        const { server, url, store, session } = await setup('delivery-pickups', { deliver: async () => ({ messageId: 'msg-8' }), pickups: { remember: async (messageId, groups) => remembered.push({ messageId, groups }) } });
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [a.json.item.id] } });
        assert.equal((await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [a.json.item.id], digest: preview.json.digest } })).status, 200);
        assert.deepEqual(remembered, [{ messageId: 'msg-8', groups: [{ id: session.id, ids: [a.json.item.id] }] }]);
        await server.stop();
        store.close();
    });

    it('queues reviewed items for the agent without a message, keeps a note as a comment, and takes items back', async () => {
        const { server, url, store, sent, session } = await setup('delivery-queue');
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const b = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'Second', target: { id: 'F1' } } });
        const ids = [a.json.item.id, b.json.item.id];
        const body = { ids, note: 'Look at F1 first.' };
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body });
        const queued = await request(url, { method: 'POST', pathname: '/api/delivery', body: { ...body, digest: preview.json.digest, mode: 'queue' } });
        assert.equal(queued.status, 200);
        assert.equal(sent.length, 0, 'Queue sends no chat message');
        const noteId = queued.json.queued.at(-1).id;
        assert.deepEqual(queued.json.queued.map((entry) => entry.id), [...ids, noteId]);
        let stored = await store.load(session.id);
        const byId = (id) => stored.feedback.find((entry) => entry.id === id);
        assert.ok([...ids, noteId].every((id) => byId(id).state === 'queued' && typeof byId(id).queuedForAgentAt === 'string'), 'queued items stay in the canvas with the time');
        assert.equal(byId(noteId).kind, 'comment');
        assert.equal(byId(noteId).text, 'Look at F1 first.');

        const back = await request(url, { method: 'POST', pathname: '/api/feedback/take-back', body: { ids: [ids[0]] } });
        assert.equal(back.status, 200);
        assert.deepEqual(back.json.ids, [ids[0]]);
        stored = await store.load(session.id);
        assert.equal(byId(ids[0]).queuedForAgentAt, undefined, 'taken back, it waits for the user again');
        assert.equal(byId(ids[0]).state, 'queued');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/take-back', body: { ids: [ids[0]] } })).status, 409, 'it is no longer queued for the agent');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/take-back', body: { ids: [] } })).status, 400);

        await store.update(session.id, (current) => takeFeedback(current, new Date().toISOString()), { by: 'agent' });
        const late = await request(url, { method: 'POST', pathname: '/api/feedback/take-back', body: { ids: [ids[1]] } });
        assert.equal(late.status, 409);
        assert.match(late.json.error.message, /The agent already has FB-\d{3}\./);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids, digest: 'x', mode: 'later' } })).status, 400);
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
        const pending = request(slow.url, { method: 'POST', pathname: '/api/delivery', body: { ids: [id], digest: preview.json.digest } });
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
        const req = http.get({ host: '127.0.0.1', port: url.port, path: `/api/events?k=${url.searchParams.get('k')}` }, (res) => {
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

describe('a session-wide send', () => {
    /**
     * A canvas showing the child loop of a two-task session, with both documents in the store.
     * `fail` decides, per store write, whether that write throws.
     */
    async function sessionSetup(name, { fail = () => false, deliver, joined } = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const parent = await store.create({ ...rootSession().session, id: storeIdFor(ROOT_TASK, FIXTURE_ROOT) });
        const child = await store.create({ ...childSession().session, id: storeIdFor(CHILD_TASK, FIXTURE_ROOT) });
        const flaky = Object.create(store);
        let writes = 0;
        flaky.update = (id, change, opts) => {
            writes += 1;
            if (fail(id, writes)) return Promise.reject(new Error(`write ${writes} to ${id} failed`));
            return store.update(id, change, opts);
        };
        const sent = [];
        const server = createCanvasServer({
            store: flaky,
            getSessionId: () => child.id,
            getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
            getSource: () => ({ kind: 'rpi', workspace: { root: FIXTURE_ROOT }, follow: { paused: false } }),
            deliver: deliver ?? (async (message) => {
                sent.push(message);
            }),
            ...(joined ? { getJoinedSessionId: () => joined } : {}),
            markRetryMs: 1,
        });
        const url = new URL(await server.start());
        return { store, server, url, sent, parent, child };
    }

    const addComment = async (store, id, text) => {
        const { result } = await store.update(id, (current) => createFeedback(current, { kind: 'comment', text }, new Date().toISOString()), { by: 'user' });
        return result;
    };
    const item = async (store, docId, id) => (await store.load(docId)).feedback.find((entry) => entry.id === id);

    it('shows other tasks\' unsent items, removes one there, and sends every task in one grouped message', async () => {
        const { store, server, url, sent, parent, child } = await sessionSetup('session-send');
        const mine = await addComment(store, child.id, 'On the child');
        const theirs = await addComment(store, parent.id, 'On the parent');
        const state = await request(url, { pathname: '/api/state' });
        assert.deepEqual(state.json.follow, { paused: false, agent: null });
        assert.deepEqual(state.json.otherTasks.map((task) => [task.taskId, task.pending.map((entry) => entry.id)]), [[ROOT_TASK, [theirs.id]]]);
        const removed = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { taskId: ROOT_TASK, id: theirs.id, to: 'dismissed' } });
        assert.equal(removed.status, 200);
        assert.equal((await item(store, parent.id, theirs.id)).state, 'dismissed');
        assert.equal((await item(store, child.id, mine.id)).state, 'queued', 'the same ID in the shown task is untouched');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { taskId: 'not-in-session', id: theirs.id, to: 'dismissed' } })).status, 404);

        const again = await addComment(store, parent.id, 'Second thought on the parent');
        const items = [{ taskId: CHILD_TASK, id: mine.id }, { taskId: ROOT_TASK, id: again.id }];
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
        assert.equal(preview.status, 200);
        assert.match(preview.json.prompt, /about 2 tasks in session "Offline trail maps": 1 for trail-maps-fixes and 1 for trail-maps\./);
        const delivered = await request(url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest } });
        assert.equal(delivered.status, 200, JSON.stringify(delivered.json));
        assert.equal(sent.length, 1);
        assert.equal(sent[0].prompt, preview.json.prompt);
        assert.deepEqual(delivered.json.parts, [{ taskId: CHILD_TASK, ids: [mine.id] }, { taskId: ROOT_TASK, ids: [again.id] }]);
        for (const [docId, id] of [[child.id, mine.id], [parent.id, again.id]]) {
            const after = await item(store, docId, id);
            assert.deepEqual([after.state, after.deliveredWith, after.deliveringSince], ['sent', 2, undefined]);
        }
        await server.stop();
        store.close();
    });

    it('lists the other tasks\' items that may have been sent, and the relayed items the chat has not taken yet', async () => {
        const own = '7b2e8f10-3c4d-4e5f-8a6b-1c2d3e4f5a6b';
        const { store, server, url, parent } = await sessionSetup('session-overview', { joined: own.toUpperCase() });
        const held = await addComment(store, parent.id, 'Held');
        const relayed = await addComment(store, parent.id, 'Relayed');
        const theirs = await addComment(store, parent.id, 'Relayed by another session');
        const now = new Date().toISOString();
        await store.update(parent.id, (current) => markDeliveryUncertain(claimDelivery(current, [held.id], now).session, [held.id], now, { sessionId: own }), { by: 'user' });
        await store.update(parent.id, (current) => markDelivered(current, [relayed.id], 'send', now, { messageId: 'message-1', route: 'relay', relayedVia: own }), { by: 'user' });
        await store.update(parent.id, (current) => markDelivered(current, [theirs.id], 'send', now, { messageId: 'message-2', route: 'relay', relayedVia: 'c0ffee00-1111-4222-8333-444455556666' }), { by: 'user' });
        const state = await request(url, { pathname: '/api/state' });
        const [task] = state.json.otherTasks;
        assert.equal(state.json.ownSessionId, own, 'the page knows its own session, in lowercase');
        assert.deepEqual([task.pending.map((entry) => entry.id), task.awaiting, task.relayed, task.uncertain, task.uncertainIn], [[], 2, [relayed.id], [held.id], [own]]);
        await server.stop();
        store.close();
    });

    it('changes an unsent item\'s words in any loop, and discards more than a send can carry', async () => {
        const { store, server, url, parent, child } = await sessionSetup('session-edit-discard');
        const theirs = await addComment(store, parent.id, 'Old words on the parent');
        const edited = await request(url, { method: 'POST', pathname: '/api/feedback/edit', body: { taskId: ROOT_TASK, id: theirs.id, text: 'New words' } });
        assert.equal(edited.status, 200, JSON.stringify(edited.json));
        assert.equal((await item(store, parent.id, theirs.id)).text, 'New words');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/edit', body: { taskId: ROOT_TASK, id: theirs.id, text: ' ' } })).status, 400);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/feedback/edit', body: { taskId: 'not-in-session', id: theirs.id, text: 'x' } })).status, 404);

        const items = [{ taskId: ROOT_TASK, id: theirs.id }];
        for (let index = 0; index < 55; index += 1) items.push({ taskId: CHILD_TASK, id: (await addComment(store, child.id, `Note ${index}`)).id });
        items.push({ taskId: CHILD_TASK, id: 'FB-999' });
        const discarded = await request(url, { method: 'POST', pathname: '/api/feedback/discard', body: { items } });
        assert.equal(discarded.status, 200, JSON.stringify(discarded.json));
        assert.equal(discarded.json.discarded.length, 56, 'more than the 50 a send carries');
        assert.deepEqual(discarded.json.skipped, [{ taskId: CHILD_TASK, id: 'FB-999' }]);
        assert.equal((await item(store, parent.id, theirs.id)).state, 'dismissed');
        assert.ok((await store.load(child.id)).feedback.every((entry) => entry.state === 'dismissed'));
        await server.stop();
        store.close();
    });

    it('names the loop Follow agent goes to: the running loop, else the latest', async () => {
        const store = createStore({ root: path.join(tmp, 'agent-loop'), pollMs: 20 });
        const child = await store.create(childSession().session);
        const task = (id, extra) => ({ id, title: `Title ${id}`, status: 'completed', depth: 0, statePath: `s/${id}-state.json`, parent: null, shown: false, continues: null, changedAt: 0, ...extra });
        const source = { kind: 'rpi', follow: { paused: true }, tasks: [task('root', { changedAt: 50 }), task('loop', { parent: 's/root-state.json', changedAt: 10 })] };
        const server = createCanvasServer({ store, getSessionId: () => child.id, getSource: () => source });
        const url = new URL(await server.start());
        const latest = await request(url, { pathname: '/api/state' });
        assert.deepEqual(latest.json.follow, { paused: true, agent: { taskId: 'loop', title: 'Title loop', statePath: 's/loop-state.json', status: 'completed' } }, 'the root changed last but continues into the loop');
        source.tasks.push(task('other', { status: 'running', changedAt: 5 }));
        const running = await request(url, { pathname: '/api/state' });
        assert.equal(running.json.follow.agent.taskId, 'other', 'a running loop wins');
        await server.stop();
        store.close();
    });

    it('releases every hold when a later claim fails, before anything is sent', async () => {
        let armed = false;
        const { store, server, url, sent, parent, child } = await sessionSetup('session-claim-fails', { fail: (id) => armed && id === storeIdFor(ROOT_TASK, FIXTURE_ROOT) });
        const mine = await addComment(store, child.id, 'Child item');
        const theirs = await addComment(store, parent.id, 'Parent item');
        const items = [{ taskId: CHILD_TASK, id: mine.id }, { taskId: ROOT_TASK, id: theirs.id }];
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
        armed = true;
        const failed = await request(url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest } });
        armed = false;
        assert.equal(failed.status, 500);
        assert.equal(sent.length, 0);
        for (const [docId, id] of [[child.id, mine.id], [parent.id, theirs.id]]) {
            const after = await item(store, docId, id);
            assert.deepEqual([after.state, after.deliveringSince], ['queued', undefined], `${docId} is released`);
        }
        await server.stop();
        store.close();
    });

    it('never releases once the message is handed over, and reports a mark that keeps failing', async () => {
        let marking = false;
        const { store, server, url, sent, parent, child } = await sessionSetup('session-mark-fails', {
            fail: (id) => marking && id === storeIdFor(ROOT_TASK, FIXTURE_ROOT),
            deliver: async (message) => {
                sent.push(message);
                marking = true;
            },
        });
        const mine = await addComment(store, child.id, 'Child item');
        const theirs = await addComment(store, parent.id, 'Parent item');
        const items = [{ taskId: CHILD_TASK, id: mine.id }, { taskId: ROOT_TASK, id: theirs.id }];
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
        const result = await request(url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest } });
        marking = false;
        assert.equal(result.status, 200);
        assert.equal(sent.length, 1);
        assert.match(result.json.warning, /could not record it for trail-maps yet/);
        assert.deepEqual(result.json.delivered, [mine.id]);
        assert.equal((await item(store, child.id, mine.id)).state, 'sent');
        const held = await item(store, parent.id, theirs.id);
        assert.equal(held.state, 'queued');
        assert.ok(held.deliveringSince, 'the parent item stays held so it is not sent twice');
        await server.stop();
        store.close();
    });

    it('accepts a comment anchored to a Decisions row', async () => {
        const { store, server, url } = await sessionSetup('session-decisions-row');
        const posted = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', target: { id: 'plan-decisions' }, text: 'Lay these out one per line.' } });
        assert.equal(posted.status, 200, JSON.stringify(posted.json));
        assert.deepEqual([posted.json.item.target.type, posted.json.item.target.phase], ['decisions-row', 'plan']);
        await server.stop();
        store.close();
    });
});


describe('a send to another session', () => {
    const PROJECT = '7b2e8f10-3c4d-4e5f-8a6b-1c2d3e4f5a6b';
    const CHILD = 'c4d5e6f7-0a1b-4c2d-9e3f-4a5b6c7d8e9f';
    const SIBLING = 'd5e6f7a8-1b2c-4d3e-8f4a-5b6c7d8e9f0a';
    const SESSION_NAME = 'Offline trail maps';

    /** Checks `condition` (sync or async) every 20 ms until it holds, for up to 3 seconds. */
    async function until(condition) {
        const end = Date.now() + 3000;
        while (!(await condition())) {
            if (Date.now() > end) throw new Error('The condition was not met in time.');
            await new Promise((resolve) => setTimeout(resolve, 20));
        }
    }

    const addComment = async (store, id, text) => {
        const { result } = await store.update(id, (current) => createFeedback(current, { kind: 'comment', text }, new Date().toISOString()), { by: 'user' });
        return result;
    };
    const itemIn = async (store, docId, id) => (await store.load(docId)).feedback.find((entry) => entry.id === id);

    /**
     * A canvas that shows the child's task, bound to the child's session and joined to the Project's
     * session. `childRunner` is the child's canvas process, and `source` is this canvas's own process
     * for the Project's session. `shown` is what the canvas shows; a test can rebind its `boundSession`. `failWrites` decides which of the canvas's writes fail: it receives
     * the number of each write, counted from 1 across task documents, the outbox, and the inbox, and
     * returns true for a write that fails. Tests reassign `writes.failWrites` to let the canvas restart.
     * `hooks.beforeInboxWrite`, when set, runs once before the source writes an inbox entry. `withParent`
     * also stores the parent task's document, in the same session, and `joined` is the Copilot session
     * this canvas joins, or null for none. `settleClock` gives the source process a clock the test moves
     * (in `sourceClock.at`), so its claim window can pass without waiting.
     */
    async function crossSetup(name, { claimWindowMs, failWrites = () => false, withParent = false, joined = PROJECT, settleClock = false } = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const child = await store.create({ ...childSession().session, id: storeIdFor(CHILD_TASK, FIXTURE_ROOT) });
        const parent = withParent ? await store.create({ ...rootSession().session, id: storeIdFor(ROOT_TASK, FIXTURE_ROOT) }) : null;
        const writes = { count: 0, failWrites };
        const flaky = Object.create(store);
        for (const method of ['update', 'updateOutbox', 'updateInbox']) {
            flaky[method] = (...args) => {
                writes.count += 1;
                if (writes.failWrites(writes.count)) {
                    return Promise.reject(new ModelError('storage_failed', 'The write could not be saved.'));
                }
                return store[method](...args);
            };
        }
        const hooks = { beforeInboxWrite: null };
        const sourceStore = Object.create(store);
        sourceStore.updateInbox = async (id, change, options) => {
            const hook = hooks.beforeInboxWrite;
            if (hook && id === CHILD) {
                hooks.beforeInboxWrite = null;
                await hook();
            }
            return store.updateInbox(id, change, options);
        };
        const chat = [];
        const childChat = [];
        const childRunner = createInboxRunner({ store, sessionId: CHILD, pid: 6161, pause: async () => {}, deliver: async (request) => {
            childChat.push(request);
            return { messageId: 'child-1' };
        } });
        const sourceClock = { at: Date.now() };
        const source = createInboxRunner({ store: sourceStore, sessionId: PROJECT, pid: 5151, pause: async () => {}, now: settleClock ? () => sourceClock.at : undefined, deliver: async (request) => {
            chat.push(request);
            return { messageId: `relay-${chat.length}` };
        } });
        const shown = { kind: 'rpi', boundSession: CHILD, workspace: { root: FIXTURE_ROOT }, follow: { paused: false } };
        const server = createCanvasServer({
            store: flaky,
            getSessionId: () => child.id,
            getCanvas: () => ({ handle: 'K7QF', instanceId: 'rpi-workflow-demo' }),
            getSource: () => shown,
            getJoinedSessionId: () => joined,
            deliver: async (request) => {
                chat.push(request);
                return { messageId: `own-${chat.length}` };
            },
            wakeOutbox: () => source.wakeOutbox(),
            claimWindowMs,
            markRetryMs: 1,
        });
        const url = new URL(await server.start());
        return {
            store, server, url, child, parent, chat, childChat, childRunner, source, shown, hooks, writes, sourceClock,
            async stop() {
                await server.stop();
                await childRunner.stop();
                await source.stop();
                store.close();
            },
        };
    }

    /**
     * Moves the source process's clock past the claim window of the pending hand-off that the Send wrote,
     * then checks the outbox.
     */
    async function passClaimWindow(f) {
        const [entry] = (await f.store.loadOutbox(PROJECT)).entries;
        f.sourceClock.at = Date.parse(entry.createdAt) + CLAIM_STALE_MS + 1;
        await f.source.checkOutbox();
    }

    /** Previews the items as the page does, then sends them with the previewed digest. */
    async function sendItems(f, body) {
        const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body });
        const sent = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { ...body, digest: preview.json.digest } });
        return { preview, sent };
    }

    it('hands the items to a live canvas process of the target session, which sends them once and records the inbox route', async () => {
        const f = await crossSetup('cross-live');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.deepEqual(preview.json.route, { kind: 'inbox', sessionId: CHILD, sessionName: SESSION_NAME });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.deepEqual([sent.json.delivered, sent.json.handedOff.map((hand) => [hand.taskId, hand.ids])], [[], [[CHILD_TASK, [mine.id]]]]);
            assert.deepEqual(sent.json.route, preview.json.route);
            assert.deepEqual([f.chat.length, f.childChat.length], [0, 0], 'nothing is sent yet, and the canvas\'s own chat gets nothing');
            const [entry] = (await f.store.loadInbox(CHILD)).entries;
            assert.deepEqual([entry.state, entry.from], ['waiting', { sessionId: PROJECT, handle: 'K7QF' }]);
            await f.childRunner.checkInbox();
            assert.equal(f.childChat.length, 1);
            assert.equal(f.childChat[0].prompt.split('\n')[0], `RPI canvas K7QF in session ${PROJECT} sent 1 item for this task. They are the user's input from that canvas.`);
            const after = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([after.state, after.route, after.messageId, after.handoff], ['sent', 'inbox', 'child-1', undefined]);
            assert.deepEqual((await f.store.loadInbox(CHILD)).entries, []);
        } finally {
            await f.stop();
        }
    });

    it('relays through its own chat at once when no canvas process of the target session is live', async () => {
        const f = await crossSetup('cross-relay');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.deepEqual(preview.json.route, { kind: 'relay', sessionId: CHILD, sessionName: SESSION_NAME });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.equal(sent.json.handedOff[0].ids[0], mine.id);
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            const { statePath } = (await f.store.load(f.child.id)).source;
            assert.equal(f.chat.length, 1);
            assert.equal(f.chat[0].prompt.split('\n')[0], `RPI canvas K7QF has 1 item for session ${CHILD} (task ${CHILD_TASK}, state ${statePath}).`);
            assert.equal(f.chat[0].displayPrompt, 'RPI canvas K7QF: 1 item for another session to forward.');
            assert.deepEqual(f.chat[0].ids, [mine.id]);
            assert.deepEqual((await f.store.loadInbox(CHILD)).entries, [], 'no inbox entry is written');
            const after = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([after.route, after.relayedVia, after.messageId, f.childChat.length], ['relay', PROJECT, 'relay-1', 0]);
        } finally {
            await f.stop();
        }
    });

    it('withdraws an entry that no process claimed within the claim window, then relays its items through its own chat', async () => {
        const f = await crossSetup('cross-window', { claimWindowMs: 200 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(preview.json.route.kind, 'inbox');
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.equal((await f.store.loadInbox(CHILD)).entries.length, 1);
            await until(async () => {
                await f.source.checkOutbox();
                return (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0;
            });
            assert.deepEqual((await f.store.loadInbox(CHILD)).entries, [], 'the unclaimed entry is withdrawn');
            assert.equal(f.childChat.length, 0, 'the target process never sent the items');
            assert.match(f.chat[0].prompt, /^RPI canvas K7QF has 1 item for session /);
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).route, 'relay');
        } finally {
            await f.stop();
        }
    });

    it('sends the items once through the target process, and relays nothing, when the target claims its entry as the window ends', async () => {
        const f = await crossSetup('cross-claim-at-end', { claimWindowMs: 0 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            f.hooks.beforeInboxWrite = () => f.childRunner.checkInbox();
            const { sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            assert.equal(f.childChat.length, 1, 'the target process sent the items');
            assert.equal(f.chat.length, 0, 'the source relayed nothing');
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).route, 'inbox');
            assert.deepEqual((await f.store.loadInbox(CHILD)).entries, []);
        } finally {
            await f.stop();
        }
    });

    it('asks the agent through the canvas\'s own chat, even while another session\'s canvas process is live', async () => {
        const store = createStore({ root: path.join(tmp, 'cross-ask'), pollMs: 20 });
        const chat = [];
        const childRunner = createInboxRunner({ store, sessionId: CHILD, pid: 6161, pause: async () => {}, deliver: async () => ({ messageId: 'child-1' }) });
        await childRunner.heartbeat();
        const server = createCanvasServer({
            store,
            getSessionId: () => '',
            getCanvas: () => ({ handle: 'K7QF', instanceId: 'rpi-workflow-demo' }),
            getSource: () => ({ kind: 'none', reason: 'missing-session', detail: null }),
            getJoinedSessionId: () => PROJECT,
            deliver: async (request) => {
                chat.push(request);
                return { messageId: 'own-1' };
            },
        });
        const url = new URL(await server.start());
        const asked = await request(url, { method: 'POST', pathname: '/api/connect-request', body: {} });
        assert.deepEqual([asked.status, asked.json.sent], [200, true]);
        assert.equal(chat.length, 1);
        assert.equal(chat[0].displayPrompt, "RPI canvas K7QF: connect this canvas to this conversation's RPI session.");
        assert.deepEqual([(await store.loadInbox(CHILD)).entries, (await store.loadOutbox(PROJECT)).entries], [[], []]);
        await server.stop();
        await childRunner.stop();
        store.close();
    });

    it('sends a note with the items as a comment of the shown task, held and handed off with them', async () => {
        const f = await crossSetup('cross-note');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }], note: 'Start with the header.' });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            const [hand] = sent.json.handedOff;
            assert.equal(hand.ids.length, 2);
            const note = await itemIn(f.store, f.child.id, hand.ids[1]);
            assert.deepEqual([note.kind, note.text, note.target, note.handoff.entryId === hand.entryId], ['comment', 'Start with the header.', null, true]);
            await f.childRunner.checkInbox();
            assert.equal(f.childChat.length, 1);
            assert.match(f.childChat[0].prompt, /Comment on the session\n {3}Start with the header\./);
            assert.equal(f.childChat[0].displayPrompt, 'RPI canvas K7QF sent 2 items: 2 comments.');
            assert.deepEqual([(await itemIn(f.store, f.child.id, note.id)).state, (await itemIn(f.store, f.child.id, note.id)).route], ['sent', 'inbox']);
        } finally {
            await f.stop();
        }
    });

    it('undoes a hand-off whose inbox write fails: releases the holds, removes the entries, dismisses the note, and sends again on retry', async () => {
        const f = await crossSetup('cross-undo-inbox', { failWrites: (n) => n === 3 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const body = { items: [{ taskId: CHILD_TASK, id: mine.id }], note: 'Also this.' };
            const failed = await sendItems(f, body);
            assert.equal(failed.sent.status, 500, JSON.stringify(failed.sent.json));
            const held = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([held.state, held.handoff, held.deliveringSince], ['queued', undefined, undefined]);
            assert.deepEqual((await f.store.load(f.child.id)).feedback.filter((entry) => entry.text === 'Also this.').map((entry) => entry.state), ['dismissed']);
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries, (await f.store.loadInbox(CHILD)).entries, f.chat.length], [[], [], 0]);
            const retried = await sendItems(f, body);
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            assert.equal(retried.sent.json.handedOff[0].ids.length, 2);
        } finally {
            await f.stop();
        }
    });

    it('a hand-off whose outbox write fails holds nothing, writes no note, and sends again on retry', async () => {
        const f = await crossSetup('cross-undo-outbox', { failWrites: (n) => n === 1 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const body = { items: [{ taskId: CHILD_TASK, id: mine.id }], note: 'Also this.' };
            const failed = await sendItems(f, body);
            assert.equal(failed.sent.status, 500, JSON.stringify(failed.sent.json));
            const held = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([held.state, held.handoff, held.deliveringSince], ['queued', undefined, undefined]);
            assert.deepEqual((await f.store.load(f.child.id)).feedback.filter((entry) => entry.text === 'Also this.'), [], 'no note is written');
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries, (await f.store.loadInbox(CHILD)).entries, f.chat.length], [[], [], 0]);
            const retried = await sendItems(f, body);
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            assert.equal(retried.sent.json.handedOff[0].ids.length, 2);
        } finally {
            await f.stop();
        }
    });

    it('a canvas that stops after the holds are written and before the hand-off commits leaves items that the runner releases after the claim window, unsent; a retry sends them once', async () => {
        // Every write from the commit on fails, as if the canvas had stopped there, so no undo runs.
        const f = await crossSetup('cross-stop', { settleClock: true, failWrites: (n) => n >= 3 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const { sent } = await sendItems(f, { items });
            assert.equal(sent.status, 500, JSON.stringify(sent.json));
            const [entry] = (await f.store.loadOutbox(PROJECT)).entries;
            assert.deepEqual([entry.state, (await itemIn(f.store, f.child.id, mine.id)).handoff.entryId], ['pending', entry.id], 'the items stay held by the pending entry');
            await f.source.checkOutbox();
            assert.deepEqual([f.chat.length, f.childChat.length, (await f.store.loadOutbox(PROJECT)).entries.length], [0, 0, 1], 'nothing is sent or released inside the claim window');
            f.writes.failWrites = () => false;
            await passClaimWindow(f);
            const released = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([released.state, released.handoff, released.deliveringSince], ['queued', undefined, undefined]);
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries, f.chat.length, f.childChat.length], [[], 0, 0], 'the runner released the items and sent nothing');
            const retried = await sendItems(f, { items });
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            assert.equal(f.chat.length, 1, 'the retry relays the items once');
        } finally {
            await f.stop();
        }
    });

    it('a hand-off whose undo cannot release its items leaves them to the runner: nothing is relayed, and after the claim window the runner releases them and dismisses the note', async () => {
        // The commit and the undo's release both fail, so the undo stops with the items still held.
        const f = await crossSetup('cross-release-fails', { settleClock: true, failWrites: (n) => n === 3 || n === 4 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const body = { items: [{ taskId: CHILD_TASK, id: mine.id }], note: 'Also this.' };
            const failed = await sendItems(f, body);
            assert.equal(failed.sent.status, 500, JSON.stringify(failed.sent.json));
            assert.ok((await itemIn(f.store, f.child.id, mine.id)).handoff, 'the item is still held');
            assert.deepEqual((await f.store.load(f.child.id)).feedback.filter((entry) => entry.text === 'Also this.').map((entry) => entry.state), ['queued'], 'the note is still held too');
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries.map((entry) => entry.state), f.chat.length], [['pending'], 0]);
            await f.source.checkOutbox();
            assert.deepEqual([f.chat.length, f.childChat.length], [0, 0], 'nothing is relayed while the entry is pending');
            f.writes.failWrites = () => false;
            await passClaimWindow(f);
            const released = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([released.state, released.handoff], ['queued', undefined]);
            assert.deepEqual((await f.store.load(f.child.id)).feedback.filter((entry) => entry.text === 'Also this.').map((entry) => entry.state), ['dismissed']);
            assert.deepEqual([f.chat.length, f.childChat.length], [0, 0], 'nothing is relayed');
            const retried = await sendItems(f, body);
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            assert.equal(f.chat.length, 1, 'the retry relays the items once');
        } finally {
            await f.stop();
        }
    });

    it('a hand-off whose inbox write and undo release both fail sends nothing, and the runner releases the items after the claim window', async () => {
        const f = await crossSetup('cross-inbox-release-fails', { settleClock: true, failWrites: (n) => n === 3 || n === 4 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const failed = await sendItems(f, { items });
            assert.equal(failed.sent.status, 500, JSON.stringify(failed.sent.json));
            assert.deepEqual([(await f.store.loadInbox(CHILD)).entries, (await f.store.loadOutbox(PROJECT)).entries.map((entry) => entry.state)], [[], ['pending']]);
            await f.childRunner.checkInbox();
            assert.equal(f.childChat.length, 0, 'the target has no entry to send');
            f.writes.failWrites = () => false;
            await passClaimWindow(f);
            assert.deepEqual([(await itemIn(f.store, f.child.id, mine.id)).handoff, (await f.store.loadOutbox(PROJECT)).entries], [undefined, []]);
            await f.childRunner.checkInbox();
            assert.deepEqual([f.childChat.length, f.chat.length], [0, 0], 'nothing is sent');
            const retried = await sendItems(f, { items });
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            await f.childRunner.checkInbox();
            assert.deepEqual([f.childChat.length, f.chat.length], [1, 0], 'the retry is delivered once, through the target');
        } finally {
            await f.stop();
        }
    });

    it('a hand-off whose inbox write fails is never delivered, and the retry is delivered once through the target', async () => {
        const f = await crossSetup('cross-inbox-fails', { failWrites: (n) => n === 3 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const failed = await sendItems(f, { items });
            assert.equal(failed.sent.status, 500, JSON.stringify(failed.sent.json));
            await f.childRunner.checkInbox();
            await f.source.checkOutbox();
            assert.deepEqual([f.chat.length, f.childChat.length, (await f.store.loadOutbox(PROJECT)).entries.length, (await f.store.loadInbox(CHILD)).entries.length], [0, 0, 0, 0]);
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).handoff, undefined);
            const retried = await sendItems(f, { items });
            assert.equal(retried.sent.status, 200, JSON.stringify(retried.sent.json));
            assert.equal(retried.sent.json.route.kind, 'inbox');
            await f.childRunner.checkInbox();
            const after = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([f.childChat.length, after.state, after.route, f.chat.length], [1, 'sent', 'inbox', 0]);
        } finally {
            await f.stop();
        }
    });

    it('a commit that fails after the target\'s inbox entries are written leaves the hand-off standing: the target sends the items once, and the runner releases nothing', async () => {
        const f = await crossSetup('cross-commit-fails', { settleClock: true, failWrites: (n) => n === 4 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.deepEqual((await f.store.loadOutbox(PROJECT)).entries.map((entry) => entry.state), ['pending']);
            await f.childRunner.checkInbox();
            const after = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([f.childChat.length, after.state, after.route], [1, 'sent', 'inbox']);
            await passClaimWindow(f);
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries, f.chat.length, f.childChat.length], [[], 0, 1], 'the items went once, through the target');
        } finally {
            await f.stop();
        }
    });

    it('a commit that fails after the target\'s inbox entries are written, with no claim from the target, is committed once the claim window has passed, and relayed', async () => {
        const f = await crossSetup('cross-commit-unclaimed', { settleClock: true, failWrites: (n) => n === 4 });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.equal((await f.store.loadInbox(CHILD)).entries.length, 1, 'the target has its entry, unclaimed');
            await passClaimWindow(f);
            assert.deepEqual((await f.store.loadOutbox(PROJECT)).entries.map((entry) => entry.state), ['committed']);
            await f.source.checkOutbox();
            assert.deepEqual([f.childChat.length, f.chat.length, (await f.store.loadInbox(CHILD)).entries.length, (await f.store.loadOutbox(PROJECT)).entries.length], [0, 1, 0, 0]);
            const after = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([after.state, after.route], ['sent', 'relay']);
        } finally {
            await f.stop();
        }
    });

    it('reports the own route for the canvas\'s own tasks, with no session to name', async () => {
        const { server, url, store } = await setup('route-own');
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const preview = await request(url, { method: 'POST', pathname: '/api/delivery/preview', body: { ids: [a.json.item.id] } });
        assert.deepEqual([preview.json.route.kind, preview.json.route.sessionId], ['own', null]);
        assert.match(preview.json.prompt, /^RPI canvas 3WF0 sent 1 item from the user about task /);
        assert.equal(preview.json.messages, undefined, 'the own route is one chat message, as before');
        await server.stop();
        store.close();
    });

    it('names the session the shown tasks go to in the state, and none for the canvas\'s own tasks', async () => {
        const f = await crossSetup('cross-state-delivery');
        try {
            const state = await request(f.url, { pathname: '/api/state' });
            assert.deepEqual(state.json.delivery, { sessionId: CHILD, sessionName: SESSION_NAME });
        } finally {
            await f.stop();
        }
        const own = await setup('state-delivery-own');
        assert.equal((await request(own.url, { pathname: '/api/state' })).json.delivery, null);
        await own.server.stop();
        own.store.close();
    });

    it('refuses a Send now whose route changed since the preview, changes nothing, and sends once the new route is named', async () => {
        const f = await crossSetup('cross-route-changed');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            assert.equal(preview.json.route.kind, 'inbox');
            await f.childRunner.stop();
            const refused = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, route: 'inbox' } });
            assert.equal(refused.status, 409, JSON.stringify(refused.json));
            assert.equal(refused.json.error.code, 'preview_stale');
            assert.deepEqual(refused.json.error.preview.route, { kind: 'relay', sessionId: CHILD, sessionName: SESSION_NAME });
            assert.equal(refused.json.error.preview.digest, preview.json.digest, 'the list is the same; only the route moved');
            const relayed = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            assert.deepEqual([refused.json.error.preview.prompt, refused.json.error.preview.displayPrompt], [relayed.json.prompt, relayed.json.displayPrompt], 'the refusal shows the relay message');
            assert.notEqual(refused.json.error.preview.prompt, preview.json.prompt, 'and not the inbox message the page had');
            const held = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([held.state, held.handoff, held.deliveringSince, held.route], ['queued', undefined, undefined, undefined]);
            assert.deepEqual([(await f.store.loadInbox(CHILD)).entries, (await f.store.loadOutbox(PROJECT)).entries, f.chat.length, f.childChat.length], [[], [], 0, 0]);
            const sent = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: refused.json.error.preview.digest, route: refused.json.error.preview.route.kind } });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.equal(sent.json.route.kind, 'relay');
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).route, 'relay');
            assert.equal(f.chat.length, 1, 'the items went once, through the relay the page named');
        } finally {
            await f.stop();
        }
    });

    it('refuses a Send now whose preview showed another session that shares the checkout, and changes nothing', async () => {
        const f = await crossSetup('cross-rebound');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            assert.equal(preview.json.route.sessionId, CHILD);
            f.shown.boundSession = SIBLING;
            const refused = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, route: preview.json.route.kind } });
            assert.deepEqual([refused.status, refused.json.error.code], [409, 'preview_stale'], JSON.stringify(refused.json));
            assert.deepEqual([refused.json.error.preview.route.kind, refused.json.error.preview.route.sessionId], [preview.json.route.kind, SIBLING], 'only the session moved');
            const held = await itemIn(f.store, f.child.id, mine.id);
            assert.deepEqual([held.state, held.handoff], ['queued', undefined]);
            assert.deepEqual([(await f.store.loadOutbox(PROJECT)).entries, f.chat.length, f.childChat.length], [[], 0, 0]);
        } finally {
            await f.stop();
        }
    });

    it('sends a Send now that names the route its preview showed, and checks no route when none is named', async () => {
        const f = await crossSetup('cross-route-match');
        try {
            const first = await addComment(f.store, f.child.id, 'First.');
            const second = await addComment(f.store, f.child.id, 'Second.');
            await f.childRunner.heartbeat();
            const firstItems = [{ taskId: CHILD_TASK, id: first.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items: firstItems } });
            const matched = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items: firstItems, digest: preview.json.digest, route: 'inbox' } });
            assert.equal(matched.status, 200, JSON.stringify(matched.json));
            assert.deepEqual([matched.json.route.kind, matched.json.handedOff.map((hand) => hand.ids)], ['inbox', [[first.id]]]);
            const older = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: second.id }] });
            assert.equal(older.sent.status, 200, JSON.stringify(older.sent.json));
            assert.deepEqual(older.sent.json.handedOff.map((hand) => hand.ids), [[second.id]], 'a body without a route is sent as before');
        } finally {
            await f.stop();
        }
    });

    it('refuses a route the server does not know, and leaves Queue alone, whichever route it names', async () => {
        const f = await crossSetup('cross-route-invalid');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            const invalid = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, route: 'elsewhere' } });
            assert.deepEqual([invalid.status, invalid.json.error.code], [400, 'invalid_input']);
            assert.deepEqual([(await f.store.loadInbox(CHILD)).entries.length, (await itemIn(f.store, f.child.id, mine.id)).state], [0, 'queued']);
            const queued = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, mode: 'queue', route: 'relay' } });
            assert.equal(queued.status, 200, JSON.stringify(queued.json));
            assert.deepEqual(queued.json.queued, [{ taskId: CHILD_TASK, id: mine.id }]);
            assert.deepEqual([(await f.store.loadInbox(CHILD)).entries.length, f.chat.length], [0, 0]);
        } finally {
            await f.stop();
        }
    });

    it('previews the inbox message the target canvas sends into its chat, which is the message the chat gets', async () => {
        const f = await crossSetup('cross-preview-inbox');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(preview.json.route.kind, 'inbox');
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            await f.childRunner.checkInbox();
            const [message] = f.childChat;
            assert.deepEqual([preview.json.prompt, preview.json.displayPrompt], [message.prompt, message.displayPrompt]);
            assert.deepEqual(preview.json.messages, [{ taskId: CHILD_TASK, prompt: message.prompt, displayPrompt: message.displayPrompt }]);
        } finally {
            await f.stop();
        }
    });

    it('previews the relay message this chat sends, which is the message the chat gets', async () => {
        const f = await crossSetup('cross-preview-relay');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }] });
            assert.equal(preview.json.route.kind, 'relay');
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            const [message] = f.chat;
            assert.deepEqual([preview.json.prompt, preview.json.displayPrompt], [message.prompt, message.displayPrompt]);
            assert.deepEqual(preview.json.messages, [{ taskId: CHILD_TASK, prompt: message.prompt, displayPrompt: message.displayPrompt }]);
        } finally {
            await f.stop();
        }
    });

    it('puts a note in the inbox preview as a comment that the message carries, stores nothing until sent, and keeps the digest', async () => {
        const f = await crossSetup('cross-preview-note-inbox');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const stored = (await f.store.load(f.child.id)).feedback.length;
            const plain = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            const noted = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items, note: 'Start with the header.' } });
            assert.equal(noted.json.digest, plain.json.digest, 'typing a note does not stale a preview');
            assert.equal((await f.store.load(f.child.id)).feedback.length, stored, 'the preview stores no note');
            assert.match(noted.json.prompt, /Comment on the session\n {3}Start with the header\./);
            const sent = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, note: 'Start with the header.', digest: noted.json.digest } });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            assert.equal(sent.json.handedOff[0].ids.length, 2);
            await f.childRunner.checkInbox();
            assert.deepEqual([f.childChat[0].prompt, f.childChat[0].displayPrompt], [noted.json.prompt, noted.json.displayPrompt]);
        } finally {
            await f.stop();
        }
    });

    it('puts a note in the relay preview as a comment that the relayed message carries', async () => {
        const f = await crossSetup('cross-preview-note-relay');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }], note: 'Start with the header.' });
            assert.equal(preview.json.route.kind, 'relay');
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            const [message] = f.chat;
            assert.match(message.prompt, /Comment on the session\n {3}Start with the header\./);
            assert.deepEqual([preview.json.prompt, preview.json.displayPrompt], [message.prompt, message.displayPrompt]);
            assert.deepEqual(message.ids, sent.json.handedOff[0].ids);
        } finally {
            await f.stop();
        }
    });

    it('previews one message for each task under its heading, and each message is the one its canvas process sends', async () => {
        const f = await crossSetup('cross-preview-two-tasks', { withParent: true });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const theirs = await addComment(f.store, f.parent.id, 'Check the legend too.');
            await f.childRunner.heartbeat();
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }, { taskId: ROOT_TASK, id: theirs.id }] });
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            const [first, second] = preview.json.messages;
            assert.deepEqual(preview.json.messages.map((message) => message.taskId), [CHILD_TASK, ROOT_TASK]);
            assert.equal(preview.json.prompt, `Message 1 of 2, task ${CHILD_TASK}:\n${first.prompt}\n\nMessage 2 of 2, task ${ROOT_TASK}:\n${second.prompt}`);
            assert.equal(preview.json.displayPrompt, `${first.displayPrompt} / ${second.displayPrompt}`);
            await f.childRunner.checkInbox();
            assert.deepEqual(f.childChat.map((message) => [message.prompt, message.displayPrompt]), [[first.prompt, first.displayPrompt], [second.prompt, second.displayPrompt]]);
        } finally {
            await f.stop();
        }
    });

    it('previews one relay message for each task, and this chat sends each of them in that order', async () => {
        const f = await crossSetup('cross-preview-relay-two-tasks', { withParent: true });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const theirs = await addComment(f.store, f.parent.id, 'Check the legend too.');
            const { preview, sent } = await sendItems(f, { items: [{ taskId: CHILD_TASK, id: mine.id }, { taskId: ROOT_TASK, id: theirs.id }] });
            assert.equal(preview.json.route.kind, 'relay');
            assert.equal(sent.status, 200, JSON.stringify(sent.json));
            await until(async () => (await itemIn(f.store, f.child.id, mine.id)).state === 'sent' && (await itemIn(f.store, f.parent.id, theirs.id)).state === 'sent' && (await f.store.loadOutbox(PROJECT)).entries.length === 0);
            const [first, second] = preview.json.messages;
            assert.deepEqual(f.chat.map((message) => [message.prompt, message.displayPrompt]), [[first.prompt, first.displayPrompt], [second.prompt, second.displayPrompt]]);
            assert.equal(preview.json.prompt, `Message 1 of 2, task ${CHILD_TASK}:\n${first.prompt}\n\nMessage 2 of 2, task ${ROOT_TASK}:\n${second.prompt}`);
        } finally {
            await f.stop();
        }
    });

    it('gives the 409 for changed items the text of the route the preview named, and sends nothing', async () => {
        const f = await crossSetup('cross-stale-items');
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            await f.childRunner.heartbeat();
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            const edited = await request(f.url, { method: 'POST', pathname: '/api/feedback/edit', body: { taskId: CHILD_TASK, id: mine.id, text: 'Keep the header row and the footer.' } });
            assert.equal(edited.status, 200, JSON.stringify(edited.json));
            const stale = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, route: 'inbox' } });
            assert.deepEqual([stale.status, stale.json.error.code], [409, 'preview_stale']);
            const fresh = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            assert.equal(stale.json.error.preview.route.kind, 'inbox');
            assert.equal(stale.json.error.preview.prompt, fresh.json.prompt);
            assert.match(stale.json.error.preview.prompt, /Comment on the session\n {3}Keep the header row and the footer\./);
            assert.deepEqual([(await f.store.loadInbox(CHILD)).entries, (await f.store.loadOutbox(PROJECT)).entries, f.chat.length, f.childChat.length], [[], [], 0, 0]);
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).handoff, undefined, 'the item is not held');
        } finally {
            await f.stop();
        }
    });

    it('keeps Queue working while the canvas has no Copilot session, and refuses Send now with the reason', async () => {
        const f = await crossSetup('cross-preview-no-session', { joined: null });
        try {
            const mine = await addComment(f.store, f.child.id, 'Keep the header row.');
            const items = [{ taskId: CHILD_TASK, id: mine.id }];
            const preview = await request(f.url, { method: 'POST', pathname: '/api/delivery/preview', body: { items } });
            assert.equal(preview.status, 200, JSON.stringify(preview.json));
            const sent = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, mode: 'send' } });
            assert.deepEqual([sent.status, sent.json.error.code], [503, 'delivery_unavailable']);
            assert.equal((await itemIn(f.store, f.child.id, mine.id)).handoff, undefined, 'nothing is held');
            const queued = await request(f.url, { method: 'POST', pathname: '/api/delivery', body: { items, digest: preview.json.digest, mode: 'queue' } });
            assert.equal(queued.status, 200, JSON.stringify(queued.json));
            assert.ok((await itemIn(f.store, f.child.id, mine.id)).queuedForAgentAt, 'Queue still marks the item for the agent');
        } finally {
            await f.stop();
        }
    });
});

describe('client info', () => {
    it('keeps a render failure, capped, so get_state can report a blank page', () => {
        assert.equal(clientInfoFrom({ scheme: 'dark' }).renderError, null);
        assert.equal(clientInfoFrom({ renderError: '   ' }).renderError, null);
        assert.equal(clientInfoFrom({ renderError: 42 }).renderError, null);
        assert.equal(clientInfoFrom({ renderError: "Cannot read properties of undefined (reading 'name')" }).renderError, "Cannot read properties of undefined (reading 'name')");
        assert.equal(clientInfoFrom({ renderError: 'x'.repeat(1000) }).renderError.length, 300);
    });
});

describe('the canvas key', () => {
    it('admits only API calls that carry the key from the page address', async () => {
        const { server, url } = await setup('key');
        try {
            const key = url.searchParams.get('k');
            assert.match(key, /^[A-Za-z0-9_-]{32}$/);
            assert.equal(server.address, `http://127.0.0.1:${url.port}/`);
            assert.equal(server.url, url.href);
            const denied = await request(url, { pathname: '/api/state', key: false });
            assert.deepEqual([denied.status, denied.json.error.code], [403, 'invalid_key']);
            assert.equal((await request(url, { pathname: '/api/state', key: false, headers: { 'x-rw-key': `${key.slice(0, -1)}${key.endsWith('x') ? 'y' : 'x'}` } })).status, 403);
            assert.equal((await request(url, { pathname: '/api/state', key: false, headers: { 'x-rw-key': key.slice(1) } })).status, 403);
            assert.equal((await request(url, { method: 'POST', pathname: '/api/delivery', body: { ids: [] }, key: false })).status, 403, 'no message reaches the agent without the key');
            assert.equal((await request(url, { pathname: '/api/state' })).status, 200);
            assert.equal((await request(url, { pathname: '/', key: false })).status, 200, 'the page itself loads, then reads the key from its address');
            const stream = (path) => new Promise((resolve, reject) => {
                http.get({ host: '127.0.0.1', port: url.port, path }, (res) => {
                    resolve(res.statusCode);
                    res.destroy();
                }).on('error', reject);
            });
            assert.equal(await stream('/api/events'), 403);
            assert.equal(await stream('/api/events?k=wrong'), 403);
            assert.equal(await stream(`/api/events?k=${key}`), 200);
            assert.equal(await stream(`/api/state?k=${key}`), 403, 'only the event stream takes the key in its address');
        } finally {
            await server.stop();
        }
    });
});

describe('static files', () => {
    it('serves every UI module, so no import fails in the page', async () => {
        const { STATIC_FILES } = await import('../lib/server.mjs');
        const uiDir = fileURLToPath(new URL('../ui/', import.meta.url));
        const modules = (await fs.readdir(uiDir)).filter((name) => name.endsWith('.mjs'));
        const missing = modules.filter((name) => !Object.prototype.hasOwnProperty.call(STATIC_FILES, `/ui/${name}`));
        assert.deepEqual(missing, []);
    });
});

describe('a canvas that shows no session', () => {
    const MISSING = '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-state.json';
    const REQUEST = "RPI canvas 3WF0: connect this canvas to this conversation's RPI session.";

    async function setupNone(name, { deliver } = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const sent = [];
        let source = { kind: 'none', reason: 'missing-session', detail: MISSING };
        let sessionId = '';
        let clock = Date.parse('2026-10-27T15:00:00.000Z');
        const server = createCanvasServer({
            store,
            getSessionId: () => sessionId,
            getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
            getSource: () => source,
            now: () => new Date(clock).toISOString(),
            deliver: deliver ?? (async (request) => {
                sent.push(request);
            }),
            showSample: async () => {
                const session = await store.create(buildScenario('research'));
                sessionId = session.id;
                source = { kind: 'sample', stage: 'research' };
                return { sessionId };
            },
        });
        const url = new URL(await server.start());
        return { store, server, url, sent, advance: (ms) => { clock += ms; } };
    }

    it('reports not connected with the reason, the request, and whether the agent can be asked', async () => {
        const { server, url, store } = await setupNone('none-state');
        const state = await request(url, { pathname: '/api/state' });
        assert.equal(state.status, 200);
        assert.deepEqual([state.json.connected, state.json.notConnected, state.json.canvas.handle, state.json.session],
            [false, { reason: 'missing-session', detail: MISSING, request: REQUEST, canAsk: true }, '3WF0', undefined]);
        for (const [method, pathname, body] of [['POST', '/api/feedback', { kind: 'comment', text: 'x' }], ['POST', '/api/delivery/preview', {}]]) {
            const refused = await request(url, { method, pathname, body });
            assert.deepEqual([refused.status, refused.json.error.code], [409, 'not_connected'], pathname);
        }
        await server.stop();
        store.close();
    });

    it('opens the event stream without a session', async () => {
        const { server, url, store } = await setupNone('none-events');
        try {
            const frames = await new Promise((resolve, reject) => {
                const req = http.get({ host: '127.0.0.1', port: url.port, path: `/api/events?k=${url.searchParams.get('k')}` }, (res) => {
                    let text = '';
                    res.setEncoding('utf8');
                    res.on('data', (chunk) => {
                        text += chunk;
                        if (/event: (revision|error)\ndata: .*\n\n/.test(text)) {
                            req.destroy();
                            resolve(text);
                        }
                    });
                });
                req.on('error', (error) => (error.code === 'ECONNRESET' ? null : reject(error)));
            });
            assert.match(frames, /event: revision\ndata: \{"revision":0\}/, 'the page listens for the agent to connect the canvas');
            assert.doesNotMatch(frames, /event: error/);
        } finally {
            await server.stop();
            store.close();
        }
    });

    it('asks the agent with fixed text, then waits before asking again', async () => {
        const { server, url, store, sent, advance } = await setupNone('none-ask');
        const first = await request(url, { method: 'POST', pathname: '/api/connect-request', body: { prompt: 'ignored' } });
        assert.deepEqual([first.status, first.json.sent], [200, true]);
        assert.equal(sent[0].displayPrompt, REQUEST, 'the page cannot change the text');
        assert.match(sent[0].prompt, /"rpi-workflow-demo"/);
        assert.match(sent[0].prompt, /show_task/);
        const again = await request(url, { method: 'POST', pathname: '/api/connect-request', body: {} });
        assert.deepEqual([again.status, again.json.error.code], [429, 'too_soon']);
        advance(30000);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/connect-request', body: {} })).status, 200);
        assert.equal(sent.length, 2);
        await server.stop();
        store.close();
    });

    it('lets the person try again at once when the message could not be sent', async () => {
        const { server, url, store } = await setupNone('none-ask-fails', { deliver: async () => { throw new ModelError('delivery_unavailable', 'This host cannot take messages from the canvas.'); } });
        for (let i = 0; i < 2; i += 1) {
            const failed = await request(url, { method: 'POST', pathname: '/api/connect-request', body: {} });
            assert.deepEqual([failed.status, failed.json.error.code], [503, 'delivery_unavailable']);
        }
        await server.stop();
        store.close();
    });

    it('shows the sample on request, and a connected canvas refuses another ask', async () => {
        const { server, url, store } = await setupNone('none-sample');
        assert.equal((await request(url, { method: 'POST', pathname: '/api/sample', body: {} })).status, 200);
        const state = await request(url, { pathname: '/api/state' });
        assert.deepEqual([state.json.connected, state.json.session.scenario.sample], [undefined, true]);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/connect-request', body: {} })).status, 409);
        await server.stop();
        store.close();
    });
});

describe('the picker and panels of a canvas that shows no session', () => {
    const OWN = '0c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
    const SESSION = 'c4d5e6f7-0a1b-4c2d-9e3f-4a5b6c7d8e9f';
    const UNKNOWN = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
    const NO_TRACKING = 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e';
    const NO_RPI = 'e6f7a8b9-0c1d-4e2f-8a3b-4c5d6e7f8a9b';
    const BROKEN = 'f7a8b9c0-1d2e-4f3a-9b4c-5d6e7f8a9b0c';
    const LISTED = [{ sessionId: SESSION, name: 'Offline trail maps', repository: 'microsoft/trails', branch: 'main', mine: true, own: false, live: false, task: { taskId: ROOT_TASK, title: 'Offline trail maps', phase: 'followup', status: 'completed', statePath: PATHS.rootState }, problem: null }];
    const notConnectedSource = { kind: 'none', reason: 'no-input', detail: null };

    /** A canvas that shows no session; `deps` adds or replaces the picker's and the panel's dependencies. */
    async function unconnected(name, deps = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const server = createCanvasServer({
            store,
            getSessionId: () => '',
            getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
            getSource: () => notConnectedSource,
            deliver: async () => {},
            ...deps,
        });
        const url = new URL(await server.start());
        return { store, server, url };
    }

    it('lists the Copilot sessions while the canvas is not connected, and reads them only on request', async () => {
        const calls = [];
        const { server, url, store } = await unconnected('picker-list', {
            listCopilotSessions: async () => {
                calls.push('list');
                return { sessions: LISTED, skipped: 2 };
            },
        });
        assert.equal((await request(url, { pathname: '/api/state' })).json.connected, false);
        assert.deepEqual(calls, [], 'the state read lists no sessions');
        const listed = await request(url, { pathname: '/api/copilot-sessions' });
        assert.deepEqual([listed.status, listed.json], [200, { sessions: LISTED, skipped: 2 }]);
        assert.deepEqual(calls, ['list']);
        await server.stop();
        store.close();
    });

    it('answers a listing or a show that the canvas cannot make with not found, and refuses a body that is not a session ID', async () => {
        const { server, url, store } = await unconnected('picker-absent');
        assert.equal((await request(url, { pathname: '/api/copilot-sessions' })).status, 404);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/show-session', body: { session: SESSION } })).status, 404);
        for (const body of [{}, { session: 'not-a-session' }, { session: 42 }, { session: `${SESSION}/..` }]) {
            const refused = await request(url, { method: 'POST', pathname: '/api/show-session', body });
            assert.deepEqual([refused.status, refused.json.error.code], [400, 'invalid_input'], JSON.stringify(body));
        }
        await server.stop();
        store.close();
    });

    it('shows a session from its ID in any letter case, and answers each session error with its code and message', async () => {
        const shown = [];
        const failures = new Map([
            [UNKNOWN, [404, 'session_not_found', new ModelError('session_not_found', `No Copilot session ${UNKNOWN} was found.`)]],
            [NO_TRACKING, [409, 'session_no_tracking', new ModelError('session_no_tracking', `Copilot session ${NO_TRACKING} has no .copilot-tracking folder.`)]],
            [NO_RPI, [404, 'source_not_found', new ModelError('source_not_found', 'No RPI session state was found.')]],
            [BROKEN, [500, 'internal_error', new Error('disk failure')]],
        ]);
        const { server, url, store } = await unconnected('picker-show', {
            showSession: async (session) => {
                shown.push(session);
                if (failures.has(session)) throw failures.get(session)[2];
                return { sessionId: session };
            },
        });
        const ok = await request(url, { method: 'POST', pathname: '/api/show-session', body: { session: SESSION.toUpperCase() } });
        assert.deepEqual([ok.status, ok.json], [200, { sessionId: SESSION }]);
        assert.deepEqual(shown, [SESSION], 'the session is passed in lowercase');
        for (const [session, [status, code, error]] of failures) {
            const failed = await request(url, { method: 'POST', pathname: '/api/show-session', body: { session } });
            assert.deepEqual([failed.status, failed.json.error.code], [status, code], session);
            if (error instanceof ModelError) assert.equal(failed.json.error.message, error.message);
        }
        await server.stop();
        store.close();
    });

    it('binds the canvas to the session\'s current task as show_task does, and names the session the page shows', async () => {
        const scratch = await scratchFolder('picker-bind');
        try {
            const stateRoot = path.join(scratch, 'session-state');
            const repo = await writeFixtureWorkspace(path.join(scratch, 'trails'));
            await fs.mkdir(path.join(stateRoot, SESSION), { recursive: true });
            await fs.writeFile(path.join(stateRoot, SESSION, 'workspace.yaml'), `cwd: ${repo}\ngit_root: ${repo}\n`);
            const store = createStore({ root: path.join(tmp, 'picker-bind-store'), pollMs: 20 });
            const sources = createSourceController({ store, sessionRoot: () => stateRoot, ownSessionId: () => OWN, intervalMs: 60000 });
            const record = { instanceId: 'rpi-workflow-demo', sessionId: '', source: notConnectedSource, server: null };
            const server = createCanvasServer({
                store,
                getSessionId: () => record.sessionId,
                getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
                getSource: () => record.source,
                getJoinedSessionId: () => OWN,
                deliver: async () => {},
                listCopilotSessions: async () => ({ sessions: [], skipped: 0 }),
                showSession: (session) => sources.show(record, { session }, { candidates: [] }),
            });
            record.server = server;
            const url = new URL(await server.start());
            const shown = await request(url, { method: 'POST', pathname: '/api/show-session', body: { session: SESSION } });
            assert.deepEqual(shown.json, { sessionId: record.sessionId }, 'the page refreshes from the document it now shows');
            assert.deepEqual([record.source.kind, record.source.boundSession, record.source.taskId], ['rpi', SESSION, ROOT_TASK]);
            const state = await request(url, { pathname: '/api/state' });
            assert.deepEqual([state.json.shownSession, state.json.session.task.id], [SESSION, ROOT_TASK]);
            await sources.settled(record);
            const remembered = await store.loadInstance('rpi-workflow-demo');
            assert.deepEqual([remembered.kind, remembered.state, remembered.session], ['rpi', PATHS.rootState, SESSION], 'the instance returns to the session when the host reopens it');
            await server.stop();
            store.close();
        } finally {
            await fs.rm(scratch, { recursive: true, force: true });
        }
    });

    it('opens a session\'s canvas in a new panel while the canvas shows no session', async () => {
        const opened = [];
        const { server, url, store } = await unconnected('picker-panel', {
            resolveSession: async (session) => {
                if (session !== SESSION) throw new Error(`No Copilot session ${session} was found.`);
                return { root: FIXTURE_ROOT, tracking: path.join(FIXTURE_ROOT, '.copilot-tracking') };
            },
            openPanel: async ({ session }) => {
                opened.push(session);
                return { outcome: 'opened', instanceId: panelInstanceId(session) };
            },
        });
        const panel = await request(url, { method: 'POST', pathname: '/api/open-panel', body: { session: SESSION } });
        assert.deepEqual([panel.status, panel.json], [200, { outcome: 'opened', instanceId: panelInstanceId(SESSION) }]);
        assert.deepEqual(opened, [SESSION]);
        await server.stop();
        store.close();
    });

    it('tells the page that the picker\'s sessions changed, through a reload event that carries the flag', async () => {
        const { server, url, store } = await unconnected('picker-reload');
        const frame = await new Promise((resolve, reject) => {
            let text = '';
            let notified = false;
            const req = http.get({ host: '127.0.0.1', port: url.port, path: `/api/events?k=${url.searchParams.get('k')}` }, (res) => {
                res.setEncoding('utf8');
                res.on('data', (chunk) => {
                    text += chunk;
                    if (!notified && text.includes('event: revision')) {
                        notified = true;
                        server.notifyReload({ sessions: true });
                    }
                    if (text.includes('event: reload')) {
                        req.destroy();
                        resolve(text.slice(text.indexOf('event: reload')));
                    }
                });
            });
            req.on('error', (error) => (error.code === 'ECONNRESET' ? null : reject(error)));
        });
        assert.match(frame, /^event: reload\ndata: \{"at":"[^"]+","sessions":true\}/);
        await server.stop();
        store.close();
    });
});

describe('opening a session in a new panel', () => {
    const PROVIDER = 'project:rpi-workflow';
    const SESSION = 'c4d5e6f7-0a1b-4c2d-9e3f-4a5b6c7d8e9f';
    const OTHER_SESSION = 'd5e6f7a8-1b2c-4d3e-8f4a-5b6c7d8e9f0a';
    const UNKNOWN = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
    const INSTANCE = 'rpi-c4d5e6f7';
    const NOW = Date.parse('2026-01-15T12:00:00.000Z');
    const OPEN = { session: SESSION };
    const FIXED_LINE = `RPI canvas K7QF: open an RPI Workflow canvas for session ${SESSION}.`;

    /**
     * A canvas that opens panels through `rpc` as the joined session does, or has no opener when `opener` is false.
     * Only SESSION and OTHER_SESSION have a workspace that reads; any other session is not found. Its clock is the
     * test's, so the ask interval can be checked.
     */
    async function panelSetup(name, { rpc, deliver, opener = true } = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const session = await store.create({ ...rootSession().session, id: storeIdFor(ROOT_TASK, FIXTURE_ROOT) });
        const sent = [];
        let clock = NOW;
        const server = createCanvasServer({
            store,
            getSessionId: () => session.id,
            getCanvas: () => ({ handle: 'K7QF', instanceId: 'rpi-workflow-demo' }),
            getSource: () => ({ kind: 'rpi', workspace: { root: FIXTURE_ROOT }, follow: { paused: false } }),
            getExtensionId: () => PROVIDER,
            resolveSession: async (sessionId) => {
                if (sessionId !== SESSION && sessionId !== OTHER_SESSION) throw new Error(`No Copilot session ${sessionId} was found.`);
                return { root: FIXTURE_ROOT, tracking: path.join(FIXTURE_ROOT, '.copilot-tracking') };
            },
            ...(opener ? { openPanel: createPanelOpener({ rpc: () => rpc, extensionId: () => PROVIDER, canvasId: CANVAS_ID }) } : {}),
            deliver: deliver ?? (async (message) => {
                sent.push(message);
            }),
            now: () => new Date(clock).toISOString(),
        });
        const url = new URL(await server.start());
        return { store, server, url, sent, advance: (ms) => { clock += ms; } };
    }

    const askPanel = (url, body = OPEN) => request(url, { method: 'POST', pathname: '/api/open-panel', body });

    it('opens the session\'s canvas in a new panel of the host, bound to the session, and reports it opened', async () => {
        const host = hostCanvas();
        const { server, url, store, sent } = await panelSetup('panel-opened', { rpc: host });
        const opened = await askPanel(url);
        assert.deepEqual([opened.status, opened.json], [200, { outcome: 'opened', instanceId: INSTANCE }]);
        assert.deepEqual(host.opens, [{ extensionId: PROVIDER, canvasId: 'hve-core-rpi-workflow', instanceId: INSTANCE, input: { session: SESSION } }]);
        assert.deepEqual(sent, [], 'no message goes to the agent when the host opens the panel');
        await server.stop();
        store.close();
    });

    it('reports focused, and opens nothing new, when the host already lists that panel open', async () => {
        const host = hostCanvas({ listed: [{ instanceId: INSTANCE, extensionId: PROVIDER, canvasId: 'hve-core-rpi-workflow' }] });
        const { server, url, store } = await panelSetup('panel-focused', { rpc: host });
        const focused = await askPanel(url);
        assert.deepEqual([focused.status, focused.json], [200, { outcome: 'focused', instanceId: INSTANCE }]);
        assert.equal(host.opens.length, 1, 'the host focuses the panel it already has for that instance');
        await server.stop();
        store.close();
    });

    it('still opens the panel when the host cannot list its canvases', async () => {
        const host = hostCanvas({ listError: new Error('Listing is not available.') });
        const { server, url, store } = await panelSetup('panel-no-list', { rpc: host });
        assert.equal((await askPanel(url)).json.outcome, 'opened');
        await server.stop();
        store.close();
    });

    it('asks the agent with one fixed line when the host refuses to open the panel, and says it did', async () => {
        const host = hostCanvas({ openError: new Error('Canvases cannot open from this session.') });
        const { server, url, store, sent } = await panelSetup('panel-refused', { rpc: host });
        const asked = await askPanel(url);
        assert.deepEqual(asked.json, { outcome: 'asked', retryAfterMs: 30000 });
        assert.equal(sent.length, 1);
        assert.equal(sent[0].displayPrompt, FIXED_LINE, 'the page cannot change the text');
        assert.ok(sent[0].prompt.startsWith(FIXED_LINE));
        assert.ok(sent[0].prompt.includes(`canvasId "hve-core-rpi-workflow", instanceId "${INSTANCE}", input ${JSON.stringify({ session: SESSION })}, extensionId "${PROVIDER}"`), sent[0].prompt);
        assert.equal(sent[0].mode, undefined, 'the message waits for the agent\'s turn, as Ask the agent does');
        await server.stop();
        store.close();
    });

    it('asks the agent when the host has no canvas API, or the canvas has no panel opener', async () => {
        const noApi = await panelSetup('panel-no-api', { rpc: {} });
        assert.equal((await askPanel(noApi.url)).json.outcome, 'asked');
        const noOpener = await panelSetup('panel-no-opener', { opener: false });
        assert.equal((await askPanel(noOpener.url)).json.outcome, 'asked');
        assert.equal(noOpener.sent.length, 1);
        await noApi.server.stop();
        noApi.store.close();
        await noOpener.server.stop();
        noOpener.store.close();
    });

    it('waits 30 seconds between asks, and says how long is left', async () => {
        const { server, url, store, sent, advance } = await panelSetup('panel-wait', { rpc: {} });
        assert.deepEqual((await askPanel(url)).json, { outcome: 'asked', retryAfterMs: 30000 });
        advance(10000);
        assert.deepEqual((await askPanel(url)).json, { outcome: 'wait', retryAfterMs: 20000, sameSession: true });
        assert.equal(sent.length, 1, 'the agent is asked once in the interval');
        advance(20000);
        assert.deepEqual((await askPanel(url)).json, { outcome: 'asked', retryAfterMs: 30000 });
        assert.equal(sent.length, 2);
        await server.stop();
        store.close();
    });

    it('keeps one wait for every session: a wait for a different session names that it is not the session asked about', async () => {
        const { server, url, store, sent, advance } = await panelSetup('panel-two-sessions', { rpc: {} });
        const other = { session: OTHER_SESSION };
        assert.deepEqual((await askPanel(url)).json, { outcome: 'asked', retryAfterMs: 30000 }, 'the first session is asked');
        advance(5000);
        assert.deepEqual((await askPanel(url, other)).json, { outcome: 'wait', retryAfterMs: 25000, sameSession: false }, 'the second session waits on the same clock');
        assert.deepEqual((await askPanel(url)).json, { outcome: 'wait', retryAfterMs: 25000, sameSession: true }, 'the first session is still the one asked about');
        assert.equal(sent.length, 1, 'the agent is not asked twice in the interval');
        advance(25000);
        assert.deepEqual((await askPanel(url, other)).json, { outcome: 'asked', retryAfterMs: 30000 });
        assert.equal(sent.length, 2);
        assert.ok(sent[1].prompt.includes(`instanceId "${panelInstanceId(OTHER_SESSION)}"`), sent[1].prompt);
        await server.stop();
        store.close();
    });

    it('does not hold back panels by the ask interval, since opening a panel sends nothing to the agent', async () => {
        const host = hostCanvas();
        const { server, url, store, sent } = await panelSetup('panel-no-wait', { rpc: host });
        assert.equal((await askPanel(url)).json.outcome, 'opened');
        assert.equal((await askPanel(url)).json.outcome, 'focused', 'the second request finds the panel listed open');
        assert.deepEqual(sent, []);
        await server.stop();
        store.close();
    });

    it('reports a failed message with its reason, and lets the next request ask at once', async () => {
        let failing = true;
        const { server, url, store, sent } = await panelSetup('panel-send-fails', {
            rpc: {},
            deliver: async (message) => {
                if (failing) throw new ModelError('delivery_unavailable', 'This host cannot take messages from the canvas.');
                sent.push(message);
            },
        });
        assert.deepEqual((await askPanel(url)).json, { outcome: 'failed', reason: 'This host cannot take messages from the canvas.' });
        failing = false;
        assert.deepEqual((await askPanel(url)).json, { outcome: 'asked', retryAfterMs: 30000 });
        assert.equal(sent.length, 1);
        await server.stop();
        store.close();
    });

    it('refuses a session that is not a session ID or does not resolve, and opens nothing', async () => {
        const host = hostCanvas();
        const { server, url, store, sent } = await panelSetup('panel-refused-session', { rpc: host });
        for (const [body, status, code] of [[{ session: UNKNOWN }, 404, 'not_found'], [{ session: 42 }, 400, 'invalid_input'], [{ session: 'not-a-session' }, 400, 'invalid_input'], [{}, 400, 'invalid_input']]) {
            const refused = await askPanel(url, body);
            assert.deepEqual([refused.status, refused.json.error.code], [status, code], JSON.stringify(body));
        }
        assert.deepEqual([host.opens, sent], [[], []]);
        await server.stop();
        store.close();
    });

    it('matches the session ID whatever its letter case, and opens it under the lowercase ID', async () => {
        const host = hostCanvas();
        const { server, url, store } = await panelSetup('panel-case', { rpc: host });
        assert.equal((await askPanel(url, { session: SESSION.toUpperCase() })).json.outcome, 'opened');
        assert.equal(host.opens[0].input.session, SESSION);
        assert.equal(host.opens[0].instanceId, INSTANCE);
        await server.stop();
        store.close();
    });
});
