// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { symlinkOrSkip } from '../../session-log/tests/helpers.mjs';
import { lineageStatusOf } from '../lib/source/assemble.mjs';
import { parseState } from '../lib/source/parse.mjs';
import { resolveSessionWorkspace } from '../lib/source/sessions.mjs';
import { agentTask, buildTree, humanizeSlug, linkKey, nextFollowTarget } from '../lib/source/tree.mjs';
import { loadState, resolveWorkspace, sessionTreeOf } from '../lib/source/workspace.mjs';
import { scratchFolder } from './helpers/scratch.mjs';

const DIR = '.copilot-tracking/rpi-sessions/2026-10-23/rpi-workflow-canvas';
const pathOf = (id) => `${DIR}/${id}-state.json`;

/**
 * A tree member from a compact spec. `parent` and `children` take task IDs.
 *
 * @param {string} id
 * @param {{ parent?: string, children?: string[], status?: string, session?: string, mtime?: number, pathless?: boolean }} [spec]
 */
function member(id, spec = {}) {
    const state = parseState({
        task_id: id,
        status: spec.status ?? 'active',
        session_status: spec.session ?? 'stopped',
        parent_task: spec.parent ? { task_id: spec.parent, ...(spec.pathless ? {} : { state_path: pathOf(spec.parent) }) } : null,
        child_tasks: (spec.children ?? []).map((child) => ({ task_id: child, state_path: pathOf(child) })),
    });
    return { path: pathOf(id), mtimeMs: spec.mtime ?? 0, state, title: `Title ${id}`, status: lineageStatusOf(state) };
}

const shape = (tasks) => tasks.map((task) => `${'  '.repeat(task.depth)}${task.id}${task.shown ? '*' : ''}`);

describe('session tree', () => {
    it('nests a chain and marks the shown task', () => {
        const { tasks, warnings } = buildTree({
            members: [member('c', { parent: 'b' }), member('a', { children: ['b'] }), member('b', { parent: 'a', children: ['c'] })],
            shownPath: pathOf('b'),
        });
        assert.deepEqual(shape(tasks), ['a', '  b*', '    c']);
        assert.deepEqual(tasks.map((task) => task.parent), [null, pathOf('a'), pathOf('b')]);
        assert.deepEqual(warnings, []);
    });

    it('orders a fan as the parent lists it, then unlisted children by age with a warning', () => {
        const { tasks, warnings } = buildTree({
            members: [
                member('root', { children: ['two', 'one'] }),
                member('one', { parent: 'root' }),
                member('two', { parent: 'root' }),
                member('late', { parent: 'root', mtime: 20 }),
                member('early', { parent: 'root', mtime: 10 }),
            ],
            shownPath: pathOf('root'),
        });
        assert.deepEqual(shape(tasks), ['root*', '  two', '  one', '  early', '  late']);
        assert.deepEqual(warnings, ['root does not list its child early in child_tasks.', 'root does not list its child late in child_tasks.']);
    });

    it('falls back to the parent task ID within the folder and lets a listing parent adopt an unlinked child', () => {
        const { tasks, warnings } = buildTree({
            members: [member('root', { children: ['adopted'] }), member('by-id', { parent: 'root', pathless: true }), member('adopted')],
            shownPath: pathOf('root'),
        });
        assert.deepEqual(shape(tasks), ['root*', '  adopted', '  by-id']);
        assert.deepEqual(warnings, ['root does not list its child by-id in child_tasks.']);
    });

    it('reports missing children and parents, and lists unreachable loops once', () => {
        const { tasks, warnings } = buildTree({
            members: [member('root', { children: ['gone'] }), member('orphan', { parent: 'missing' }), member('x', { parent: 'y' }), member('y', { parent: 'x' })],
            shownPath: pathOf('x'),
        });
        assert.deepEqual(shape(tasks), ['orphan', 'root', 'x*', '  y']);
        assert.deepEqual(warnings, [
            'orphan continues missing, which is not in this session.',
            'root lists child gone, whose state file is missing.',
            'x is not reached from a top-level task; its parent links form a loop.',
            'x does not list its child y in child_tasks.',
            'y does not list its child x in child_tasks.',
        ]);
    });

    it('shows a parent from another session as context, or why it could not be read', () => {
        const outside = new Map([
            ['.copilot-tracking/rpi-sessions/2026-10-01/earlier/base-state.json', { id: 'base', title: 'Base', statePath: '.copilot-tracking/rpi-sessions/2026-10-01/earlier/base-state.json', session: '2026-10-01/earlier', status: 'completed' }],
            ['.copilot-tracking/plans/x-state.json', { error: 'refused.' }],
        ]);
        const continued = member('continued');
        continued.state.parent = { taskId: 'base', taskSlug: 'base', statePath: '.copilot-tracking/rpi-sessions/2026-10-01/earlier/base-state.json' };
        const refused = member('refused');
        refused.state.parent = { taskId: 'x', taskSlug: 'x', statePath: '.copilot-tracking/plans/x-state.json' };
        const { tasks, warnings } = buildTree({ members: [continued, refused], shownPath: pathOf('continued'), outside });
        assert.deepEqual(tasks.map((task) => [task.id, task.depth, task.continues?.session ?? null]), [['continued', 0, '2026-10-01/earlier'], ['refused', 0, null]]);
        assert.deepEqual(warnings, ['refused continues x, which could not be read: refused.']);
    });

    it('humanizes a folder name for a session without a name', () => {
        assert.equal(humanizeSlug('rpi-workflow-canvas'), 'Rpi workflow canvas');
        assert.equal(humanizeSlug(''), '');
    });
});

