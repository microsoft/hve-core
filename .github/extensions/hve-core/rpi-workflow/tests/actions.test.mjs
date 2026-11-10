// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { ACTION_DEFINITIONS, ACTION_GROUPS, createActionHandlers } from '../lib/actions.mjs';
import { createDelivery } from '../lib/delivery.mjs';
import { createInstanceRegistry } from '../lib/lifecycle.mjs';
import { createFeedback, ModelError, queueForAgent, suggestEdit, upsertDecision } from '../lib/model.mjs';
import { buildScenario, SCENARIO_ID } from '../lib/scenario.mjs';
import { createSourceController } from '../lib/sources.mjs';
import { importIntoStore, loadTask, resolveWorkspace, storeIdFor } from '../lib/source/workspace.mjs';
import { createStore } from '../lib/store.mjs';
import { CHILD_TASK, PATHS, ROOT_STATE, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';
import { scratchFolder } from './helpers/scratch.mjs';

class FakeCanvasError extends Error {
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}
const makeError = (code, message) => new FakeCanvasError(code, message);

let tmp;
before(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-actions-'));
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

async function setup(name, stage = 'research') {
    const store = createStore({ root: path.join(tmp, name) });
    await store.create(buildScenario(stage));
    const focusCalls = [];
    const server = { url: 'http://127.0.0.1:1/?k=test', address: 'http://127.0.0.1:1/', editor: { name: 'VS Code' }, clientInfo: null, streamClients: 1, focus: (request) => { focusCalls.push(request); return { delivered: true }; }, notifyReload: () => {} };
    const handlers = createActionHandlers({ getInstance: (id) => (id === 'i1' ? { server, sessionId: SCENARIO_ID, instanceId: 'i1', handle: 'K7QF' } : undefined), store, makeError });
    const call = (name, input) => handlers[name]({ instanceId: 'i1', input });
    return { store, handlers, call, focusCalls };
}

async function code(promise) {
    try {
        await promise;
    } catch (error) {
        return error.code;
    }
    assert.fail('expected an error');
}

describe('definitions', () => {
    it('declares every action with a handler, an object schema, and a legal name', async () => {
        const { handlers, store } = await setup('defs');
        const grouped = Object.values(ACTION_GROUPS).flat().sort();
        assert.deepEqual(ACTION_DEFINITIONS.map((d) => d.name).sort(), grouped);
        for (const definition of ACTION_DEFINITIONS) {
            assert.equal(typeof handlers[definition.name], 'function', definition.name);
            assert.ok(!definition.name.startsWith('canvas.'), definition.name);
            assert.equal(definition.inputSchema.type, 'object', definition.name);
            assert.ok(definition.description.length > 20, definition.name);
        }
        store.close();
    });
});

describe('handlers', () => {
    it('requires an open instance and object input', async () => {
        const { handlers, call, store } = await setup('guards');
        assert.equal(await code(handlers.get_state({ instanceId: 'missing' })), 'instance_not_found');
        assert.equal(await code(call('get_state', [1, 2])), 'invalid_input');
        store.close();
    });

    it('reports state, loads stages, and protects user changes', async () => {
        const { call, store } = await setup('state');
        const state = await call('get_state', {});
        assert.deepEqual(state.canvas, { handle: 'K7QF', instanceId: 'i1' });
        assert.equal(state.url, 'http://127.0.0.1:1/', 'get_state reports the address without the key');
        assert.deepEqual(state.editor, { name: 'VS Code' });
        assert.deepEqual((await call('get_state', { detail: 'full' })).canvas, { handle: 'K7QF', instanceId: 'i1' });
        assert.equal(state.activePhase, 'research');
        assert.ok(Array.isArray(state.pendingFeedback));
        assert.ok(state.needsUserInput.some((d) => d.id === 'D2'));
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'comment', text: 'mine' }, new Date().toISOString()), { by: 'user' });
        assert.equal(await code(call('load_scenario', { stage: 'plan' })), 'scenario_exists');
        const loaded = await call('load_scenario', { stage: 'plan', replace: true });
        assert.equal(loaded.activePhase, 'plan');
        assert.equal(await code(call('load_scenario', { stage: 'ship' })), 'invalid_input');
        store.close();
    });

    it('takes feedback and records read-backs', async () => {
        const { call, store } = await setup('feedback');
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both.' }, new Date().toISOString()), { by: 'user' });
        const taken = await call('take_feedback', {});
        assert.equal(taken.items.length, 1);
        assert.equal(taken.items[0].optionLabel, 'Merge per field; queue same-field conflicts for review');
        const again = await call('take_feedback', {});
        assert.deepEqual(again.items.map((item) => [item.id, item.alreadySent]), [[taken.items[0].id, true]], 'a sent item without a read-back comes back, marked');
        assert.match(again.note, /alreadySent also reached you as a chat message: handle each once, by its ID\./);
        assert.equal((await store.load(SCENARIO_ID)).feedback.find((item) => item.id === taken.items[0].id).state, 'sent', 'and stays as it was');
        await call('record_interpretation', { feedbackId: taken.items[0].id, text: 'Queue same-field conflicts.', effect: 'Adds P02-T03' });
        assert.deepEqual((await call('take_feedback', {})).items, [], 'once read back, it does not come back');
        const state = await call('get_state', {});
        assert.equal((await store.load(SCENARIO_ID)).feedback.find((item) => item.id === taken.items[0].id).state, 'applied', 'a read-back applies the item');
        assert.ok(!state.readBackNotApplied.some((item) => item.id === taken.items[0].id));
        assert.equal(await code(call('record_interpretation', { feedbackId: 'FB-999', text: 'x' })), 'not_found');
        await store.update(SCENARIO_ID, (s) => suggestEdit(s, { sectionId: 'research-summary', markdown: 'Shorter summary', baseRevision: s.sections['research-summary'].revision }, new Date().toISOString()), { by: 'user' });
        const pending = await call('take_feedback', {});
        const edit = pending.items.find((item) => item.kind === 'edit');
        assert.equal(edit.section.markdown, 'Shorter summary');
        assert.match(edit.section.diff, /\+Shorter summary/);
        assert.equal(edit.section.revision, (await store.load(SCENARIO_ID)).sections['research-summary'].revision, 'the section itself is unchanged');
        store.close();
    });

    it('takes only what the user queued at a checkpoint, and every unsent item on request', async () => {
        const { call, store } = await setup('checkpoint');
        const now = () => new Date().toISOString();
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'comment', text: 'Not queued' }, now()), { by: 'user' });
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'comment', text: 'Queued' }, now()), { by: 'user' });
        const [kept, queued] = (await store.load(SCENARIO_ID)).feedback.slice(-2).map((item) => item.id);
        await store.update(SCENARIO_ID, (s) => queueForAgent(s, [queued], now()), { by: 'user' });
        assert.deepEqual((await call('get_state', {})).pendingFeedback.filter((item) => item.queuedForAgent).map((item) => item.id), [queued], 'get_state names what waits for a checkpoint');
        const atCheckpoint = await call('take_feedback', { checkpoint: true });
        assert.deepEqual(atCheckpoint.items.map((item) => item.id), [queued]);
        assert.equal((await store.load(SCENARIO_ID)).feedback.find((item) => item.id === kept).state, 'queued', 'items not queued stay with the user');
        const next = await call('take_feedback', { checkpoint: true });
        assert.deepEqual(next.items.map((item) => [item.id, item.alreadySent === true]), [[queued, true]], 'only the unread item comes back');
        const all = await call('take_feedback', {});
        assert.deepEqual(all.items.filter((item) => !item.alreadySent).map((item) => item.id), [kept], 'on request, the rest come too');
        await call('record_interpretation', { feedbackId: queued, text: 'Read.', applied: true });
        await call('record_interpretation', { feedbackId: kept, text: 'Read.', applied: true });
        assert.match((await call('take_feedback', { checkpoint: true })).note, /^Nothing is queued for you, and nothing sent to you waits for a read-back\.$/);
        assert.equal(await code(call('take_feedback', { checkpoint: 'yes' })), 'invalid_input');
        store.close();
    });

    it('drives decisions, tasks, changes, discoveries, findings, sections, lanes, focus, and appearance', async () => {
        const { call, store, focusCalls } = await setup('drive', 'implement');
        const decision = await call('upsert_decision', { owner: 'agent', phase: 'implement', title: 'Use a version field', chosen: 'a', options: [{ id: 'a', label: 'Version field' }, { id: 'b', label: 'Strong ETags' }], anchor: { rowId: 'DS-004' } });
        assert.equal(decision.decision.status, 'decided');
        assert.equal((await call('update_task', { taskId: 'P02-T02', status: 'done' })).task.status, 'done');
        assert.match((await call('record_change', { taskId: 'P02-T02', title: 'Conditional writes', behavior: 'Writes send If-Match.', files: [{ path: 'src/a.ts', kind: 'modified', additions: 3, deletions: 1 }], validation: [{ check: 'npm test', status: 'passed' }] })).id, /^CH-\d{3}$/);
        assert.match((await call('record_discovery', { kind: 'follow-up', title: 'Later', detail: 'Not now.' })).id, /^DS-\d{3}$/);
        await call('record_activity', { text: 'Ran tests', kind: 'test' });
        assert.equal(await code(call('record_activity', { text: 'x', kind: 'dance' })), 'invalid_input');
        await call('update_session', { activePhase: 'review', phaseStatus: { implement: 'done' } });
        assert.equal((await call('update_finding', { id: 'RV-010', severity: 'low', title: 'Typo', decision: 'accepted', rationale: 'Trivial' })).finding.decision, 'accepted');
        assert.equal((await call('update_section', { sectionId: 'changes-summary', markdown: 'Updated by the agent' })).section.revision, 2);
        assert.equal(await code(call('update_section', { sectionId: 'nope', markdown: 'x' })), 'not_found');
        assert.equal((await call('track_research_lane', { question: 'More?', status: 'running' })).lane.id, 'L3');
        await call('focus_item', { itemId: 'D6', phase: 'implement' });
        assert.deepEqual(focusCalls[0], { phase: 'implement', itemId: 'D6' });
        assert.equal(await code(call('focus_item', { phase: 'ship' })), 'invalid_input');
        assert.deepEqual((await call('set_appearance', { theme: 'dark' })).preferences, { theme: 'dark', contrast: 'standard' });
        assert.equal(await code(call('set_appearance', { theme: 'neon' })), 'invalid_input');
        store.close();
    });
});

