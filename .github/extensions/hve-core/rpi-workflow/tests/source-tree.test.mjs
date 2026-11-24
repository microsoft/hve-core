// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { lineageStatusOf } from '../lib/source/assemble.mjs';
import { parseState } from '../lib/source/parse.mjs';
import { agentTask, buildTree, humanizeSlug, nextFollowTarget } from '../lib/source/tree.mjs';

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
