// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The Implement task board's rules, without DOM: the three lanes, the one card each lane
 * shows, and the paused and blocked markers. The board, Phases and tasks filters, and task
 * previews share them, so the sample and live RPI sessions read the same way.
 */

/**
 * The board's lanes, in order. `status` names the task status whose icon and tone stand for
 * the lane; `statuses` are the task statuses the lane holds.
 */
export const LANES = Object.freeze([
    Object.freeze({ id: 'backlog', label: 'Backlog', status: 'todo', statuses: Object.freeze(['todo']) }),
    Object.freeze({ id: 'active', label: 'In progress', status: 'in-progress', statuses: Object.freeze(['in-progress', 'paused', 'blocked']) }),
    Object.freeze({ id: 'done', label: 'Done', status: 'done', statuses: Object.freeze(['done']) }),
]);

/**
 * The lane a task belongs to, or null for a status no lane holds.
 *
 * @param {{ status?: string } | null | undefined} task
 * @returns {'backlog' | 'active' | 'done' | null}
 */
export function laneOf(task) {
    const lane = LANES.find((candidate) => candidate.statuses.includes(task?.status));
    return lane ? /** @type {'backlog' | 'active' | 'done'} */ (lane.id) : null;
}

/** True when `text` names the task ID as a whole word, such as "Unpauses P03-T01". */
function names(text, id) {
    if (typeof text !== 'string' || !text) return false;
    const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`(?:^|[^\\w-])${escaped}(?![\\w-])`).test(text);
}

const waiting = (decision) => decision?.status === 'needs-input';

/**
 * A task's paused and blocked markers. A task that is not done is paused when its status is
 * paused, its linked decision needs your input, or a decision that needs your input names it
 * in its impact. It is blocked when its status is blocked or a current blocker names it.
 * Live RPI plans set only done, in progress, and not started, so the impact and blocker
 * paths are what mark their tasks.
 *
 * @param {any} session
 * @param {any} task
 * @returns {{ paused: boolean, blocked: boolean, decision: any, blocker: any }} `decision` is the decision the task waits on and `blocker` the blocker that names it, when known
 */
export function taskMarkers(session, task) {
    if (!task || task.status === 'done') return { paused: false, blocked: false, decision: null, blocker: null };
    const decisions = session?.decisions ?? [];
    const linked = task.decisionId ? decisions.find((decision) => decision.id === task.decisionId) ?? null : null;
    const named = decisions.find((decision) => waiting(decision) && names(decision.impact, task.id)) ?? null;
    const decision = (waiting(linked) ? linked : null) ?? named ?? (task.status === 'paused' ? linked : null);
    const blocker = (session?.implementation?.blockers ?? []).find((item) => item.taskId === task.id) ?? null;
    return {
        paused: task.status === 'paused' || waiting(linked) || Boolean(named),
        blocked: task.status === 'blocked' || Boolean(blocker),
        decision,
        blocker,
    };
}

/** True when every task and phase the task depends on is done; an unknown ID does not hold it back. */
function dependenciesDone(phases, task) {
    return (task.dependencies ?? []).every((id) => {
        const phase = phases.find((candidate) => candidate.id === id);
        if (phase) return phase.tasks.every((item) => item.status === 'done');
        const found = phases.flatMap((candidate) => candidate.tasks).find((item) => item.id === id);
        return found ? found.status === 'done' : true;
    });
}

/** Milliseconds of the task's newest timed change, or -Infinity when none has a time. */
function newestChange(session, task) {
    let newest = -Infinity;
    for (const change of session?.implementation?.changes ?? []) {
        if (change.taskId !== task.id || !change.at) continue;
        const at = Date.parse(change.at);
        if (Number.isFinite(at) && at > newest) newest = at;
    }
    return newest;
}

/**
 * The one card a lane shows. Backlog: the first task whose dependencies are done, else the
 * first. In progress: the agent's task, else the first paused, else the first blocked, else
 * the first. Done: the task with the newest timed change, else the last in plan order.
 */
function laneCard(session, laneId, tasks) {
    if (!tasks.length) return null;
    const phases = session?.plan?.phases ?? [];
    if (laneId === 'backlog') return tasks.find((task) => dependenciesDone(phases, task)) ?? tasks[0];
    if (laneId === 'active') {
        const agent = session?.implementation?.current?.taskId ?? null;
        const marked = tasks.map((task) => ({ task, markers: taskMarkers(session, task) }));
        return tasks.find((task) => task.id === agent)
            ?? marked.find((entry) => entry.markers.paused)?.task
            ?? marked.find((entry) => entry.markers.blocked)?.task
            ?? tasks[0];
    }
    let best = null;
    let bestAt = -Infinity;
    for (const task of tasks) {
        const at = newestChange(session, task);
        if (at > bestAt) {
            best = task;
            bestAt = at;
        }
    }
    return best ?? tasks.at(-1);
}

/**
 * The board's lanes for a session, in order, each with its tasks in plan order, the one card
 * it shows, and how many of the cards it hides are paused or blocked.
 *
 * @param {any} session
 * @returns {{ id: 'backlog' | 'active' | 'done', label: string, status: string, tasks: any[], card: any, hidden: { paused: number, blocked: number } }[]}
 */
export function boardLanes(session) {
    const tasks = (session?.plan?.phases ?? []).flatMap((phase) => phase.tasks);
    return LANES.map((lane) => {
        const members = tasks.filter((task) => laneOf(task) === lane.id);
        const card = laneCard(session, lane.id, members);
        const hidden = { paused: 0, blocked: 0 };
        for (const task of members) {
            if (task === card) continue;
            const markers = taskMarkers(session, task);
            if (markers.paused) hidden.paused += 1;
            if (markers.blocked) hidden.blocked += 1;
        }
        return { id: /** @type {'backlog' | 'active' | 'done'} */ (lane.id), label: lane.label, status: lane.status, tasks: members, card, hidden };
    });
}
