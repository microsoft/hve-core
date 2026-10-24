// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createActionHandlers } from '../lib/actions.mjs';
import { createFeedback } from '../lib/model.mjs';
import { buildScenario, SCENARIO_ID } from '../lib/scenario.mjs';
import { createCanvasServer } from '../lib/server.mjs';
import { createSourceController, sourceSummary, validateOpenInput } from '../lib/sources.mjs';
import { createStore } from '../lib/store.mjs';
import { CHILD_TASK, PATHS, ROOT_TASK, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

class FakeCanvasError extends Error {
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}
const makeError = (code, message) => new FakeCanvasError(code, message);
const NOW = '2026-01-15T12:00:00.000Z';
let tmp;
let root;

before(async () => {
    tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-sources-')));
    root = path.join(tmp, 'repo');
    await writeFixtureWorkspace(root);
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

async function codeOf(run) {
    try {
        await run();
    } catch (error) {
        return error.code;
    }
    assert.fail('expected an error');
}

describe('open input', () => {
    it('accepts the sample and task forms and rejects mixtures', async () => {
        assert.deepEqual(validateOpenInput(undefined, makeError), {});
        assert.deepEqual(validateOpenInput({ stage: 'plan' }, makeError), { stage: 'plan' });
        assert.deepEqual(validateOpenInput({ scenario: SCENARIO_ID, stage: 'review' }, makeError), { scenario: SCENARIO_ID, stage: 'review' });
        assert.deepEqual(validateOpenInput({ task: 'current' }, makeError), { task: 'current' });
        assert.deepEqual(validateOpenInput({ task: ROOT_TASK }, makeError), { task: ROOT_TASK });
        for (const bad of [[], 'x', { task: 'current', stage: 'plan' }, { task: ROOT_TASK, scenario: SCENARIO_ID }, { task: 'sample' }, { task: '../escape' }, { task: 7 }, { stage: 'later' }, { scenario: 'other' }, { extra: true }]) {
            assert.equal(await codeOf(() => validateOpenInput(bad, makeError)), 'invalid_input', JSON.stringify(bad));
        }
    });
});

describe('source controller', () => {
    it('prepares the sample as before and keeps changes the user made', async () => {
        const store = createStore({ root: path.join(tmp, 'sample-store') });
        const sources = createSourceController({ store });
        const first = await sources.prepare({});
        assert.deepEqual([first.sessionId, first.source], [SCENARIO_ID, { kind: 'sample', stage: 'implement' }]);
        assert.equal((await sources.prepare({ stage: 'plan' })).session.session.activePhase, 'plan');
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'comment', text: 'mine' }, NOW), { by: 'user' });
        const kept = await sources.prepare({ stage: 'review' });
        assert.equal(kept.session.session.activePhase, 'plan');
        assert.match(kept.note, /kept your changes/);
        store.close();
    });

    it('prepares a task from the workspace and moves an instance between sources', async () => {
        const store = createStore({ root: path.join(tmp, 'task-store') });
        const sources = createSourceController({ store });
        assert.equal(await codeOf(() => sources.prepare({ task: 'current' }, { candidates: [path.join(tmp, 'nowhere')] })), 'source_unavailable');
        assert.equal(await codeOf(() => sources.prepare({ task: 'bad id!' }, { candidates: [root] })), 'invalid_input');
        const task = await sources.prepare({ task: 'current' }, { candidates: [undefined, root] });
        assert.equal(task.sessionId, 'rpi-trail-maps');
        assert.deepEqual([task.source.kind, task.source.taskId, task.source.statePath], ['rpi', ROOT_TASK, PATHS.rootState]);
        assert.equal(task.source.follower.running, false, 'following waits for a page');
        const rebinds = [];
        const record = { sessionId: task.sessionId, source: task.source, server: { rebind: () => rebinds.push(record.sessionId) } };
        task.source.follower.start();
        const child = await sources.switchToTask(record, CHILD_TASK);
        assert.deepEqual([record.sessionId, record.source.taskId], ['rpi-trail-maps-fixes', CHILD_TASK]);
        assert.equal(task.source.follower.running, false, 'the previous follower stops');
        assert.deepEqual(rebinds, ['rpi-trail-maps-fixes']);
        assert.equal(child.session.phases.research.status, 'skipped');
        assert.equal(await codeOf(() => sources.switchToTask(record, 'old-task')), 'invalid_input', 'only lineage tasks');
        const sample = await sources.prepare({ stage: 'research' });
        sources.attach(record, sample);
        assert.equal(record.sessionId, SCENARIO_ID);
        assert.equal(await codeOf(() => sources.switchToTask(record, ROOT_TASK)), 'invalid_state');
        assert.deepEqual(sourceSummary(record, sample.session), { kind: 'sample', stage: 'research' });
        store.close();
    });
});

