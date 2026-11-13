// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { DEFAULT_LIMIT, listRpiSessions } from '../lib/source/session-list.mjs';
import { resolveSessionWorkspace } from '../lib/source/sessions.mjs';
import { loadTask } from '../lib/source/workspace.mjs';
import { scratchFolder, symlinkOrSkip } from './helpers/scratch.mjs';
import { PATHS, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

const NOW = Date.parse('2026-01-15T12:00:00.000Z');
const minutesAgo = (minutes) => new Date(NOW - minutes * 60 * 1000).toISOString();
/** A valid session ID for test number `n`. */
const sid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;

let scratch;
before(async () => {
    scratch = await scratchFolder('session-list');
});
after(() => fs.rm(scratch, { recursive: true, force: true }));

/** A folder for one test's workspaces and its session-state root. */
async function world(name) {
    const base = path.join(scratch, name);
    const root = path.join(base, 'session-state');
    await fs.mkdir(root, { recursive: true });
    return { base, root };
}

/**
 * A workspace folder with a tracking folder and, when `task` is given, one RPI state file whose plan
 * is titled `title`. Returns the folder.
 */
async function workspace(dir, task = null) {
    await fs.mkdir(path.join(dir, '.copilot-tracking'), { recursive: true });
    if (task) {
        const { title = 'Offline trail maps', phase = 'Plan', status = 'active', sessionStatus = 'running' } = task;
        const folder = path.join(dir, '.copilot-tracking', 'rpi-sessions', '2026-01-15', task.id);
        await fs.mkdir(folder, { recursive: true });
        const plan = `.copilot-tracking/plans/2026-01-15/${task.id}-plan.md`;
        await fs.mkdir(path.dirname(path.join(dir, plan)), { recursive: true });
        await fs.writeFile(path.join(dir, plan), `# RPI Plan: ${title}\n`);
        const state = { task_id: task.id, task_slug: task.id, mode: 'manual', active_phase: phase, status, session_status: sessionStatus, artifact_paths: { plan } };
        await fs.writeFile(path.join(folder, `${task.id}-state.json`), JSON.stringify(state));
    }
    return dir;
}

/**
 * A session folder under `root`, with its workspace.yaml lines when given. The file's modification time
 * is its `updated_at`, as when the CLI writes it, or `mtime` when given.
 */
async function session(root, id, lines, mtime = null) {
    const folder = path.join(root, id);
    await fs.mkdir(folder, { recursive: true });
    if (lines) {
        const file = path.join(folder, 'workspace.yaml');
        await fs.writeFile(file, `${lines.join('\n')}\n`);
        const updated = lines.find((line) => line.startsWith('updated_at: '))?.slice('updated_at: '.length);
        const at = mtime ?? (updated ? new Date(updated) : null);
        if (at) await fs.utimes(file, at, at);
    }
    return folder;
}

/** The workspace.yaml lines of a session that works in `dir`, last updated `minutes` ago when given. */
const inDir = (dir, { name, repository = 'microsoft/trails', branch = 'main', minutes } = {}) => [
    ...(name ? [`name: ${name}`] : []),
    `cwd: ${dir}`,
    `git_root: ${dir}`,
    ...(repository ? [`repository: ${repository}`] : []),
    ...(branch ? [`branch: ${branch}`] : []),
    ...(minutes === undefined ? [] : [`updated_at: ${minutesAgo(minutes)}`]),
];

const idsOf = (result) => result.sessions.map((entry) => entry.sessionId);

describe('listing the sessions with RPI work', () => {
    it('lists the sessions the conversation started first, in the order given, then the others newest first', async () => {
        const { base, root } = await world('order');
        await session(root, sid(1), inDir(await workspace(path.join(base, 'a'), { id: 'trail-maps' }), { name: 'Trail maps', minutes: 50 }));
        await session(root, sid(2), inDir(await workspace(path.join(base, 'b'), { id: 'map-api' }), { minutes: 40 }));
        await session(root, sid(3), inDir(await workspace(path.join(base, 'c'), { id: 'tiles' }), { minutes: 5 }));
        await session(root, sid(4), inDir(await workspace(path.join(base, 'd'), { id: 'routes' }), { minutes: 30 }));
        const result = await listRpiSessions({ root, mine: [sid(2), sid(1)], own: null, now: () => NOW });
        assert.deepEqual(idsOf(result), [sid(2), sid(1), sid(3), sid(4)]);
        assert.deepEqual(result.sessions.map((entry) => entry.mine), [true, true, false, false]);
        assert.equal(result.skipped, 0);
    });

    it('reads the name, repository, and branch from workspace.yaml, and titles the task as the canvas does', async () => {
        const { base, root } = await world('fields');
        const dir = await writeFixtureWorkspace(path.join(base, 'trails'));
        await session(root, sid(1), inDir(dir, { name: 'Offline trail maps', minutes: 1 }));
        const [entry] = (await listRpiSessions({ root, mine: [sid(1)], now: () => NOW })).sessions;
        assert.deepEqual(entry, {
            sessionId: sid(1),
            name: 'Offline trail maps',
            repository: 'microsoft/trails',
            branch: 'main',
            mine: true,
            own: false,
            live: false,
            task: { taskId: 'trail-maps', title: 'Offline trail maps', phase: 'followup', status: 'completed', statePath: PATHS.rootState },
            problem: null,
        });
        const loaded = await loadTask(await resolveSessionWorkspace(sid(1), { root }), PATHS.rootState, new Date(NOW).toISOString());
        assert.equal(entry.task.title, loaded.session.task.title, 'the title is the one the canvas shows for the task');
    });

    it('limits the other sessions to the most recently updated ones, and does not count the sessions the conversation started', async () => {
        const { base, root } = await world('limit');
        for (let n = 1; n <= 3; n += 1) {
            await session(root, sid(n), inDir(await workspace(path.join(base, `w${n}`), { id: `task-${n}` }), { minutes: n * 10 }));
        }
        const limited = await listRpiSessions({ root, mine: [sid(3)], limit: 1, now: () => NOW });
        assert.deepEqual(idsOf(limited), [sid(3), sid(1)], 'the started session is listed, and one other session is examined');
    });

    it('orders other sessions by when their workspace.yaml last changed, and examines a folder without one last', async () => {
        const { base, root } = await world('mtime');
        await session(root, sid(1), inDir(await workspace(path.join(base, 'a'), { id: 'trail-maps' }), { minutes: 90 }));
        await session(root, sid(2), inDir(await workspace(path.join(base, 'b'), { id: 'map-api' }), { repository: null, branch: null }), new Date(NOW - 10 * 60 * 1000));
        await session(root, sid(3), inDir(await workspace(path.join(base, 'c'), { id: 'tiles' }), { repository: null, branch: null }), new Date(NOW - 180 * 60 * 1000));
        await session(root, sid(4), null);
        assert.deepEqual(idsOf(await listRpiSessions({ root, now: () => NOW })), [sid(2), sid(1), sid(3)]);
        assert.equal((await listRpiSessions({ root, limit: 3, now: () => NOW })).skipped, 0, 'the folder without a workspace.yaml is not among the three examined');
    });

    it('resolves the session-state folder once, reads each listed session\'s workspace.yaml once, and opens none of the others', async () => {
        const { base, root } = await world('reads');
        for (let n = 1; n <= 5; n += 1) {
            await session(root, sid(n), inDir(await workspace(path.join(base, `w${n}`), { id: `task-${n}` }), { minutes: n }));
        }
        const reads = [];
        let rootResolved = 0;
        const counting = {
            readFile: async (file, ...rest) => {
                reads.push(file);
                return fs.readFile(file, ...rest);
            },
            realpath: async (target, ...rest) => {
                if (target === root) rootResolved += 1;
                return fs.realpath(target, ...rest);
            },
        };
        const result = await listRpiSessions({ root, mine: [sid(5)], limit: 2, now: () => NOW, fs: counting });
        assert.deepEqual(idsOf(result), [sid(5), sid(1), sid(2)]);
        const yamlReads = reads.filter((file) => path.basename(file) === 'workspace.yaml').map((file) => path.basename(path.dirname(file)));
        assert.deepEqual(yamlReads.sort(), [sid(1), sid(2), sid(5)].sort());
        assert.equal(rootResolved, 1);
    });

    it('lists each workspace once, under its most recently updated session, and never under a session the conversation started', async () => {
        const { base, root } = await world('dedupe');
        const shared = await workspace(path.join(base, 'shared'), { id: 'trail-maps' });
        const started = await workspace(path.join(base, 'started'), { id: 'map-api' });
        await session(root, sid(1), inDir(shared, { minutes: 60 }));
        await session(root, sid(2), inDir(shared, { minutes: 20 }));
        await session(root, sid(3), inDir(started, { minutes: 15 }));
        await session(root, sid(4), inDir(started, { minutes: 5 }));
        assert.deepEqual(idsOf(await listRpiSessions({ root, mine: [sid(3)], now: () => NOW })), [sid(3), sid(2)]);
    });

    it('gives each problem its reason, lists the sessions the conversation started with it, and counts the other sessions it skips', async () => {
        const { base, root } = await world('problems');
        const untracked = path.join(base, 'untracked');
        await fs.mkdir(untracked, { recursive: true });
        const quiet = await workspace(path.join(base, 'quiet'));
        await fs.mkdir(path.join(quiet, '.copilot-tracking', 'rpi-sessions', '2026-01-15', 'broken'), { recursive: true });
        await fs.writeFile(path.join(quiet, '.copilot-tracking', 'rpi-sessions', '2026-01-15', 'broken', 'broken-state.json'), '{ not json');
        await session(root, sid(1), null);
        await session(root, sid(2), ['name: Unplaced']);
        await session(root, sid(3), inDir(untracked, { name: 'Untracked' }));
        await session(root, sid(4), inDir(quiet, { name: 'Quiet' }));
        await session(root, sid(5), inDir(untracked, { minutes: 3 }));
        const result = await listRpiSessions({ root, mine: [sid(1), sid(2), sid(3), sid(4), sid(9)], now: () => NOW });
        assert.deepEqual(result.sessions.map((entry) => [entry.sessionId, entry.problem]), [
            [sid(1), 'no-workspace'],
            [sid(2), 'no-workspace'],
            [sid(3), 'no-tracking'],
            [sid(4), 'no-rpi'],
            [sid(9), 'not-found'],
        ]);
        assert.ok(result.sessions.every((entry) => entry.mine && entry.task === null));
        assert.equal(result.sessions[2].name, 'Untracked', 'a problem still names the session');
        assert.equal(result.skipped, 1, 'the other session without a tracking folder is counted and left out');
        assert.deepEqual(await listRpiSessions({ root, now: () => NOW }).then((found) => [found.sessions, found.skipped]), [[], 5], 'with none started, every session is another with a problem');
    });

    it('counts the other sessions it examines, which are the most recently updated up to the default limit', async () => {
        const { base, root } = await world('skipped');
        const plain = path.join(base, 'plain');
        await fs.mkdir(plain, { recursive: true });
        for (let n = 1; n <= DEFAULT_LIMIT + 2; n += 1) await session(root, sid(n), inDir(plain, { minutes: n }));
        const result = await listRpiSessions({ root, now: () => NOW });
        assert.equal(DEFAULT_LIMIT, 30);
        assert.deepEqual([result.sessions.length, result.skipped], [0, DEFAULT_LIMIT]);
    });

    it('never follows a symbolic link to a session folder, as a listed session or as one the conversation started', async (t) => {
        const { base, root } = await world('links');
        const real = await workspace(path.join(base, 'real'), { id: 'trail-maps' });
        const elsewhere = await session(path.join(base, 'elsewhere'), sid(1), inDir(real, { minutes: 1 }));
        if (!await symlinkOrSkip(t, elsewhere, path.join(root, sid(1)), 'dir')) return;
        assert.deepEqual(await listRpiSessions({ root, now: () => NOW }), { sessions: [], skipped: 0 });
        const started = await listRpiSessions({ root, mine: [sid(1)], now: () => NOW });
        assert.deepEqual(started.sessions.map((entry) => [entry.sessionId, entry.problem]), [[sid(1), 'not-found']]);
    });

    it('reports whether a canvas runs for each session, and which session is the conversation\'s own', async () => {
        const { base, root } = await world('live');
        await session(root, sid(1), inDir(await workspace(path.join(base, 'a'), { id: 'trail-maps' }), { minutes: 1 }));
        await session(root, sid(2), inDir(await workspace(path.join(base, 'b'), { id: 'map-api' }), { minutes: 2 }));
        await session(root, sid(3), inDir(await workspace(path.join(base, 'c'), { id: 'tiles' }), { minutes: 3 }));
        const presence = new Map([
            [sid(1), { sessionId: sid(1), processes: [{ pid: 1, version: 1, updatedAt: minutesAgo(1) }] }],
            [sid(2), { sessionId: sid(2), processes: [{ pid: 2, version: 1, updatedAt: minutesAgo(30) }] }],
        ]);
        const loadPresence = async (sessionId) => {
            if (sessionId === sid(3)) throw new Error('unreadable presence');
            return presence.get(sessionId) ?? { sessionId, processes: [] };
        };
        const result = await listRpiSessions({ root, own: sid(2).toUpperCase(), loadPresence, now: () => new Date(NOW).toISOString() });
        assert.deepEqual(result.sessions.map((entry) => [entry.sessionId, entry.live, entry.own]), [
            [sid(1), true, false],
            [sid(2), false, true],
            [sid(3), false, false],
        ], 'a presence entry older than its window is not live, and an unreadable presence is not live');
    });

    it('treats a session-state folder that does not exist as having no sessions, and marks the sessions the conversation started as not found', async () => {
        const { base } = await world('absent');
        const result = await listRpiSessions({ root: path.join(base, 'missing'), mine: [sid(1)], now: () => NOW });
        assert.deepEqual(result, { sessions: [{ sessionId: sid(1), name: null, repository: null, branch: null, mine: true, own: false, live: false, task: null, problem: 'not-found' }], skipped: 0 });
    });

    it('titles the current task by its artifact, or by its ID when it has none, and reads the running task over a stopped one', async () => {
        const { base, root } = await world('current');
        const dir = await workspace(path.join(base, 'w'), { id: 'older', title: 'Older work', sessionStatus: 'stopped', status: 'completed' });
        const newer = path.join(dir, '.copilot-tracking', 'rpi-sessions', '2026-01-15', 'newer');
        await fs.mkdir(newer, { recursive: true });
        await fs.writeFile(path.join(newer, 'newer-state.json'), JSON.stringify({ task_id: 'newer', active_phase: 'Implement', status: 'active', session_status: 'running' }));
        await session(root, sid(1), inDir(dir, { minutes: 1 }));
        const [entry] = (await listRpiSessions({ root, mine: [sid(1)], now: () => NOW })).sessions;
        assert.deepEqual([entry.task.taskId, entry.task.phase, entry.task.status, entry.task.title], ['newer', 'implement', 'running', 'newer']);
    });
});