describe('delivery adapter', () => {
    it('enqueues one message whose prompt is the reviewed text', async () => {
        const calls = [];
        const deliver = createDelivery({ getSession: () => ({ send: async (options) => calls.push(options) }) });
        await deliver({ prompt: 'Full text', displayPrompt: 'RPI canvas K7QF sent 1 item: 1 comment.', ids: ['FB-001'] });
        assert.deepEqual(calls, [{ prompt: 'Full text', displayPrompt: 'RPI canvas K7QF sent 1 item: 1 comment.', mode: 'enqueue' }]);
    });

    it('sends now when asked, and returns the chat message ID', async () => {
        const calls = [];
        const deliver = createDelivery({ getSession: () => ({ send: async (options) => {
            calls.push(options);
            return 'msg-42';
        } }) });
        assert.deepEqual(await deliver({ prompt: 'Now', displayPrompt: 'd', ids: ['FB-001'], mode: 'immediate' }), { messageId: 'msg-42' });
        assert.equal(calls[0].mode, 'immediate');
        const quiet = createDelivery({ getSession: () => ({ send: async () => undefined }) });
        assert.deepEqual(await quiet({ prompt: 'x', displayPrompt: 'x', ids: [] }), { messageId: null }, 'a host that returns no ID records none');
    });

    it('reports hosts that cannot take messages, pointing to take_feedback', async () => {
        const none = createDelivery({ getSession: () => null });
        await assert.rejects(none({ prompt: 'x', displayPrompt: 'x', ids: [] }), (error) => error instanceof ModelError && error.code === 'delivery_unavailable' && /take_feedback/.test(error.message));
        const noSend = createDelivery({ getSession: () => ({ rpc: {} }) });
        await assert.rejects(noSend({ prompt: 'x', displayPrompt: 'x', ids: [] }), (error) => error.code === 'delivery_unavailable');
    });
});

