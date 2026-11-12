// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, afterEach, before, describe, it } from 'node:test';

import { symlinkOrSkip } from '../../session-log/tests/helpers.mjs';
import { createActionHandlers } from '../lib/actions.mjs';
import { createFeedback, markDelivered } from '../lib/model.mjs';
import { buildScenario, SCENARIO_ID } from '../lib/scenario.mjs';
import { createCanvasServer as newServer } from '../lib/server.mjs';
import { createSourceController, notConnected, openPlan, splitOpenInput, sourceSummary, validateOpenInput } from '../lib/sources.mjs';
import { storeIdFor } from '../lib/source/workspace.mjs';
import { createStore, MAX_INSTANCES } from '../lib/store.mjs';
import { stopTracked, track } from './helpers/cleanup.mjs';
import { scratchFolder } from './helpers/scratch.mjs';
import { CHILD_STATE, CHILD_TASK, PATHS, ROOT_STATE, ROOT_TASK, SESSION_KEY, STALE_SESSION_KEY, STALE_TASK, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

/** A canvas server that stops after the test even when an assertion fails. */
const createCanvasServer = (deps) => track(newServer(deps));

afterEach(stopTracked);

const writeJson = async (dir, relative, value) => {
    await fs.mkdir(path.dirname(path.join(dir, relative)), { recursive: true });
    await fs.writeFile(path.join(dir, relative), JSON.stringify(value));
};

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
        assert.deepEqual(validateOpenInput({ state: PATHS.childState }, makeError), { state: PATHS.childState });
        for (const bad of [[], 'x', { task: 'current', stage: 'plan' }, { task: ROOT_TASK, scenario: SCENARIO_ID }, { task: 'sample' }, { task: '../escape' }, { task: 7 }, { stage: 'later' }, { scenario: 'other' }, { extra: true },
            { state: PATHS.plan }, { state: '' }, { state: 7 }, { state: PATHS.rootState, task: ROOT_TASK }, { state: PATHS.rootState, stage: 'plan' }, { state: `x\u0000-state.json` }]) {
            assert.equal(await codeOf(() => validateOpenInput(bad, makeError)), 'invalid_input', JSON.stringify(bad));
        }
    });
});

describe('the picker\'s sessions in open input', () => {
    const FIRST = '0c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
    const SECOND = '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b';
    const idAt = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
    const remembered = { kind: 'rpi', state: PATHS.childState, paused: false };
    let store;
    let sources;
    before(() => {
        store = createStore({ root: path.join(tmp, 'picker-open-store') });
        sources = createSourceController({ store });
    });
    after(() => store.close());

    it('accepts a list of session IDs alone or with other input, and returns it lowercased and without repeats', () => {
        assert.deepEqual(validateOpenInput({ sessions: [] }, makeError), { sessions: [] });
        assert.deepEqual(validateOpenInput({ sessions: [FIRST.toUpperCase(), SECOND, FIRST] }, makeError), { sessions: [FIRST, SECOND] });
        assert.deepEqual(validateOpenInput({ sessions: [FIRST], task: 'current' }, makeError), { sessions: [FIRST], task: 'current' });
        assert.deepEqual(validateOpenInput({ sessions: [FIRST], stage: 'plan' }, makeError), { sessions: [FIRST], stage: 'plan' });
        assert.deepEqual(validateOpenInput({ sessions: [FIRST], state: PATHS.childState }, makeError), { sessions: [FIRST], state: PATHS.childState });
        assert.equal(validateOpenInput({ sessions: Array.from({ length: 50 }, (_, n) => idAt(n + 1)) }, makeError).sessions.length, 50, 'fifty is the most');
    });

    it('refuses a value that is not a list of session IDs, and a list of more than fifty', async () => {
        const bad = [{ sessions: 'x' }, { sessions: [FIRST, 'nope'] }, { sessions: [7] }, { sessions: null }, { sessions: {} }, { sessions: [FIRST, ''] },
            { sessions: [FIRST, `${SECOND}/..`] }, { sessions: Array.from({ length: 51 }, (_, n) => idAt(n + 1)) }];
        for (const input of bad) {
            assert.equal(await codeOf(() => validateOpenInput(input, makeError)), 'invalid_input', JSON.stringify(input).slice(0, 80));
        }
    });

    it('combines with the other input, except that a session with stage or scenario is still refused', async () => {
        assert.equal(await codeOf(() => validateOpenInput({ sessions: [FIRST], session: SECOND, stage: 'plan' }, makeError)), 'invalid_input');
        assert.equal(await codeOf(() => validateOpenInput({ sessions: [FIRST], task: 'current', stage: 'plan' }, makeError)), 'invalid_input');
        assert.equal(await codeOf(() => validateOpenInput({ sessions: [FIRST], task: 'sample' }, makeError)), 'invalid_input');
    });

    it('opens Not connected for a list alone, as for an empty input, and leaves an open canvas as it is', async () => {
        const { target, sessions } = splitOpenInput(validateOpenInput({ sessions: [FIRST] }, makeError));
        assert.deepEqual([target, sessions], [{}, [FIRST]]);
        assert.deepEqual(splitOpenInput(validateOpenInput({}, makeError)), { target: {}, sessions: undefined });
        assert.deepEqual(splitOpenInput(validateOpenInput({ sessions: [FIRST], task: 'current' }, makeError)).target, { task: 'current' });
        assert.deepEqual((await sources.prepare(target)).source, notConnected('no-input').source);
        for (const instance of [{ open: true, remembered: null }, { open: false, remembered }, { open: false, remembered: null }]) {
            assert.deepEqual(openPlan(target, instance), openPlan({}, instance), JSON.stringify(instance));
        }
        assert.deepEqual(openPlan(target, { open: true, remembered: null }), { keep: true }, 'an open canvas keeps its view when the list alone is sent');
    });
});

