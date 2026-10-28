// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { agentEditSection, createFeedback, ModelError, recordActivity, takeFeedback, upsertDecision } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { clientInfoFrom, createCanvasServer, MAX_BODY, renderShell } from '../lib/server.mjs';
import { createStore } from '../lib/store.mjs';
import { CHILD_TASK, childSession, ROOT_TASK, rootSession } from './helpers/rpi-fixture.mjs';

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
        getCanvas: () => ({ handle: '3WF0', instanceId: 'rpi-workflow-demo' }),
        deliver: deliver ?? (async (request) => {
            sent.push(request);
        }),
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
        assert.equal((await request(url, { method: 'POST', pathname: '/api/checklist/share', body: { phase: 'research' } })).status, 404, 'reviews go with Review and send');
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
        const applied = await request(url, { method: 'POST', pathname: '/api/feedback/transition', body: { id: interpreted.id, to: 'applied' } });
        assert.equal(applied.json.item.state, 'applied');
        const stored = await store.load(session.id);
        assert.equal(stored.scenario.userChanges, 2);
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

    it('marks checklist items and keeps the pending review in step', async () => {
        const { server, url, store, session } = await setup('checklist');
        const marked = await request(url, { method: 'POST', pathname: '/api/checklist', body: { phase: 'research', itemId: 'R3', verdict: 'needs-work', note: 'Add a native-app option.' } });
        assert.equal(marked.status, 200);
        assert.equal(marked.json.item.verdict, 'needs-work');
        const pending = (await store.load(session.id)).feedback.filter((item) => item.kind === 'checklist' && item.state === 'queued');
        assert.equal(pending.length, 1);
        assert.match(pending[0].text, /Note: Add a native-app option\./);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/checklist', body: { phase: 'research', itemId: 'R3', verdict: null } })).status, 200);
        assert.equal((await store.load(session.id)).feedback.filter((item) => item.kind === 'checklist').length, 0);
        assert.equal((await request(url, { method: 'POST', pathname: '/api/checklist', body: { phase: 'research', itemId: 'R3', verdict: 'maybe' } })).status, 400);
        await server.stop();
        store.close();
    });

    it('sends exactly the reviewed text as one message, once, even after unrelated agent writes', async () => {
        const { server, url, store, sent, session } = await setup('delivery');
        const a = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'comment', text: 'First', target: { id: 'F1' } } });
        const b = await request(url, { method: 'POST', pathname: '/api/feedback', body: { kind: 'research-request', text: 'Second', target: { id: 'F4' } } });
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
        assert.equal(sent[0].displayPrompt, 'Start with F1.\n\nRPI canvas 3WF0 sent 2 items: 1 comment and 1 research request.');
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

    it('queues reviewed items for the agent without a message, keeps a note as context, and takes items back', async () => {
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
        assert.equal(byId(noteId).kind, 'context');
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
    async function sessionSetup(name, { fail = () => false, deliver } = {}) {
        const store = createStore({ root: path.join(tmp, name), pollMs: 20 });
        const parent = await store.create(rootSession().session);
        const child = await store.create(childSession().session);
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
            getSource: () => ({ kind: 'rpi', follow: { paused: false } }),
            deliver: deliver ?? (async (message) => {
                sent.push(message);
            }),
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
        const { store, server, url, sent, parent, child } = await sessionSetup('session-claim-fails', { fail: (id) => armed && id === 'rpi-trail-maps' });
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
            fail: (id) => marking && id === 'rpi-trail-maps',
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
        const uiDir = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'ui');
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
        for (const [method, pathname, body] of [['POST', '/api/feedback', { kind: 'comment', text: 'x' }], ['POST', '/api/delivery/preview', {}], ['POST', '/api/checklist', { phase: 'research', itemId: 'x', mark: 'good' }]]) {
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