describe('instance registry', () => {
    function fakeServer(log) {
        let listening = false;
        let release;
        const gate = new Promise((resolve) => {
            release = resolve;
        });
        return {
            release,
            get listening() {
                return listening;
            },
            async start() {
                log.push('start');
                await gate;
                listening = true;
                return 'http://127.0.0.1:1/';
            },
            async stop() {
                log.push('stop');
                listening = false;
            },
        };
    }

    it('shares one start across overlapping opens', async () => {
        const log = [];
        const servers = [];
        const registry = createInstanceRegistry({ makeError, createServer: () => {
            const server = fakeServer(log);
            servers.push(server);
            return server;
        } });
        const a = registry.open({ instanceId: 'x', sessionId: 's' });
        const b = registry.open({ instanceId: 'x', sessionId: 's' });
        servers[0].release();
        assert.equal(await a, await b);
        assert.equal(servers.length, 1);
        assert.equal(registry.size, 1);
    });

    it('stops a server whose start finishes after close', async () => {
        const log = [];
        const servers = [];
        const registry = createInstanceRegistry({ makeError, createServer: () => {
            const server = fakeServer(log);
            servers.push(server);
            return server;
        } });
        const opening = registry.open({ instanceId: 'y', sessionId: 's' });
        const closing = registry.close('y');
        servers[0].release();
        await closing;
        await assert.rejects(opening, (error) => error.code === 'instance_closed');
        assert.equal(registry.size, 0);
        assert.ok(log.includes('stop'));
        const reopened = registry.open({ instanceId: 'y', sessionId: 's' });
        servers[1].release();
        assert.ok(await reopened);
        assert.equal(servers.length, 2);
    });

    it('starts no server when the canvas closes while its session is prepared', async () => {
        const log = [];
        const servers = [];
        const registry = createInstanceRegistry({ makeError, createServer: () => {
            const server = fakeServer(log);
            servers.push(server);
            return server;
        } });
        let finish;
        const preparing = new Promise((resolve) => {
            finish = resolve;
        });
        const opening = registry.open({ instanceId: 'z', sessionId: 's', prepare: () => preparing });
        await registry.close('z');
        finish();
        await assert.rejects(opening, (error) => error.code === 'instance_closed');
        assert.equal(servers.length, 0);
        assert.equal(registry.size, 0);
        const reopened = registry.open({ instanceId: 'z', sessionId: 's', prepare: async () => {} });
        await new Promise((resolve) => setImmediate(resolve));
        servers[0].release();
        assert.ok(await reopened);
        assert.equal(registry.size, 1);
    });
});