describe('following the running loop', () => {
    const tree = (members, shown = members[0].state.taskId) => buildTree({ members, shownPath: pathOf(shown) }).tasks;

    it('moves along a chain once the followed task stops running', () => {
        const tasks = tree([member('a', { status: 'completed', session: 'running', children: ['b'] }), member('b', { parent: 'a', session: 'running' })]);
        assert.equal(nextFollowTarget(tasks, pathOf('a'))?.id, 'b');
        assert.equal(nextFollowTarget(tasks, pathOf('b')), null, 'the running child stays');
    });

    it('stays while the followed task runs, even with one running child', () => {
        const tasks = tree([member('a', { session: 'running', children: ['b'] }), member('b', { parent: 'a', session: 'running' })]);
        assert.equal(nextFollowTarget(tasks, pathOf('a')), null);
    });

    it('follows the running loop that changed last when several run, and the only running one in a fan', () => {
        const parallel = tree([member('a', { status: 'completed', children: ['b', 'c'] }), member('b', { parent: 'a', session: 'running', mtime: 20 }), member('c', { parent: 'a', session: 'running', mtime: 10 })]);
        assert.equal(nextFollowTarget(parallel, pathOf('a'))?.id, 'b');
        const tied = tree([member('a', { status: 'completed', children: ['b', 'c'] }), member('b', { parent: 'a', session: 'running' }), member('c', { parent: 'a', session: 'running' })]);
        assert.equal(nextFollowTarget(tied, pathOf('a'))?.id, 'b', 'a tie goes to tree order');
        const fan = tree([member('a', { status: 'completed', children: ['b', 'c'] }), member('b', { parent: 'a', status: 'completed' }), member('c', { parent: 'a', session: 'running' })]);
        assert.equal(nextFollowTarget(fan, pathOf('a'))?.id, 'c');
    });

    it('moves to a running loop that is not a child of the followed task', () => {
        const chain = tree([
            member('a', { status: 'completed', children: ['b'] }),
            member('b', { parent: 'a', status: 'completed', children: ['c'] }),
            member('c', { parent: 'b', session: 'running' }),
        ]);
        assert.equal(nextFollowTarget(chain, pathOf('a'))?.id, 'c', 'from the root, past a completed loop');
        const apart = tree([member('a', { status: 'completed' }), member('z', { session: 'running' })]);
        assert.equal(nextFollowTarget(apart, pathOf('a'))?.id, 'z', 'to another task of the session');
    });

    it('stays in a stopped session and on an unknown task', () => {
        const stopped = tree([member('a', { children: ['b'] }), member('b', { parent: 'a' })]);
        assert.equal(nextFollowTarget(stopped, pathOf('a')), null);
        assert.equal(nextFollowTarget(stopped, pathOf('nope')), null);
    });

    it('finds where the agent works: the running task, else the latest loop', () => {
        const running = tree([member('a', { status: 'completed', children: ['b'], mtime: 30 }), member('b', { parent: 'a', session: 'running', mtime: 5 })]);
        assert.equal(agentTask(running)?.id, 'b');
        const stopped = tree([
            member('a', { status: 'completed', children: ['b', 'c'], mtime: 50 }),
            member('b', { parent: 'a', status: 'completed', mtime: 10 }),
            member('c', { parent: 'a', status: 'completed', mtime: 20 }),
        ]);
        assert.equal(agentTask(stopped)?.id, 'c', 'the root changed last but continues into loops, so the latest loop wins');
        assert.equal(agentTask([]), null);
        assert.ok(running.every((task) => typeof task.changedAt === 'number'), 'tree tasks carry their change time');
    });

    it('moves from this session\'s completed root, whose session still runs, to its running child', () => {
        const root = member('rpi-workflow-canvas', { status: 'completed', session: 'running', children: ['rpi-workflow-canvas-sessions'] });
        const child = member('rpi-workflow-canvas-sessions', { parent: 'rpi-workflow-canvas', status: 'active', session: 'running' });
        assert.deepEqual([root.status, child.status], ['completed', 'running']);
        const tasks = tree([root, child]);
        assert.equal(nextFollowTarget(tasks, pathOf('rpi-workflow-canvas'))?.id, 'rpi-workflow-canvas-sessions');
    });
});

