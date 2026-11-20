// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { buildScenario } from '../lib/scenario.mjs';
import { boardLanes, LANES, laneOf, taskMarkers } from '../ui/board.mjs';

const NOW = '2026-10-27T12:00:00.000Z';
/** The sample at Implement: P02-T02 in progress, P03-T01 paused on D6, P04-T02 blocked by B1. */
const implementing = () => buildScenario('implement', Date.parse(NOW));
const taskOf = (session, id) => session.plan.phases.flatMap((phase) => phase.tasks).find((task) => task.id === id);
const lane = (session, id) => boardLanes(session).find((entry) => entry.id === id);
const ids = (tasks) => tasks.map((task) => task.id);

/** The sample reshaped the way an RPI import arrives: only done, in progress, and not started, with no task decision links. */
function rpiShaped() {
    const session = implementing();
    for (const task of session.plan.phases.flatMap((phase) => phase.tasks)) {
        if (task.status === 'paused' || task.status === 'blocked') task.status = 'todo';
        delete task.decisionId;
    }
    session.implementation.blockers = [{ id: 'B1', taskId: 'P04-T01', text: 'P04-T01 waits on the design review.', owner: '', clear: '' }];
    return session;
}

describe('board lanes', () => {
    it('hold Backlog, In progress, and Done in that order, each with its tasks in plan order', () => {
        const lanes = boardLanes(implementing());
        assert.deepEqual(lanes.map((entry) => [entry.id, entry.label]), [['backlog', 'Backlog'], ['active', 'In progress'], ['done', 'Done']]);
        assert.deepEqual(lanes.map((entry) => ids(entry.tasks)), [
            ['P02-T03', 'P03-T02', 'P04-T01'],
            ['P02-T02', 'P03-T01', 'P04-T02'],
            ['P01-T01', 'P01-T02', 'P02-T01'],
        ]);
        assert.deepEqual(LANES.map((entry) => entry.status), ['todo', 'in-progress', 'done']);
    });

    it('put paused and blocked tasks in In progress and leave unknown statuses out of every lane', () => {
        assert.deepEqual(['todo', 'in-progress', 'paused', 'blocked', 'done', 'skipped'].map((status) => laneOf({ status })), ['backlog', 'active', 'active', 'active', 'done', null]);
    });
});

describe('the card each lane shows', () => {
    it('is the next ready task, the agent\'s task, and the task finished last', () => {
        const session = implementing();
        assert.equal(lane(session, 'backlog').card.id, 'P03-T02', 'P02-T03 waits on P02-T02, so P03-T02 is next');
        assert.equal(lane(session, 'active').card.id, 'P02-T02', 'the agent works on P02-T02');
        assert.equal(lane(session, 'done').card.id, 'P02-T01', 'CH-003 is the newest change');
    });

    it('counts the paused and blocked cards a lane hides', () => {
        const session = implementing();
        assert.deepEqual(lane(session, 'active').hidden, { paused: 1, blocked: 1 });
        assert.deepEqual(lane(session, 'backlog').hidden, { paused: 0, blocked: 0 });
    });

    it('falls back to paused, then blocked, when the agent has no task', () => {
        const session = implementing();
        session.implementation.current = null;
        assert.equal(lane(session, 'active').card.id, 'P03-T01');
        taskOf(session, 'P03-T01').status = 'in-progress';
        delete taskOf(session, 'P03-T01').decisionId;
        session.decisions = session.decisions.filter((decision) => decision.id !== 'D6');
        assert.equal(lane(session, 'active').card.id, 'P04-T02');
    });

    it('shows the task with the newest timed change in Done, else the last done task in plan order', () => {
        const session = implementing();
        session.implementation.changes.find((change) => change.taskId === 'P01-T01').at = '2026-10-27T11:59:00.000Z';
        assert.equal(lane(session, 'done').card.id, 'P01-T01');
        for (const change of session.implementation.changes) change.at = null;
        assert.equal(lane(session, 'done').card.id, 'P02-T01');
    });

    it('shows the first task when no Backlog task is ready, and nothing in an empty lane', () => {
        const session = implementing();
        for (const task of lane(session, 'backlog').tasks) task.dependencies = ['P02-T02'];
        assert.equal(lane(session, 'backlog').card.id, 'P02-T03', 'every Backlog task waits on P02-T02');
        for (const task of session.plan.phases.flatMap((phase) => phase.tasks)) task.status = 'todo';
        assert.equal(lane(session, 'done').card, null);
    });
});

describe('task markers', () => {
    it('mark the sample\'s paused and blocked tasks with the decision and blocker behind them', () => {
        const session = implementing();
        const paused = taskMarkers(session, taskOf(session, 'P03-T01'));
        assert.deepEqual([paused.paused, paused.blocked, paused.decision?.id], [true, false, 'D6']);
        const blocked = taskMarkers(session, taskOf(session, 'P04-T02'));
        assert.deepEqual([blocked.paused, blocked.blocked, blocked.blocker?.id], [false, true, 'B1']);
        assert.deepEqual(taskMarkers(session, taskOf(session, 'P02-T02')), { paused: false, blocked: false, decision: null, blocker: null });
    });

    it('never mark a done task', () => {
        const session = implementing();
        session.implementation.blockers.push({ id: 'B2', taskId: 'P01-T01', text: 'P01-T01', owner: '', clear: '' });
        assert.deepEqual(taskMarkers(session, taskOf(session, 'P01-T01')), { paused: false, blocked: false, decision: null, blocker: null });
    });

    it('come from blockers and decisions that name a task in a live RPI session', () => {
        const session = rpiShaped();
        const blocked = taskMarkers(session, taskOf(session, 'P04-T01'));
        assert.deepEqual([blocked.blocked, laneOf(taskOf(session, 'P04-T01'))], [true, 'backlog'], 'a blocked task not started stays in Backlog');
        const paused = taskMarkers(session, taskOf(session, 'P03-T01'));
        assert.deepEqual([paused.paused, paused.decision?.id], [true, 'D6'], 'D6 needs your input and its impact names P03-T01');
        session.decisions.find((decision) => decision.id === 'D6').impact = 'Changes P03-T010 and P03';
        assert.equal(taskMarkers(session, taskOf(session, 'P03-T01')).paused, false, 'only the whole task ID counts');
        session.decisions.find((decision) => decision.id === 'D6').impact = 'Pauses P02-T02 until you decide.';
        assert.equal(taskMarkers(session, taskOf(session, 'P02-T02')).paused, true, 'an in-progress task is paused too');
        assert.equal(lane(session, 'active').card.id, 'P02-T02', 'the agent\'s task still leads In progress');
    });

    it('ignore a decision once it no longer needs your input', () => {
        const session = rpiShaped();
        session.decisions.find((decision) => decision.id === 'D6').status = 'decided';
        assert.equal(taskMarkers(session, taskOf(session, 'P03-T01')).paused, false);
    });
});