describe('linked sessions in get_state', () => {
    const COORD = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
    const CHILD = '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e';
    const WHEN = '2026-01-15T12:00:00.000Z';
    let scratch;
    let stateRoot;
    let coordRoot;
    let childRoot;
    let otherRoot;
    let store;
    let child;

    before(async () => {
        scratch = await scratchFolder('linked-actions');
        stateRoot = path.join(scratch, 'session-state');
        coordRoot = path.join(scratch, 'coordinator');
        childRoot = path.join(scratch, 'child');
        otherRoot = path.join(scratch, 'other');
        await fs.mkdir(stateRoot);
        for (const root of [coordRoot, childRoot, otherRoot]) await writeFixtureWorkspace(root);
        await fs.rm(path.join(coordRoot, PATHS.childState));
        for (const [id, root] of [[COORD, coordRoot], [CHILD, childRoot]]) {
            await fs.mkdir(path.join(stateRoot, id));
            await fs.writeFile(path.join(stateRoot, id, 'workspace.yaml'), `cwd: ${root}\n`);
        }
        await fs.writeFile(path.join(coordRoot, PATHS.rootState), JSON.stringify({ ...ROOT_STATE, child_tasks: [{ task_id: CHILD_TASK, task_slug: CHILD_TASK, state_path: PATHS.childState, session_id: CHILD }] }));
        store = createStore({ root: path.join(scratch, 'store') });
        child = await resolveWorkspace([childRoot]);
    });
    after(async () => {
        store.close();
        await fs.rm(scratch, { recursive: true, force: true });
    });

    /** An instance that shows the coordinator's current task, and the handlers that serve it. */
    async function coordinator() {
        const sources = createSourceController({ store, sessionRoot: () => stateRoot, ownSessionId: () => null, intervalMs: 60000 });
        const prepared = await sources.prepare({ session: COORD, task: 'current' });
        const instance = { instanceId: 'linked', handle: 'K7QF', sessionId: prepared.sessionId, source: prepared.source, server: { url: 'http://127.0.0.1:1/', address: null, clientInfo: null, streamClients: 0, editor: null, notifyReload: () => {} } };
        const handlers = createActionHandlers({ getInstance: (id) => (id === 'linked' ? instance : undefined), store, makeError });
        return { handlers, prepared };
    }

    it('lists each child task in another session with its session, phase, status, and no decisions until a canvas has read it', async () => {
        const { handlers } = await coordinator();
        const state = await handlers.get_state({ instanceId: 'linked', input: {} });
        assert.deepEqual(state.linkedSessions, [{ taskId: CHILD_TASK, sessionId: CHILD, sessionName: 'Offline trail maps', statePath: PATHS.childState, phase: 'followup', status: 'completed', decisionsWaiting: null }]);
        assert.deepEqual((await handlers.get_state({ instanceId: 'linked', input: { detail: 'full' } })).linkedSessions, state.linkedSessions);
        assert.deepEqual(state.otherTasks, [], 'the child is not a task of this session\'s feedback');
    });

    it('reads the decisions waiting from the child\'s own document, once a canvas has read it', async () => {
        const imported = await importIntoStore(store, await loadTask(child, PATHS.childState, WHEN), WHEN);
        await store.update(imported.session.id, (session) => upsertDecision(session, { owner: 'user', phase: 'plan', title: 'Pick a sync rule', question: 'Which sync rule should the maps use?', options: [{ label: 'Merge' }, { label: 'Replace' }] }, WHEN), { by: 'user' });
        const { handlers } = await coordinator();
        const [linked] = (await handlers.get_state({ instanceId: 'linked', input: {} })).linkedSessions;
        assert.ok(linked.decisionsWaiting.some((item) => item.title === 'Pick a sync rule'), JSON.stringify(linked.decisionsWaiting));
    });

    it('keys the child\'s document by its workspace, so the same task in another workspace is not read', async () => {
        const other = await resolveWorkspace([otherRoot]);
        assert.notEqual(storeIdFor(CHILD_TASK, other.root), storeIdFor(CHILD_TASK, child.root));
        const imported = await importIntoStore(store, await loadTask(other, PATHS.childState, WHEN), WHEN);
        await store.update(imported.session.id, (session) => upsertDecision(session, { owner: 'user', phase: 'plan', title: 'Other workspace decision', question: 'Which one?', options: [{ label: 'A' }] }, WHEN), { by: 'user' });
        const { handlers } = await coordinator();
        const [linked] = (await handlers.get_state({ instanceId: 'linked', input: {} })).linkedSessions;
        assert.ok(!linked.decisionsWaiting.some((item) => item.title === 'Other workspace decision'));
    });
});