const SESSION_B = 'bbbbbbbb-1111-4222-8333-444444444444';
const SESSION_C = 'cccccccc-2222-4333-8444-555555555555';

/** A task link to a state file of another Copilot session, as a `child_tasks` entry or `parent_task` names it. */
const linkTo = (id, sessionId) => ({ task_id: id, task_slug: id, state_path: pathOf(id), session_id: sessionId });

/** The key a parsed link to task `id` in `sessionId` is stored under in `outside`. */
const keyOf = (id, sessionId) => linkKey({ taskId: id, statePath: pathOf(id), sessionId });

/** A task of another Copilot session, as the reader reports it through a link. */
const linkedTask = (id, sessionId, extra = {}) => ({
    id,
    title: `Title ${id}`,
    status: 'running',
    statePath: pathOf(id),
    session: `2026-01-15/${id}`,
    changedAt: 0,
    phase: 'plan',
    sessionId,
    sessionName: `Session ${id}`,
    root: '/work/other',
    ...extra,
});

describe('session-qualified links in a tree', () => {
    it('places a linked child where its parent lists it, among the folder\'s own children', () => {
        const root = { path: pathOf('root'), mtimeMs: 0, state: parseState({ task_id: 'root', child_tasks: [linkTo('remote', SESSION_B), { task_id: 'local-a', state_path: pathOf('local-a') }] }), title: 'Title root', status: 'completed' };
        const outside = new Map([[keyOf('remote', SESSION_B), linkedTask('remote', SESSION_B)]]);
        const { tasks, warnings } = buildTree({ members: [root, member('local-a', { parent: 'root' })], shownPath: pathOf('root'), outside });
        assert.deepEqual(shape(tasks), ['root*', '  remote', '  local-a']);
        const [, linked] = tasks;
        assert.deepEqual([linked.sessionId, linked.sessionName, linked.phase, linked.root, linked.parent, linked.shown, linked.continues], [SESSION_B, `Session remote`, 'plan', '/work/other', pathOf('root'), false, null]);
        assert.deepEqual(tasks.filter((task) => task.sessionId === null).map((task) => task.id), ['root', 'local-a']);
        assert.deepEqual(warnings, []);
    });

    it('lists a linked child that cannot be read with its session and state path, and never matches a task of this folder by ID or path', () => {
        const twin = member('local-twin');
        const root = { path: pathOf('root'), mtimeMs: 0, state: parseState({ task_id: 'root', child_tasks: [linkTo('local-twin', SESSION_B), linkTo('gone', SESSION_C)] }), title: 'Title root', status: 'completed' };
        const outside = new Map([[keyOf('gone', SESSION_C), { error: `No Copilot session ${SESSION_C} was found in /work/session-state.` }]]);
        const { tasks, warnings } = buildTree({ members: [root, twin], shownPath: pathOf('root'), outside });
        assert.deepEqual(shape(tasks), ['local-twin', 'root*'], 'the linked child is not the folder\'s twin, so the twin stays a top-level task');
        assert.deepEqual(warnings, [
            `root lists child local-twin in Copilot session ${SESSION_B} at ${pathOf('local-twin')}, which could not be read.`,
            `root lists child gone in Copilot session ${SESSION_C} at ${pathOf('gone')}, which could not be read: No Copilot session ${SESSION_C} was found in /work/session-state.`,
        ]);
    });

    it('continues a parent in another session, and names the session when that parent cannot be read', () => {
        const continued = member('continued');
        continued.state.parent = { taskId: 'base', taskSlug: 'base', statePath: pathOf('base'), sessionId: SESSION_B };
        const refused = member('refused');
        refused.state.parent = { taskId: 'x', taskSlug: 'x', statePath: pathOf('x'), sessionId: 'not-a-session' };
        const outside = new Map([
            [linkKey(continued.state.parent), linkedTask('base', SESSION_B, { status: 'completed' })],
            [linkKey(refused.state.parent), { error: 'session must be a Copilot session ID.' }],
        ]);
        const { tasks, warnings } = buildTree({ members: [continued, refused], shownPath: pathOf('continued'), outside });
        assert.deepEqual(tasks.map((task) => [task.id, task.continues?.sessionId ?? null, task.continues?.sessionName ?? null]), [['continued', SESSION_B, 'Session base'], ['refused', null, null]]);
        assert.deepEqual(warnings, [`refused continues x in Copilot session not-a-session at ${pathOf('x')}, which could not be read: session must be a Copilot session ID.`]);
    });

    it('never follows or takes the agent\'s place from a task in another session', () => {
        const root = { path: pathOf('a'), mtimeMs: 0, state: parseState({ task_id: 'a', child_tasks: [linkTo('remote', SESSION_B)] }), title: 'Title a', status: 'completed' };
        const outside = new Map([[keyOf('remote', SESSION_B), linkedTask('remote', SESSION_B, { changedAt: 99 })]]);
        const tasks = buildTree({ members: [root], shownPath: pathOf('a'), outside }).tasks;
        assert.equal(tasks.at(-1).sessionId, SESSION_B);
        assert.equal(nextFollowTarget(tasks, pathOf('a')), null, 'a running task in another session is not followed');
        assert.equal(agentTask(tasks)?.id, 'a', 'the agent stays with this session\'s own task');
    });
});