describe('actions on a canvas that follows RPI files', () => {
    async function setup(name) {
        const store = createStore({ root: path.join(tmp, name) });
        const sources = createSourceController({ store });
        const prepared = await sources.prepare({ task: ROOT_TASK }, { candidates: [root] });
        const reloads = [];
        const instance = { server: { url: 'http://127.0.0.1:1/', clientInfo: null, streamClients: 0, notifyReload: () => reloads.push('reload'), rebind: () => reloads.push('rebind') }, sessionId: prepared.sessionId, source: prepared.source };
        const handlers = createActionHandlers({
            getInstance: (id) => (id === 'i1' ? instance : undefined),
            store,
            makeError,
            async switchSource(target, request, context) {
                const next = await sources.prepare(request, { workspace: request.task !== undefined && target.source?.kind === 'rpi' ? target.source.workspace : null, candidates: [context.workingDirectory, root] });
                sources.attach(target, next);
                return next;
            },
        });
        const call = (action, input, extra = {}) => handlers[action]({ instanceId: 'i1', input, ...extra });
        return { store, instance, call, reloads };
    }

    it('refuses document changes and names the file to update', async () => {
        const { call, store } = await setup('managed');
        const cases = [
            ['update_session', { nextAction: 'x' }, PATHS.rootState],
            ['update_task', { taskId: 'P02-T02', status: 'done' }, PATHS.plan],
            ['record_change', { taskId: 'P02-T02', title: 't', behavior: 'b' }, PATHS.changes],
            ['record_discovery', { kind: 'local', title: 't', detail: 'd' }, PATHS.changes],
            ['update_finding', { id: 'RV-001', decision: 'accepted' }, PATHS.review],
            ['update_section', { sectionId: 'plan-summary', markdown: 'x', baseRevision: 1 }, PATHS.plan],
            ['upsert_decision', { id: 'D1', title: 'Changed' }, PATHS.research],
            ['upsert_decision', { id: 'plan.D2', title: 'Changed' }, PATHS.plan],
        ];
        for (const [action, input, file] of cases) {
            await assert.rejects(call(action, input), (error) => error.code === 'source_managed' && error.message.includes(file), action);
        }
        store.close();
    });

    it('keeps the conversation actions working and reports the source', async () => {
        const { call, store, instance } = await setup('conversation');
        const asked = await call('upsert_decision', { owner: 'user', phase: 'plan', title: 'Coast or park?', question: 'Which region first?', options: [{ label: 'Coast' }, { label: 'Park' }] });
        assert.equal(asked.decision.id, 'D3');
        await store.update(instance.sessionId, (s) => createFeedback(s, { kind: 'comment', text: 'Hello agent', target: { id: 'F1', type: 'finding', phase: 'research' } }, NOW), { by: 'user' });
        const taken = await call('take_feedback', {});
        assert.deepEqual(taken.items.map((item) => item.text), ['Hello agent']);
        assert.ok((await call('record_activity', { text: 'Reading' })).revision > 0);
        const state = await call('get_state', {});
        assert.deepEqual([state.source.kind, state.source.taskId, state.source.lineage.length, state.source.following], ['rpi', ROOT_TASK, 2, false]);
        store.close();
    });

    it('switches between tasks and the sample', async () => {
        const { call, store, instance, reloads } = await setup('switching');
        for (const input of [{}, { task: 7 }, { task: ROOT_TASK, stage: 'plan' }, { stage: 'later' }]) {
            assert.equal(await codeOf(() => call('show_task', input)), 'invalid_input', JSON.stringify(input));
        }
        const child = await call('show_task', { task: CHILD_TASK });
        assert.deepEqual([child.source.taskId, instance.sessionId], [CHILD_TASK, 'rpi-trail-maps-fixes']);
        const sample = await call('show_task', { task: 'sample', stage: 'plan' });
        assert.deepEqual([sample.source, instance.sessionId], [{ kind: 'sample', stage: 'plan' }, SCENARIO_ID]);
        await call('show_task', { task: 'current' }, { session: { workingDirectory: root } });
        assert.equal(instance.sessionId, 'rpi-trail-maps');
        const loaded = await call('load_scenario', { stage: 'review' });
        assert.equal(loaded.activePhase, 'review');
        assert.equal(instance.sessionId, SCENARIO_ID, 'load_scenario returns the canvas to the sample');
        assert.ok(reloads.filter((item) => item === 'rebind').length >= 4);
        store.close();
    });
});

