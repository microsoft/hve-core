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
import { createFeedback, editSection, ModelError } from '../lib/model.mjs';
import { buildScenario, SCENARIO_ID } from '../lib/scenario.mjs';
import { createStore } from '../lib/store.mjs';

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
    const server = { url: 'http://127.0.0.1:1/', clientInfo: null, streamClients: 1, focus: (request) => { focusCalls.push(request); return { delivered: true }; }, notifyReload: () => {} };
    const handlers = createActionHandlers({ getInstance: (id) => (id === 'i1' ? { server, sessionId: SCENARIO_ID } : undefined), store, makeError });
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
        assert.equal(state.activePhase, 'research');
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
        assert.deepEqual((await call('take_feedback', {})).items, []);
        await call('record_interpretation', { feedbackId: taken.items[0].id, text: 'Queue same-field conflicts.', effect: 'Adds P02-T03' });
        const state = await call('get_state', {});
        assert.ok(state.awaitingUserConfirmation.some((item) => item.id === taken.items[0].id));
        assert.equal(await code(call('record_interpretation', { feedbackId: 'FB-999', text: 'x' })), 'not_found');
        await store.update(SCENARIO_ID, (s) => editSection(s, { sectionId: 'research-summary', markdown: 'Shorter summary', baseRevision: s.sections['research-summary'].revision }, new Date().toISOString()), { by: 'user' });
        const edits = await call('take_feedback', {});
        assert.equal(edits.items[0].kind, 'edit');
        assert.equal(edits.items[0].section.markdown, 'Shorter summary');
        assert.equal(edits.items[0].section.truncated, false);
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
    it('attaches a composer pill bound to the instance', async () => {
        const calls = [];
        const deliver = createDelivery({ getSession: () => ({ rpc: { extensions: { sendAttachmentsToMessage: async (params) => calls.push(params) } } }), getInstanceId: () => 'i1' });
        await deliver({ mode: 'attach', prompt: 'Full text', displayPrompt: 'RPI canvas: 1 comment', ids: ['FB-001'] });
        assert.deepEqual(calls[0], { instanceId: 'i1', attachments: [{ type: 'extension_context', title: 'RPI canvas: 1 comment', payload: { text: 'Full text', feedbackIds: ['FB-001'] } }] });
    });

    it('enqueues a message whose prompt is the previewed text', async () => {
        const calls = [];
        const deliver = createDelivery({ getSession: () => ({ send: async (options) => calls.push(options) }), getInstanceId: () => null });
        await deliver({ mode: 'send', prompt: 'Full text', displayPrompt: 'Label', ids: ['FB-001'] });
        assert.deepEqual(calls[0], { prompt: 'Full text', displayPrompt: 'Label', mode: 'enqueue' });
    });

    it('reports unavailable hosts', async () => {
        const none = createDelivery({ getSession: () => null, getInstanceId: () => null });
        await assert.rejects(none({ mode: 'send', prompt: 'x', displayPrompt: 'x', ids: [] }), (error) => error instanceof ModelError && error.code === 'delivery_unavailable');
        const noPills = createDelivery({ getSession: () => ({ send: async () => {} }), getInstanceId: () => 'i1' });
        await assert.rejects(noPills({ mode: 'attach', prompt: 'x', displayPrompt: 'x', ids: [] }), (error) => error.code === 'delivery_unavailable');
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