describe('session-qualified links across workspaces', () => {
    const COORD = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
    const CHILD = '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e';
    const MISSING = '3c4d5e6f-7a8b-4c9d-8e0f-2a3b4c5d6e7f';
    const LINKED = '4d5e6f7a-8b9c-4d0e-8f1a-3b4c5d6e7f8a';
    const SYMLINKED = '5e6f7a8b-9c0d-4e1f-8a2b-4c5d6e7f8a9b';
    const DIR = '.copilot-tracking/rpi-sessions/2026-11-09';
    const PROJECT = `${DIR}/project-x/project-x-state.json`;
    const LOCAL_KID = `${DIR}/project-x/local-kid-state.json`;
    const API = `${DIR}/api/api-state.json`;
    const LEAF = `${DIR}/api/api-leaf-state.json`;
    const TESTS = `${DIR}/tests/tests-state.json`;
    const UI = `${DIR}/ui/ui-state.json`;
    const GONE = `${DIR}/gone/gone-state.json`;
    const UNTRACKED = `${DIR}/untracked/untracked-state.json`;
    let scratch;
    let stateRoot;
    let coordRoot;
    let childRoot;
    let coord;
    let child;
    const resolveSession = (sessionId) => resolveSessionWorkspace(sessionId, { root: stateRoot });

    /** Writes a JSON file under a workspace root, creating its folders. */
    async function writeJson(root, relative, value) {
        await fs.mkdir(path.dirname(path.join(root, relative)), { recursive: true });
        await fs.writeFile(path.join(root, relative), JSON.stringify(value));
    }

    /** A session folder in the session-state root that names `root` as its workspace. */
    async function session(id, root) {
        await fs.mkdir(path.join(stateRoot, id), { recursive: true });
        await fs.writeFile(path.join(stateRoot, id, 'workspace.yaml'), `cwd: ${root}\n`);
    }

    before(async () => {
        scratch = await scratchFolder('linked-tree');
        stateRoot = path.join(scratch, 'session-state');
        coordRoot = path.join(scratch, 'coordinator');
        childRoot = path.join(scratch, 'child');
        await fs.mkdir(stateRoot);
        await fs.mkdir(path.join(coordRoot, '.copilot-tracking'), { recursive: true });
        await fs.mkdir(path.join(childRoot, '.copilot-tracking'), { recursive: true });
        await fs.mkdir(path.join(scratch, 'no-tracking'));
        await session(COORD, coordRoot);
        await session(CHILD, childRoot);
        await session(LINKED, path.join(scratch, 'no-tracking'));
        await writeJson(coordRoot, PROJECT, {
            task_id: 'project-x',
            task_slug: 'project-x',
            session_name: 'Project X',
            parent_task: null,
            child_tasks: [
                { task_id: 'api', task_slug: 'api', state_path: API, session_id: CHILD },
                { task_id: 'tests', task_slug: 'tests', state_path: TESTS, session_id: CHILD },
                { task_id: 'ui', task_slug: 'ui', state_path: UI, session_id: MISSING },
                { task_id: 'bad', task_slug: 'bad', state_path: API, session_id: 'not-a-session' },
                { task_id: 'escape', task_slug: 'escape', state_path: '../escape-state.json', session_id: CHILD },
                { task_id: 'inner', task_slug: 'inner', state_path: 'src/inner-state.json', session_id: CHILD },
                { task_id: 'untracked', task_slug: 'untracked', state_path: UNTRACKED, session_id: LINKED },
                { task_id: 'gone', task_slug: 'gone', state_path: GONE, session_id: CHILD },
                { task_id: 'local-kid', task_slug: 'local-kid', state_path: LOCAL_KID, session_id: COORD },
            ],
            status: 'active',
            session_status: 'running',
        });
        await writeJson(coordRoot, LOCAL_KID, { task_id: 'local-kid', task_slug: 'local-kid', parent_task: { task_id: 'project-x', state_path: PROJECT }, child_tasks: [], status: 'active', session_status: 'stopped' });
        await writeJson(childRoot, API, {
            task_id: 'api',
            task_slug: 'api',
            session_name: 'API session',
            parent_task: { task_id: 'project-x', task_slug: 'project-x', state_path: PROJECT, session_id: COORD },
            child_tasks: [{ task_id: 'api-leaf', task_slug: 'api-leaf', state_path: LEAF }],
            active_phase: 'Plan',
            status: 'active',
            session_status: 'running',
        });
        await writeJson(childRoot, LEAF, { task_id: 'api-leaf', parent_task: { task_id: 'api', state_path: API }, status: 'active', session_status: 'running' });
        await writeJson(childRoot, TESTS, { task_id: 'tests', parent_task: { task_id: 'project-x', state_path: PROJECT, session_id: COORD }, active_phase: 'Research', status: 'completed', session_status: 'stopped' });
        await fs.mkdir(path.join(childRoot, 'src'), { recursive: true });
        await writeJson(childRoot, 'src/inner-state.json', { task_id: 'inner' });
        await writeJson(scratch, 'escape-state.json', { task_id: 'escape' });
        coord = await resolveWorkspace([coordRoot]);
        child = await resolveWorkspace([childRoot]);
    });
    after(() => fs.rm(scratch, { recursive: true, force: true }));

    it('reads a child in another Copilot session from that session\'s workspace, and never reads that session\'s other tasks', async () => {
        const tree = await sessionTreeOf(coord, await loadState(coord, PROJECT), undefined, { resolveSession });
        assert.deepEqual(tree.tasks.map((task) => [task.id, task.depth, task.shown, task.sessionId, task.sessionName, task.phase, task.status]), [
            ['project-x', 0, true, null, null, null, 'running'],
            ['api', 1, false, CHILD, 'API session', 'plan', 'running'],
            ['tests', 1, false, CHILD, CHILD.slice(0, 8), 'research', 'completed'],
            ['local-kid', 1, false, null, null, null, 'stopped'],
        ]);
        assert.equal(tree.tasks[1].root, child.root, 'the child task is keyed to its own workspace');
        assert.ok(!tree.tasks.some((task) => task.id === 'api-leaf'), 'the child session\'s own children stay in that session');
        assert.equal(tree.tasks[1].parent, PROJECT);
    });

    it('refuses an invalid session ID, a state path that leaves the linked tracking folder, a missing session or file, and a session with no tracking folder', async () => {
        const tree = await sessionTreeOf(coord, await loadState(coord, PROJECT), undefined, { resolveSession });
        assert.deepEqual(tree.warnings, [
            `project-x lists child ui in Copilot session ${MISSING} at ${UI}, which could not be read: No Copilot session ${MISSING} was found in ${path.join(stateRoot)}.`,
            `project-x lists child bad in Copilot session not-a-session at ${API}, which could not be read: session must be a Copilot session ID (a UUID), as in the name of its folder under session-state.`,
            `project-x lists child escape in Copilot session ${CHILD} at ../escape-state.json, which could not be read: ../escape-state.json is outside .copilot-tracking.`,
            `project-x lists child inner in Copilot session ${CHILD} at src/inner-state.json, which could not be read: src/inner-state.json is outside .copilot-tracking.`,
            `project-x lists child untracked in Copilot session ${LINKED} at ${UNTRACKED}, which could not be read: Copilot session ${LINKED} has no real .copilot-tracking folder in ${path.join(scratch, 'no-tracking', '.copilot-tracking')}.`,
            `project-x lists child gone in Copilot session ${CHILD} at ${GONE}, which could not be read: ${GONE} could not be read.`,
        ]);
        assert.ok(!tree.tasks.some((task) => ['ui', 'bad', 'escape', 'inner', 'untracked', 'gone'].includes(task.id)), 'no refused link adds a task');
    });

    it('shows a parent in another session as context for the child, and reads the child\'s session name', async () => {
        const tree = await sessionTreeOf(child, await loadState(child, API), undefined, { resolveSession });
        assert.deepEqual(tree.tasks.map((task) => [task.id, task.depth, task.shown]), [['api', 0, true], ['api-leaf', 1, false]]);
        assert.deepEqual([tree.tasks[0].continues.id, tree.tasks[0].continues.sessionId, tree.tasks[0].continues.sessionName, tree.tasks[0].continues.root], ['project-x', COORD, 'Project X', coord.root]);
        assert.deepEqual(tree.warnings, []);
    });

    it('treats a link that names this workspace\'s own session and task as local', async () => {
        const tree = await sessionTreeOf(coord, await loadState(coord, PROJECT), undefined, { resolveSession });
        const kid = tree.tasks.find((task) => task.id === 'local-kid');
        assert.deepEqual([kid.depth, kid.sessionId, kid.parent], [1, null, PROJECT]);
    });

    it('refuses a tracking folder that is a symbolic link, naming the session and the state path', async (t) => {
        const linkedRepo = path.join(scratch, 'linked-repo');
        const real = path.join(scratch, 'real-tracking');
        await fs.mkdir(linkedRepo);
        await fs.mkdir(real);
        if (!(await symlinkOrSkip(t, real, path.join(linkedRepo, '.copilot-tracking'), 'dir'))) return;
        await session(SYMLINKED, linkedRepo);
        const owner = path.join(scratch, 'symlink-owner');
        await fs.mkdir(path.join(owner, '.copilot-tracking'), { recursive: true });
        await writeJson(owner, PROJECT, { task_id: 'project-x', child_tasks: [{ task_id: 'linked-kid', state_path: `${DIR}/linked-kid/linked-kid-state.json`, session_id: SYMLINKED }] });
        const ownerWorkspace = await resolveWorkspace([owner]);
        const tree = await sessionTreeOf(ownerWorkspace, await loadState(ownerWorkspace, PROJECT), undefined, { resolveSession });
        assert.deepEqual(tree.tasks.map((task) => task.id), ['project-x']);
        assert.deepEqual(tree.warnings, [`project-x lists child linked-kid in Copilot session ${SYMLINKED} at ${DIR}/linked-kid/linked-kid-state.json, which could not be read: Copilot session ${SYMLINKED} has no real .copilot-tracking folder in ${path.join(linkedRepo, '.copilot-tracking')}.`]);
    });
});