describe('reopening an instance', () => {
    const remembered = { kind: 'rpi', state: '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-state.json', paused: true };

    it('shows the input when there is one, keeps an open instance, and restores a bare reopen', () => {
        assert.deepEqual(openPlan({ stage: 'plan' }, { open: true, remembered }), { keep: false, restore: null });
        assert.deepEqual(openPlan({ state: remembered.state }, { open: false, remembered: null }), { keep: false, restore: null });
        assert.deepEqual(openPlan({}, { open: true, remembered }), { keep: true });
        assert.deepEqual(openPlan({}, { open: false, remembered }), { keep: false, restore: { state: remembered.state, paused: true } });
        assert.deepEqual(openPlan({}, { open: false, remembered: { ...remembered, paused: undefined } }).restore.paused, false);
    });

    it('restores a remembered instance whatever input the host repeats', () => {
        const restored = { keep: false, restore: { state: remembered.state, paused: true } };
        assert.deepEqual(openPlan({ stage: 'implement' }, { open: false, remembered }), restored, "a session restart repeats the first open's input");
        assert.deepEqual(openPlan({ state: '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-fixes-state.json' }, { open: false, remembered }), restored, "a reload repeats the latest open's input");
        assert.deepEqual(openPlan({ task: 'current' }, { open: false, remembered }), restored);
        assert.deepEqual(openPlan({ stage: 'implement' }, { open: true, remembered }), { keep: false, restore: null }, 'an instance already showing obeys its input');
        assert.deepEqual(openPlan({ state: remembered.state }, { open: false, remembered: { kind: 'sample' } }), { keep: false, restore: { task: 'sample' } }, 'a remembered sample comes back as it was');
    });

    it('opens the input for an instance this conversation never showed, or a memory it cannot use', () => {
        assert.deepEqual(openPlan({}, { open: false, remembered: null }), { keep: false, restore: null });
        assert.deepEqual(openPlan({ stage: 'plan' }, { open: false, remembered: null }), { keep: false, restore: null });
        assert.deepEqual(openPlan({}, { open: false, remembered: { kind: 'sample' } }), { keep: false, restore: { task: 'sample' } });
        assert.deepEqual(openPlan({}, { open: false, remembered: { kind: 'rpi', state: '../etc/passwd' } }), { keep: false, restore: null });
        assert.deepEqual(openPlan({}, { open: false, remembered: { kind: 'rpi', state: 42 } }), { keep: false, restore: null });
    });

    it('remembers what each instance shows, including paused following, and reopens it there', async () => {
        const dir = path.join(tmp, 'remember-session');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, PATHS.childState, { ...CHILD_STATE, status: 'active', session_status: 'running' });
        const store = createStore({ root: path.join(tmp, 'remember-store') });
        const sources = createSourceController({ store });
        const record = { instanceId: 'rpi-trail-maps', sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(record, await sources.prepare({ state: PATHS.rootState }, { candidates: [dir] }));
        // What an instance shows is written once its move and memory write settle.
        const remembered = async (shownBy) => {
            await sources.settled(shownBy);
            return store.loadInstance('rpi-trail-maps');
        };
        let shown = await remembered(record);
        assert.deepEqual([shown.kind, shown.state, shown.paused], ['rpi', PATHS.childState, false], 'following moved to the running child');
        await sources.switchToTask(record, ROOT_TASK);
        shown = await remembered(record);
        assert.deepEqual([shown.state, shown.paused], [PATHS.rootState, true], 'a manual switch to a stopped loop is remembered as paused');
        await sources.resumeFollowing(record);
        shown = await remembered(record);
        assert.deepEqual([shown.state, shown.paused], [PATHS.childState, false]);
        sources.detach(record);

        const plan = openPlan({}, { open: false, remembered: { ...shown, state: PATHS.rootState, paused: true } });
        const reopened = { instanceId: 'rpi-trail-maps', sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(reopened, await sources.prepare(plan.restore, { candidates: [dir] }));
        await sources.settled(reopened);
        assert.deepEqual([reopened.source.taskId, reopened.source.follow.paused], [ROOT_TASK, true], 'a paused memory reopens paused, on the loop it showed');
        sources.detach(reopened);
        const sample = { instanceId: 'rpi-trail-maps', sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(sample, await sources.prepare({ stage: 'plan' }, {}));
        assert.equal((await remembered(sample)).kind, 'sample', 'showing the sample on purpose is remembered too');
        store.close();
    });

    it('remembers nothing for a canvas that shows no session, so it keeps its last place', async () => {
        const store = createStore({ root: path.join(tmp, 'none-memory') });
        const sources = createSourceController({ store });
        const record = { instanceId: 'panel', sessionId: '', source: null, server: { rebind: () => {} }, hostSessionId: 'session-a' };
        sources.attach(record, await sources.prepare({ task: 'sample' }, {}));
        await sources.settled(record);
        assert.equal((await store.loadInstance('panel', 'session-a')).kind, 'sample');
        sources.attach(record, notConnected('missing-session', PATHS.childState));
        await sources.settled(record);
        assert.equal((await store.loadInstance('panel', 'session-a')).kind, 'sample');
        assert.deepEqual(sourceSummary(record, null), { kind: 'none', reason: 'missing-session', detail: PATHS.childState });
        store.close();
    });

    it('keeps the most recent instances and treats an unreadable memory as empty', async () => {
        const store = createStore({ root: path.join(tmp, 'instances-store') });
        await fs.mkdir(store.root, { recursive: true });
        await fs.writeFile(path.join(store.root, 'instances.json'), '{ not json');
        assert.equal(await store.loadInstance('a'), null);
        for (let i = 0; i < MAX_INSTANCES + 5; i += 1) await store.rememberInstance(`i-${i}`, { kind: 'sample' });
        const doc = JSON.parse(await fs.readFile(path.join(store.root, 'instances.json'), 'utf8'));
        assert.equal(Object.keys(doc.instances).length, MAX_INSTANCES);
        assert.equal(await store.loadInstance('i-0'), null, 'the oldest instances are dropped');
        assert.equal((await store.loadInstance(`i-${MAX_INSTANCES + 4}`)).kind, 'sample');
        store.close();
    });

    it('keeps each conversation apart', async () => {
        const store = createStore({ root: path.join(tmp, 'conversations-store') });
        const shown = { kind: 'rpi', state: remembered.state, paused: false };
        await store.rememberInstance('panel', shown, { hostSessionId: 'session-a' });
        assert.deepEqual([(await store.loadInstance('panel', 'session-a')).state], [remembered.state]);
        assert.equal(await store.loadInstance('panel', 'session-b'), null, 'another conversation remembers nothing');
        assert.equal(await store.loadInstance('panel'), null, 'the instance alone is another key');
        await store.rememberInstance('panel', { kind: 'sample' }, { hostSessionId: 'session-b' });
        assert.equal((await store.loadInstance('panel', 'session-a')).kind, 'rpi', 'conversations do not overwrite each other');
        assert.equal((await store.loadInstance('panel', 'session-b')).kind, 'sample');
        await store.rememberInstance('loose', { kind: 'sample' }, { hostSessionId: '../escape' });
        assert.equal((await store.loadInstance('loose')).kind, 'sample', 'an unusable conversation ID falls back to the instance alone');
        store.close();
    });

    it('ignores memory saved in another version', async () => {
        const store = createStore({ root: path.join(tmp, 'version-store') });
        await fs.mkdir(store.root, { recursive: true });
        const file = path.join(store.root, 'instances.json');
        await fs.writeFile(file, JSON.stringify({ format: 'hve-core-rpi-workflow.instances', version: 1, instances: { panel: { kind: 'rpi', state: remembered.state, paused: false } } }));
        assert.equal(await store.loadInstance('panel'), null, 'memory saved before version 2 is not carried over');
        await store.rememberInstance('panel', { kind: 'sample' }, { hostSessionId: 'session-a' });
        const doc = JSON.parse(await fs.readFile(file, 'utf8'));
        assert.deepEqual([doc.version, Object.keys(doc.instances)], [2, ['session-a/panel']], 'the next write replaces it');
        store.close();
    });

    it('brings a remembered task back when the host reopens with an earlier input', async () => {
        const dir = path.join(tmp, 'replay-session');
        await writeFixtureWorkspace(dir);
        const store = createStore({ root: path.join(tmp, 'replay-store') });
        const sources = createSourceController({ store });
        const first = { stage: 'implement' };
        const conversation = 'session-a';
        const record = { instanceId: 'panel', sessionId: '', source: null, server: { rebind: () => {} }, hostSessionId: conversation };
        sources.attach(record, await sources.prepare(first, {}));
        sources.attach(record, await sources.prepare({ state: PATHS.rootState }, { candidates: [dir] }));
        await sources.settled(record);
        sources.detach(record);
        let memory = null;
        for (let i = 0; i < 50 && memory?.kind !== 'rpi'; i += 1) {
            await new Promise((resolve) => setTimeout(resolve, 20));
            memory = await store.loadInstance('panel', conversation);
        }
        assert.equal(memory?.kind, 'rpi', 'the conversation remembers the task');

        for (const repeated of [first, { state: PATHS.rootState }]) {
            const plan = openPlan(repeated, { open: false, remembered: memory });
            const reopened = { instanceId: 'panel', sessionId: '', source: null, server: { rebind: () => {} }, hostSessionId: conversation };
            sources.attach(reopened, await sources.prepare(plan.restore, { candidates: [dir] }));
            await sources.settled(reopened);
            assert.deepEqual([reopened.source.kind, reopened.source.statePath], ['rpi', memory.state], `reopening with ${JSON.stringify(repeated)} returns to the task`);
            sources.detach(reopened);
        }

        assert.equal(await store.loadInstance('panel', 'session-b'), null, 'another conversation has no memory of the panel');
        assert.deepEqual(openPlan(first, { open: false, remembered: null }), { keep: false, restore: null }, 'so its first open obeys the input');
        store.close();
    });
});

describe('source controller', () => {
    it('prepares the sample only when asked for and keeps changes the user made', async () => {
        const store = createStore({ root: path.join(tmp, 'sample-store') });
        const sources = createSourceController({ store });
        const nothing = await sources.prepare({});
        assert.deepEqual([nothing.sessionId, nothing.source, nothing.session], ['', { kind: 'none', reason: 'no-input', detail: null }, null], 'nothing asked for is not connected, not the sample');
        const first = await sources.prepare({ task: 'sample' });
        assert.deepEqual([first.sessionId, first.source], [SCENARIO_ID, { kind: 'sample', stage: 'implement' }]);
        assert.equal((await sources.prepare({ stage: 'plan' })).session.session.activePhase, 'plan');
        await store.update(SCENARIO_ID, (s) => createFeedback(s, { kind: 'comment', text: 'mine' }, NOW), { by: 'user' });
        const kept = await sources.prepare({ stage: 'review' });
        assert.equal(kept.session.session.activePhase, 'plan');
        assert.match(kept.note, /kept your changes/);
        store.close();
    });

    it('opens a task from its state path and refuses paths outside the session folders', async (t) => {
        const store = createStore({ root: path.join(tmp, 'state-store') });
        t.after(() => store.close());
        const sources = createSourceController({ store });
        const opened = await sources.prepare({ state: PATHS.childState }, { candidates: [root] });
        assert.deepEqual([opened.sessionId, opened.source.taskId, opened.source.sessionKey], [storeIdFor(CHILD_TASK, root), CHILD_TASK, SESSION_KEY]);
        await writeJson(root, '.copilot-tracking/plans/2026-01-15/stray-state.json', { task_id: 'stray' });
        await writeJson(root, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json', { task_id: 'flat' });
        await fs.writeFile(path.join(tmp, 'outside-state.json'), JSON.stringify({ task_id: 'outside' }));
        assert.equal(await codeOf(() => sources.prepare({ state: '.copilot-tracking/plans/2026-01-15/stray-state.json' }, { candidates: [root] })), 'source_outside');
        assert.equal(await codeOf(() => sources.prepare({ state: '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json' }, { candidates: [root] })), 'source_outside');
        assert.equal(await codeOf(() => sources.prepare({ state: '../outside-state.json' }, { candidates: [root] })), 'source_outside');
        assert.equal(await codeOf(() => sources.prepare({ state: PATHS.plan }, { candidates: [root] })), 'invalid_input');
        await fs.rm(path.join(root, '.copilot-tracking/plans/2026-01-15/stray-state.json'));
        await fs.rm(path.join(root, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'));
        await t.test('refuses a linked state file', async (t) => {
            const state = `.copilot-tracking/rpi-sessions/${SESSION_KEY}/linked-state.json`;
            const linkPath = path.join(root, state);
            if (!(await symlinkOrSkip(t, path.join(tmp, 'outside-state.json'), linkPath, 'file'))) return;
            t.after(() => fs.rm(linkPath));
            assert.equal(await codeOf(() => sources.prepare({ state }, { candidates: [root] })), 'source_invalid');
        });
    });

    it('follows the running loop, pauses on a manual switch, and resumes', async () => {
        const dir = path.join(tmp, 'follow-session');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, PATHS.childState, { ...CHILD_STATE, status: 'active', session_status: 'running' });
        const store = createStore({ root: path.join(tmp, 'follow-session-store') });
        const sources = createSourceController({ store });
        const rebinds = [];
        const record = { sessionId: '', source: null, server: { rebind: (detail) => rebinds.push(detail) } };
        sources.attach(record, await sources.prepare({ state: PATHS.rootState }, { candidates: [dir] }));
        await sources.settled(record);
        assert.equal(record.source.taskId, CHILD_TASK, 'the completed root hands over to its one running child');
        assert.deepEqual(rebinds.at(-1), { moved: { from: ROOT_TASK, to: CHILD_TASK, title: 'Offline trail maps review fixes' } });
        assert.equal(sourceSummary(record, await store.load(record.sessionId)).following, 'enabled');

        await sources.switchToTask(record, ROOT_TASK);
        await sources.settled(record);
        assert.equal(record.source.taskId, ROOT_TASK, 'a manual switch to a task that is not running stays there');
        assert.equal(sourceSummary(record, await store.load(record.sessionId)).following, 'paused');

        await sources.resumeFollowing(record);
        await sources.settled(record);
        assert.equal(record.source.taskId, CHILD_TASK, 'resuming shows the running task');
        assert.equal(record.source.follow.paused, false);

        const before = rebinds.length;
        await sources.pauseFollowing(record);
        assert.equal(record.source.follow.paused, true, 'pausing keeps the task and stops following');
        assert.equal(record.source.taskId, CHILD_TASK);
        assert.equal(rebinds.length, before + 1, 'the page hears about the pause');
        assert.equal(sourceSummary(record, await store.load(record.sessionId)).following, 'paused');
        await sources.pauseFollowing(record);
        assert.equal(rebinds.length, before + 1, 'pausing twice changes nothing');
        await sources.resumeFollowing(record);
        assert.equal(record.source.follow.paused, false);

        await sources.switchToTask(record, CHILD_TASK, { paused: true });
        await sources.settled(record);
        assert.deepEqual([record.source.taskId, record.source.follow.paused], [CHILD_TASK, true], 'a switch the reader chose can stay paused on a running loop');
        await sources.switchToTask(record, CHILD_TASK);
        assert.equal(record.source.follow.paused, false, 'without the option, a running loop follows');

        const other = await sources.switchToSession(record, STALE_SESSION_KEY);
        assert.equal(other.source.taskId, STALE_TASK);
        const pausedSession = await sources.switchToSession(record, SESSION_KEY, { paused: true });
        assert.equal(pausedSession.source.follow.paused, true, 'a session switch can stay paused');
        assert.equal(await codeOf(() => sources.switchToSession(record, '2030-01-01/none')), 'not_found');
        const listed = await sources.sessions(record);
        assert.deepEqual(listed.sessions.map((session) => session.key).sort(), [SESSION_KEY, STALE_SESSION_KEY].sort());
        sources.detach(record);
        store.close();
    });

    it('resumes following on the latest loop when none runs, from anywhere in the session', async () => {
        const dir = path.join(tmp, 'follow-latest');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, PATHS.childState, { ...CHILD_STATE, status: 'completed', session_status: 'stopped' });
        const later = new Date(Date.now() + 5000);
        await fs.utimes(path.join(dir, PATHS.rootState), later, later);
        const store = createStore({ root: path.join(tmp, 'follow-latest-store') });
        const sources = createSourceController({ store, intervalMs: 60000 });
        const record = { sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(record, await sources.prepare({ state: PATHS.rootState, paused: true }, { candidates: [dir] }));
        await sources.settled(record);
        assert.deepEqual([record.source.taskId, record.source.follow.paused], [ROOT_TASK, true]);
        await sources.resumeFollowing(record);
        await sources.settled(record);
        assert.deepEqual([record.source.taskId, record.source.follow.paused], [CHILD_TASK, false], 'the root changed last, but its loop is where the agent was');
        await sources.resumeFollowing(record);
        assert.equal(record.source.taskId, CHILD_TASK, 'resuming on the latest loop keeps it');
        sources.detach(record);
        store.close();
    });

    it('moves along when the followed task finishes while the page is open', async () => {
        const dir = path.join(tmp, 'follow-later');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, status: 'active' });
        await writeJson(dir, PATHS.childState, { ...CHILD_STATE, status: 'active', session_status: 'running' });
        const store = createStore({ root: path.join(tmp, 'follow-later-store') });
        const sources = createSourceController({ store, intervalMs: 60000 });
        const record = { sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(record, await sources.prepare({ state: PATHS.rootState }, { candidates: [dir] }));
        await sources.settled(record);
        assert.equal(record.source.taskId, ROOT_TASK, 'a running parent keeps the canvas even with a running child');
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, status: 'completed' });
        const later = new Date(Date.now() + 5000);
        await fs.utimes(path.join(dir, PATHS.rootState), later, later);
        const follower = record.source.follower;
        await follower.tick();
        await follower.tick();
        await sources.settled(record);
        assert.equal(record.source.taskId, CHILD_TASK);
        sources.detach(record);
        store.close();
    });

    it('prepares a task from the workspace and moves an instance between sources', async () => {
        const store = createStore({ root: path.join(tmp, 'task-store') });
        const sources = createSourceController({ store });
        assert.equal(await codeOf(() => sources.prepare({ task: 'current' }, { candidates: [path.join(tmp, 'nowhere')] })), 'source_unavailable');
        assert.equal(await codeOf(() => sources.prepare({ task: 'bad id!' }, { candidates: [root] })), 'invalid_input');
        const task = await sources.prepare({ task: 'current' }, { candidates: [undefined, root] });
        assert.equal(task.sessionId, storeIdFor(ROOT_TASK, root));
        assert.deepEqual([task.source.kind, task.source.taskId, task.source.statePath], ['rpi', ROOT_TASK, PATHS.rootState]);
        assert.equal(task.source.follower.running, false, 'following waits for a page');
        const rebinds = [];
        const record = { sessionId: task.sessionId, source: task.source, server: { rebind: () => rebinds.push(record.sessionId) } };
        task.source.follower.start();
        const child = await sources.switchToTask(record, CHILD_TASK);
        assert.deepEqual([record.sessionId, record.source.taskId], [storeIdFor(CHILD_TASK, root), CHILD_TASK]);
        assert.equal(task.source.follower.running, false, 'the previous follower stops');
        assert.deepEqual(rebinds, [storeIdFor(CHILD_TASK, root)]);
        assert.equal(child.session.phases.research.status, 'skipped');
        assert.equal(await codeOf(() => sources.switchToTask(record, 'old-task')), 'invalid_input', 'only tasks in the session');
        const byPath = await sources.switchToTask(record, { statePath: PATHS.rootState });
        assert.equal(byPath.source.taskId, ROOT_TASK);
        const sample = await sources.prepare({ stage: 'research' });
        sources.attach(record, sample);
        assert.equal(record.sessionId, SCENARIO_ID);
        assert.equal(await codeOf(() => sources.switchToTask(record, ROOT_TASK)), 'invalid_state');
        assert.deepEqual(sourceSummary(record, sample.session), { kind: 'sample', stage: 'research' });
        sources.attach(record, notConnected('no-input'));
        assert.equal(await codeOf(() => sources.switchToTask(record, ROOT_TASK)), 'not_connected', 'a canvas that shows no session says so');
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
                return sources.show(target, request, { workspace: request.task !== undefined && target.source?.kind === 'rpi' ? target.source.workspace : null, candidates: [context.workingDirectory, root] });
            },
        });
        const call = (action, input, extra = {}) => handlers[action]({ instanceId: 'i1', input, ...extra });
        return { store, instance, call, reloads };
    }

    it('tells the agent a canvas shows no session, refuses what needs one, and connects it with show_task', async () => {
        const { call, store, instance } = await setup('not-connected');
        const none = notConnected('missing-session', PATHS.childState);
        Object.assign(instance, { sessionId: none.sessionId, source: none.source });
        const state = await call('get_state', {});
        assert.deepEqual([state.connected, state.source], [false, { kind: 'none', reason: 'missing-session', detail: PATHS.childState }]);
        assert.match(state.nextStep, /show_task/);
        for (const [action, input] of [['take_feedback', {}], ['update_section', { sectionId: 'x', markdown: 'y', baseRevision: 1 }], ['focus_item', { itemId: 'D1' }], ['record_interpretation', { feedbackId: 'FB-001', text: 'x' }]]) {
            assert.equal(await codeOf(() => call(action, input)), 'not_connected', action);
        }
        assert.ok((await call('set_appearance', { theme: 'dark' })).preferences, 'appearance needs no session');
        await call('show_task', { task: ROOT_TASK });
        assert.deepEqual([instance.source.kind, instance.source.taskId], ['rpi', ROOT_TASK], 'show_task connects the canvas');
        assert.equal((await call('get_state', {})).connected, undefined);
        store.close();
    });

    it('moves a canvas that shows no session to the sample only when asked', async () => {
        const { call, store, instance } = await setup('not-connected-sample');
        const none = notConnected('no-input');
        Object.assign(instance, { sessionId: none.sessionId, source: none.source });
        await call('show_task', { task: 'sample' });
        assert.deepEqual([instance.source.kind, instance.sessionId], ['sample', SCENARIO_ID], 'task "sample" without a stage asks for the sample');
        Object.assign(instance, { sessionId: none.sessionId, source: none.source });
        const loaded = await call('load_scenario', { stage: 'plan' });
        assert.deepEqual([instance.source.kind, loaded.activePhase], ['sample', 'plan'], 'load_scenario switches the canvas, not only the stored sample');
        store.close();
    });

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
        assert.deepEqual([state.source.kind, state.source.taskId, state.source.session.tasks.length, state.source.following, state.source.polling], ['rpi', ROOT_TASK, 2, 'enabled', false]);
        assert.deepEqual(state.source.session.tasks.map((task) => [task.taskId, task.shown]), [[ROOT_TASK, true], [CHILD_TASK, false]]);
        store.close();
    });

    it('takes feedback from every task in the session and needs the task for a repeated ID', async () => {
        const { call, store, instance } = await setup('session-feedback');
        const other = await createSourceController({ store }).prepare({ task: CHILD_TASK }, { candidates: [root] });
        other.source.follower.stop();
        const add = async (id, text) => (await store.update(id, (current) => createFeedback(current, { kind: 'comment', text }, NOW), { by: 'user' })).result;
        const mine = await add(instance.sessionId, 'Root note');
        const theirs = await add(other.sessionId, 'Child note');
        assert.equal(mine.id, theirs.id, 'feedback IDs repeat across tasks');
        const state = await call('get_state', {});
        assert.deepEqual(state.otherTasks.map((task) => [task.taskId, task.pendingFeedback.map((entry) => entry.id)]), [[CHILD_TASK, [theirs.id]]]);
        const taken = await call('take_feedback', {});
        assert.deepEqual(taken.items.map((entry) => [entry.taskId, entry.id, entry.text, entry.followUp === true]), [[ROOT_TASK, mine.id, 'Root note', true], [CHILD_TASK, theirs.id, 'Child note', true]]);
        assert.match(taken.note, /passing its taskId/);
        assert.equal(await codeOf(() => call('record_interpretation', { feedbackId: mine.id, text: 'Noted' })), 'invalid_input', 'the ID is waiting in two tasks');
        const read = await call('record_interpretation', { taskId: CHILD_TASK, feedbackId: theirs.id, text: 'Child noted', applied: true });
        assert.deepEqual([read.taskId, read.state], [CHILD_TASK, 'applied']);
        assert.equal((await store.load(instance.sessionId)).feedback.find((entry) => entry.id === mine.id).state, 'sent', 'the root item is untouched');
        const unique = await call('record_interpretation', { feedbackId: mine.id, text: 'Root noted' });
        assert.deepEqual([unique.taskId, unique.state], [ROOT_TASK, 'applied'], 'once only one task waits, the ID is enough, and the read-back applies it');
        assert.equal(await codeOf(() => call('record_interpretation', { taskId: 'nope', feedbackId: mine.id })), 'not_found');
        const third = await add(other.sessionId, 'Sent with others');
        await store.update(other.sessionId, (current) => markDelivered(current, [third.id], 'send', NOW, { tasks: 2 }), { by: 'user' });
        assert.equal(await codeOf(() => call('record_interpretation', { feedbackId: third.id, text: 'x' })), 'invalid_input', 'an item sent with other tasks needs its task');
        other.source.follower.stop();
        store.close();
    });

    it('switches between tasks and the sample', async () => {
        const { call, store, instance, reloads } = await setup('switching');
        for (const input of [{}, { task: 7 }, { task: ROOT_TASK, stage: 'plan' }, { stage: 'later' }]) {
            assert.equal(await codeOf(() => call('show_task', input)), 'invalid_input', JSON.stringify(input));
        }
        const child = await call('show_task', { task: CHILD_TASK });
        assert.deepEqual([child.source.taskId, instance.sessionId], [CHILD_TASK, storeIdFor(CHILD_TASK, root)]);
        assert.equal(instance.source.follow.paused, true, 'a task the agent names that is not running stays shown');
        const sample = await call('show_task', { task: 'sample', stage: 'plan' });
        assert.deepEqual([sample.source, instance.sessionId], [{ kind: 'sample', stage: 'plan' }, SCENARIO_ID]);
        await call('show_task', { task: 'current' }, { session: { workingDirectory: root } });
        assert.equal(instance.sessionId, storeIdFor(ROOT_TASK, root));
        assert.equal(instance.source.follow.paused, false, '"current" asks for where the work is, so following stays on');
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
        const req = http.get({ host: '127.0.0.1', port: url.port, path: `/api/events?k=${url.searchParams.get('k')}` }, (res) => {
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
        const req = http.request({ host: '127.0.0.1', port: url.port, method: 'POST', path: pathname, headers: { 'content-type': 'application/json', 'x-rw-key': url.searchParams.get('k') } }, (res) => {
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
        const followCalls = [];
        const switchOptions = [];
        let sessionId = session.id;
        const server = createCanvasServer({
            store,
            getSessionId: () => sessionId,
            getSource: () => ({ follower }),
            switchTask: async (ref, options) => {
                if (ref.taskId !== 'trail-maps-fixes' && ref.statePath !== PATHS.childState) throw Object.assign(new Error('not in this session'), { code: 'invalid_input' });
                switchOptions.push(['task', options]);
                sessionId = session.id;
                server.rebind(ref.statePath ? { moved: { from: ROOT_TASK, to: CHILD_TASK, title: 'Fixes' } } : {});
                return { sessionId };
            },
            resumeFollowing: async () => {
                followCalls.push('resume');
                server.rebind({});
                return { sessionId };
            },
            pauseFollowing: async () => {
                followCalls.push('pause');
                return { sessionId };
            },
            switchSession: async (key, options) => {
                if (key !== SESSION_KEY) throw Object.assign(new Error('no such session'), { code: 'invalid_input' });
                switchOptions.push(['session', options]);
                return { sessionId };
            },
            listSessions: async () => ({ sessions: [{ key: SESSION_KEY }], skipped: [] }),
        });
        const url = new URL(await server.start());
        const page = stream(url);
        await page.until((event) => event === 'revision');
        assert.deepEqual(calls, ['start']);
        const switched = await post(url, '/api/task', { taskId: 'trail-maps-fixes' });
        assert.deepEqual([switched.status, switched.json.sessionId], [200, session.id]);
        await page.until((event) => event === 'reload');
        assert.deepEqual(calls, ['start', 'start'], 'rebinding restarts following for the new source');
        assert.equal((await post(url, '/api/task', { statePath: PATHS.childState })).status, 200);
        assert.equal((await post(url, '/api/task', { statePath: PATHS.childState, follow: false })).status, 200);
        const resumed = await post(url, '/api/follow', {});
        assert.deepEqual([resumed.status, resumed.json.following], [200, true]);
        const paused = await post(url, '/api/follow', { follow: false });
        assert.deepEqual([paused.status, paused.json.following], [200, false]);
        assert.deepEqual(followCalls, ['resume', 'pause']);
        assert.deepEqual((await post(url, '/api/session', { key: SESSION_KEY })).status, 200);
        assert.deepEqual((await post(url, '/api/session', { key: SESSION_KEY, follow: false })).status, 200);
        assert.deepEqual(switchOptions.map(([kind, options]) => `${kind}:${options.paused}`), ['task:false', 'task:false', 'task:true', 'session:false', 'session:true'], 'only follow: false asks a switch to stay paused');
        assert.deepEqual((await post(url, '/api/session', { key: '../x' })).status, 400);
        const sessions = await new Promise((resolve, reject) => {
            http.get({ host: '127.0.0.1', port: url.port, path: '/api/sessions', headers: { 'x-rw-key': url.searchParams.get('k') } }, (res) => {
                let text = '';
                res.setEncoding('utf8');
                res.on('data', (chunk) => {
                    text += chunk;
                });
                res.on('end', () => resolve(JSON.parse(text)));
            }).on('error', reject);
        });
        assert.deepEqual(sessions.sessions.map((item) => item.key), [SESSION_KEY]);
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

describe('binding a canvas to a Copilot session', () => {
    const OWN = '0c1d2e3f-4a5b-4c6d-8e7f-9a0b1c2d3e4f';
    const BOUND = '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b';
    const UNKNOWN = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';
    const NO_YAML = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
    const NO_TRACKING = 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e';
    const LINKED = 'c3d4e5f6-a7b8-4c9d-8e0f-2a3b4c5d6e7f';
    let scratch;
    let stateRoot;
    let ownRoot;
    let boundRoot;
    let bareRoot;

    before(async () => {
        scratch = await scratchFolder('binding');
        stateRoot = path.join(scratch, 'session-state');
        ownRoot = path.join(scratch, 'own-repo');
        boundRoot = path.join(scratch, 'child-repo');
        bareRoot = path.join(scratch, 'bare-repo');
        await writeFixtureWorkspace(ownRoot);
        await writeFixtureWorkspace(boundRoot);
        await fs.mkdir(bareRoot);
        await fs.writeFile(path.join(scratch, 'outside-state.json'), JSON.stringify({ task_id: 'outside' }));
        await writeSession(BOUND, [`git_root: ${boundRoot}`, `cwd: ${boundRoot}`]);
        await writeSession(NO_YAML, null);
        await writeSession(NO_TRACKING, [`cwd: ${bareRoot}`]);
    });
    after(() => fs.rm(scratch, { recursive: true, force: true }));

    async function writeSession(id, lines) {
        await fs.mkdir(path.join(stateRoot, id), { recursive: true });
        if (lines) await fs.writeFile(path.join(stateRoot, id, 'workspace.yaml'), `${lines.join('\n')}\n`);
    }

    /** A controller whose session-state root is the scratch folder and whose own session is `OWN`. */
    const controller = (store) => createSourceController({ store, sessionRoot: () => stateRoot, ownSessionId: () => OWN, intervalMs: 60000 });

    const post = (url, pathname, body) => new Promise((resolve, reject) => {
        const req = http.request({ host: '127.0.0.1', port: url.port, method: 'POST', path: pathname, headers: { 'content-type': 'application/json', 'x-rw-key': url.searchParams.get('k') } }, (res) => {
            let text = '';
            res.setEncoding('utf8');
            res.on('data', (chunk) => {
                text += chunk;
            });
            res.on('end', () => resolve({ status: res.statusCode, json: JSON.parse(text) }));
        });
        req.on('error', reject);
        req.end(JSON.stringify(body));
    });

    it('accepts a session with a state or task, or alone, and refuses a bad ID or a session with stage or scenario', async () => {
        assert.deepEqual(validateOpenInput({ session: BOUND }, makeError), { session: BOUND });
        assert.deepEqual(validateOpenInput({ session: BOUND, task: 'current' }, makeError), { session: BOUND, task: 'current' });
        assert.deepEqual(validateOpenInput({ session: BOUND, state: PATHS.childState }, makeError), { session: BOUND, state: PATHS.childState });
        for (const bad of [{ session: '../x' }, { session: 'nope' }, { session: 7 }, { session: '' }, { session: `${BOUND}/..` }, { session: BOUND, stage: 'plan' }, { session: BOUND, scenario: SCENARIO_ID }, { session: BOUND, task: 'sample' }]) {
            assert.equal(await codeOf(() => validateOpenInput(bad, makeError)), 'invalid_input', JSON.stringify(bad));
        }
    });

    it('reads a task from the bound session\'s workspace, with state relative to it, and keeps the binding', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-bound') });
        t.after(() => store.close());
        const sources = controller(store);
        const byState = await sources.prepare({ session: BOUND, state: PATHS.childState });
        assert.equal(byState.sessionId, storeIdFor(CHILD_TASK, boundRoot), 'the document is keyed to the bound workspace');
        assert.deepEqual([byState.source.boundSession, byState.source.workspace.root, byState.source.taskId], [BOUND, boundRoot, CHILD_TASK]);
        const current = await sources.prepare({ session: BOUND.toUpperCase() });
        assert.deepEqual([current.source.boundSession, current.source.taskId], [BOUND, ROOT_TASK], 'a session alone shows its current task');
        const byTask = await sources.prepare({ session: BOUND, task: CHILD_TASK });
        assert.equal(byTask.source.taskId, CHILD_TASK);
    });

    it('refuses a state that leaves the bound tracking folder, and a session that cannot be read', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-refusals') });
        t.after(() => store.close());
        const sources = controller(store);
        await assert.rejects(sources.prepare({ session: '../escape', task: 'current' }), { code: 'session_invalid' });
        const traversal = '.copilot-tracking/rpi-sessions/../../../outside-state.json';
        await assert.rejects(sources.prepare({ session: BOUND, state: traversal }), { code: 'source_outside' }, 'traversal out of the tracking folder');
        await assert.rejects(sources.prepare({ session: BOUND, state: path.join(scratch, 'outside-state.json') }), { code: 'source_outside' }, 'an absolute path outside');
        await assert.rejects(sources.prepare({ session: BOUND, state: PATHS.plan }), { code: 'invalid_input' }, 'not a state file');
        await assert.rejects(sources.prepare({ session: UNKNOWN, task: 'current' }), { code: 'session_not_found' });
        await assert.rejects(sources.prepare({ session: NO_YAML, task: 'current' }), { code: 'session_no_workspace' });
        await assert.rejects(sources.prepare({ session: NO_TRACKING, task: 'current' }), { code: 'session_no_tracking' });
    });

    it('refuses a bound workspace whose tracking folder is a symbolic link', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-linked') });
        t.after(() => store.close());
        const real = path.join(scratch, 'real-tracking-repo');
        const linked = path.join(scratch, 'linked-tracking-repo');
        await fs.mkdir(path.join(real, '.copilot-tracking'), { recursive: true });
        await fs.mkdir(linked);
        await writeSession(LINKED, [`cwd: ${linked}`]);
        if (!(await symlinkOrSkip(t, path.join(real, '.copilot-tracking'), path.join(linked, '.copilot-tracking'), 'dir'))) return;
        await assert.rejects(controller(store).prepare({ session: LINKED, task: 'current' }), { code: 'session_no_tracking' });
    });

    it('resolves the conversation\'s own session from the candidates, as it does without session', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-own') });
        t.after(() => store.close());
        const sources = controller(store);
        const own = await sources.prepare({ session: OWN, task: 'current' }, { candidates: [ownRoot] });
        assert.deepEqual([own.source.boundSession, own.source.workspace.root], [null, ownRoot], 'the own session keeps no binding');
        const plain = await sources.prepare({ task: 'current' }, { candidates: [ownRoot] });
        assert.equal(own.sessionId, plain.sessionId);
    });

    it('keeps the bound session across show_task calls that omit it, and moves when another session is named', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-sticky') });
        t.after(() => store.close());
        const sources = controller(store);
        const record = { sessionId: '', source: null, server: { rebind: () => {} } };
        sources.attach(record, await sources.prepare({ session: BOUND, state: PATHS.childState }));
        await sources.show(record, { state: PATHS.rootState });
        assert.deepEqual([record.source.boundSession, record.source.taskId, record.source.workspace.root], [BOUND, ROOT_TASK, boundRoot], 'a state path is relative to the bound workspace');
        await sources.show(record, { task: 'current' });
        assert.deepEqual([record.source.boundSession, record.source.taskId], [BOUND, ROOT_TASK]);
        await sources.show(record, { session: BOUND });
        assert.equal(record.source.follow.paused, false, 'a session alone asks for where the work is, so following stays on');
        await sources.show(record, { session: OWN, task: 'current' }, { candidates: [ownRoot] });
        assert.deepEqual([record.source.boundSession, record.source.workspace.root], [null, ownRoot], 'another session replaces the binding');
        sources.detach(record);
    });

    it('remembers the bound session with the state path, and a reopen that cannot read it says why', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-memory') });
        t.after(() => store.close());
        const sources = controller(store);
        const record = { instanceId: 'bound-panel', sessionId: '', source: null, server: { rebind: () => {} }, hostSessionId: 'chat-1' };
        sources.attach(record, await sources.prepare({ session: BOUND, state: PATHS.childState }));
        await sources.settled(record);
        assert.equal(sourceSummary(record, await store.load(record.sessionId)).boundSession, BOUND);
        const memory = await store.loadInstance('bound-panel', 'chat-1');
        assert.deepEqual([memory.kind, memory.state, memory.session], ['rpi', PATHS.childState, BOUND]);
        sources.detach(record);

        const plan = openPlan({}, { open: false, remembered: memory });
        assert.deepEqual(plan.restore, { state: PATHS.childState, paused: false, session: BOUND });
        const back = await sources.restore(plan.restore, {});
        assert.deepEqual([back.source.kind, back.source.boundSession, back.source.taskId], ['rpi', BOUND, CHILD_TASK]);

        const cases = [
            [{ ...plan.restore, session: UNKNOWN }, 'session-not-found', UNKNOWN],
            [{ ...plan.restore, session: 'not-a-session' }, 'session-not-found', plan.restore.state],
            [{ ...plan.restore, session: NO_YAML }, 'session-no-workspace', path.join(stateRoot, NO_YAML, 'workspace.yaml')],
            [{ ...plan.restore, session: NO_TRACKING }, 'session-no-tracking', path.join(bareRoot, '.copilot-tracking')],
            [{ ...plan.restore, state: '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/missing-state.json' }, 'missing-session', '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/missing-state.json'],
        ];
        for (const [restore, reason, detail] of cases) {
            const outcome = await sources.restore(restore, {});
            assert.deepEqual([outcome.source.kind, outcome.source.reason, outcome.source.detail], ['none', reason, detail], reason);
        }
        assert.equal((await sources.restore({ task: 'sample' }, {})).source.kind, 'sample', 'a remembered sample restores as before');
    });

    it('shows another session\'s task through show_task, and refuses a session that is not one', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-actions') });
        t.after(() => store.close());
        const sources = controller(store);
        const prepared = await sources.prepare({ task: 'current' }, { candidates: [ownRoot] });
        const instance = { server: { url: 'http://127.0.0.1:1/', clientInfo: null, streamClients: 0, notifyReload: () => {}, rebind: () => {} }, sessionId: prepared.sessionId, source: prepared.source };
        const handlers = createActionHandlers({
            getInstance: (id) => (id === 'i1' ? instance : undefined),
            store,
            makeError,
            async switchSource(target, request, context) {
                return sources.show(target, request, { candidates: [context.workingDirectory, ownRoot] });
            },
        });
        const call = (input) => handlers.show_task({ instanceId: 'i1', input });
        for (const bad of [{ session: '../nope' }, { session: BOUND, stage: 'plan' }, { session: BOUND, task: 'sample' }]) {
            assert.equal(await codeOf(() => call(bad)), 'invalid_input', JSON.stringify(bad));
        }
        assert.equal(await codeOf(() => call({ session: UNKNOWN })), 'session_not_found');
        const shown = await call({ session: BOUND, state: PATHS.childState });
        assert.deepEqual([shown.source.kind, shown.source.boundSession, shown.source.taskId], ['rpi', BOUND, CHILD_TASK]);
        assert.equal((await call({ session: BOUND })).source.taskId, ROOT_TASK);
        assert.equal((await call({ task: CHILD_TASK })).source.boundSession, BOUND, 'a task without session keeps the session shown');
    });

    it('names the session in the message about a task of another session, and not for the own session', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-messages') });
        t.after(() => store.close());
        const sources = controller(store);
        const shown = await sources.prepare({ session: BOUND, state: PATHS.childState });
        const { result } = await store.update(shown.sessionId, (current) => createFeedback(current, { kind: 'comment', text: 'Check the child' }, NOW), { by: 'user' });
        const items = [{ taskId: CHILD_TASK, id: result.id }];
        const expected = `RPI canvas 3WF0 has 1 item for session ${BOUND} (task ${CHILD_TASK}, state .copilot-tracking/rpi-sessions/`;

        const elsewhere = createCanvasServer({ store, getSessionId: () => shown.sessionId, getCanvas: () => ({ handle: '3WF0', instanceId: 'panel' }), getSource: () => shown.source, getJoinedSessionId: () => OWN, deliver: async () => {} });
        const away = await post(new URL(await elsewhere.start()), '/api/delivery/preview', { items });
        assert.equal(away.status, 200);
        assert.deepEqual([away.json.route.kind, away.json.route.sessionId], ['relay', BOUND]);
        assert.ok(away.json.prompt.startsWith(expected), away.json.prompt);

        const home = createCanvasServer({ store, getSessionId: () => shown.sessionId, getCanvas: () => ({ handle: '3WF0', instanceId: 'panel' }), getSource: () => shown.source, getJoinedSessionId: () => BOUND, deliver: async () => {} });
        const same = await post(new URL(await home.start()), '/api/delivery/preview', { items });
        assert.equal(same.status, 200);
        assert.doesNotMatch(same.json.prompt, /in session/);
        assert.match(same.json.prompt, /Task files:\n- State: \.copilot-tracking\/rpi-sessions\//);
        assert.notEqual(same.json.digest, away.json.digest, 'the digest covers the session line');
    });
});