describe('server following and task switching', () => {
    function stream(url) {
        const events = [];
        let waiter = null;
        const req = http.get({ host: '127.0.0.1', port: url.port, path: '/api/events' }, (res) => {
            let buffer = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                buffer += chunk;
                let index;
                while ((index = buffer.indexOf('\n\n')) >= 0) {
                    const frame = buffer.slice(0, index);
                    buffer = buffer.slice(index + 2);
                    const event = /^event: (.+)$/m.exec(frame)?.[1];
                    if (event) {
                        events.push(event);
                        if (waiter?.predicate(event)) waiter.resolve();
                    }
                }
            });
        });
        const until = (predicate) => new Promise((resolve) => {
            if (events.some(predicate)) resolve();
            else waiter = { predicate, resolve };
        });
        return { req, events, until };
    }

    const post = (url, pathname, body) => new Promise((resolve, reject) => {
        const payload = JSON.stringify(body);
        const req = http.request({ host: '127.0.0.1', port: url.port, method: 'POST', path: pathname, headers: { 'content-type': 'application/json' } }, (res) => {
            let text = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                text += chunk;
            });
            res.on('end', () => resolve({ status: res.statusCode, json: JSON.parse(text) }));
        });
        req.on('error', reject);
        req.end(payload);
    });

    it('follows only while a page is connected, switches tasks, and tells the page', async () => {
        const store = createStore({ root: path.join(tmp, 'server-store'), pollMs: 20 });
        const session = await store.create(buildScenario('research'));
        const calls = [];
        const follower = { start: () => calls.push('start'), stop: () => calls.push('stop') };
        let sessionId = session.id;
        const server = createCanvasServer({
            store,
            getSessionId: () => sessionId,
            getSource: () => ({ follower }),
            switchTask: async (taskId) => {
                if (taskId !== 'trail-maps-fixes') throw Object.assign(new Error('not in lineage'), { code: 'invalid_input' });
                sessionId = session.id;
                server.rebind();
                return { sessionId };
            },
        });
        const url = new URL(await server.start());
        const page = stream(url);
        await page.until((event) => event === 'revision');
        assert.deepEqual(calls, ['start']);
        const switched = await post(url, '/api/task', { taskId: 'trail-maps-fixes' });
        assert.deepEqual([switched.status, switched.json.sessionId], [200, session.id]);
        await page.until((event) => event === 'reload');
        assert.deepEqual(calls, ['start', 'start'], 'rebinding restarts following for the new source');
        page.req.destroy();
        await new Promise((resolve) => setTimeout(resolve, 50));
        assert.equal(calls.at(-1), 'stop');
        await server.stop();
        assert.equal(calls.at(-1), 'stop');
        store.close();
    });

    it('reports that a canvas without sources cannot switch tasks', async () => {
        const store = createStore({ root: path.join(tmp, 'server-store-2') });
        const session = await store.create(buildScenario('research'));
        const server = createCanvasServer({ store, getSessionId: () => session.id });
        const url = new URL(await server.start());
        const result = await post(url, '/api/task', { taskId: 'x' });
        assert.equal(result.status, 404);
        await server.stop();
        store.close();
    });
});
