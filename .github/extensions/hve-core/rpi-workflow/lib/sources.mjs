// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';
import { buildScenario, SCENARIO_ID, STAGES } from './scenario.mjs';
import { agentTask, nextFollowTarget } from './source/tree.mjs';
import { createFollower, listSessions, loadState, resolveState, resolveTask, resolveWorkspace, scanStates, sessionOf, sessionTreeOf } from './source/workspace.mjs';
import { lineageStatusOf } from './source/assemble.mjs';

export const DEFAULT_STAGE = 'implement';
const TASK_REF_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;
const STATE_PATH_MAX = 400;

/**
 * Validates canvas open input: `state` opens the task whose state file it names, `task`
 * opens an RPI task by ID or `current`, and `scenario` and `stage` open the sample.
 * Returns the input, or an empty object when none was given.
 *
 * @param {unknown} input
 * @param {(code: string, message: string) => Error} makeError
 * @returns {{ task?: string, state?: string, scenario?: string, stage?: string }}
 */
export function validateOpenInput(input, makeError) {
    if (input === undefined || input === null) {
        return {};
    }
    if (typeof input !== 'object' || Array.isArray(input)) {
        throw makeError('invalid_input', 'Canvas input must be an object.');
    }
    const value = /** @type {Record<string, unknown>} */ (input);
    for (const key of Object.keys(value)) {
        if (key !== 'scenario' && key !== 'stage' && key !== 'task' && key !== 'state') {
            throw makeError('invalid_input', `Unknown input property: ${key}`);
        }
    }
    if (value.scenario !== undefined && value.scenario !== SCENARIO_ID) {
        throw makeError('invalid_input', `scenario must be ${SCENARIO_ID}; it is the only sample available.`);
    }
    if (value.stage !== undefined && !STAGES.includes(/** @type {any} */ (value.stage))) {
        throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
    }
    if (value.task !== undefined && value.state !== undefined) {
        throw makeError('invalid_input', 'Give either task or state, not both.');
    }
    if (value.state !== undefined && !validStatePath(value.state)) {
        throw makeError('invalid_input', 'state must be the workspace-relative path of a state file, such as .copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json.');
    }
    if (value.task !== undefined && (typeof value.task !== 'string' || (value.task !== 'current' && !TASK_REF_RE.test(value.task)) || value.task === 'sample')) {
        throw makeError('invalid_input', 'task must be "current" or a task ID; omit it to open the sample.');
    }
    if ((value.task !== undefined || value.state !== undefined) && (value.stage !== undefined || value.scenario !== undefined)) {
        throw makeError('invalid_input', 'task and state open an RPI task from the workspace; stage and scenario apply only to the sample.');
    }
    return /** @type {any} */ (value);
}

/**
 * What a canvas open shows. An instance already open here keeps what it shows when the open
 * has no input, and shows the input otherwise.
 *
 * The host reopens an instance this process has not opened yet by repeating an input it was
 * opened with: the latest open's after an extension reload, the first open's after a session
 * restart. Neither tells a reopen apart, and both arrive before the agent can act, so any open
 * of an instance that is not open here, and that this conversation remembers, restores what
 * it showed last: the task, or `{ task: 'sample' }` for the sample as it was.
 *
 * @param {Record<string, unknown>} requested validated open input
 * @param {{ open: boolean, remembered: any }} instance whether the instance is open here, and what it showed last in this conversation
 * @returns {{ keep: true } | { keep: false, restore: { state: string, paused: boolean } | { task: 'sample' } | null }}
 */
export function openPlan(requested, instance) {
    if (instance.open) return Object.keys(requested).length === 0 ? { keep: true } : { keep: false, restore: null };
    const remembered = instance.remembered;
    if (remembered?.kind === 'rpi' && validStatePath(remembered.state)) {
        return { keep: false, restore: { state: remembered.state.trim(), paused: remembered.paused === true } };
    }
    return { keep: false, restore: remembered?.kind === 'sample' ? { task: 'sample' } : null };
}

/** A non-empty state path without control characters, within the length cap. */
function validStatePath(value) {
    return typeof value === 'string' && value.trim() !== '' && value.length <= STATE_PATH_MAX && !/[\u0000-\u001f]/.test(value) && /-state\.json$/.test(value.trim());
}

/** Why a canvas shows no session: it opened without one, or the session it showed is gone. */
export const NOT_CONNECTED_REASONS = Object.freeze(['no-input', 'missing-session']);

/**
 * The prepared source of a canvas that shows no session, until the agent connects it with
 * `show_task`. Its session ID is empty, so nothing reads a session document for it.
 *
 * @param {'no-input' | 'missing-session'} reason
 * @param {string | null} [detail] the remembered state path that could not be read
 */
export function notConnected(reason, detail = null) {
    return { sessionId: '', source: { kind: 'none', reason, detail: typeof detail === 'string' ? detail : null }, session: null, note: '' };
}

/**
 * Decides what a canvas instance shows, the bundled sample at a stage or an RPI task read
 * from the workspace, and moves an instance between them. A task's follower polls only
 * while the instance's server has a page connected. While following, the canvas moves from
 * a task that is no longer running to the session's running task, wherever it sits;
 * showing a task that is not running, by hand or by `show_task`, pauses following until it
 * resumes.
 *
 * @param {{
 *   store: ReturnType<typeof import('./store.mjs').createStore>,
 *   log?: (message: string) => void,
 *   now?: () => string,
 *   intervalMs?: number,
 * }} deps
 */
export function createSourceController(deps) {
    const { store } = deps;
    const log = deps.log ?? (() => {});
    const now = deps.now ?? (() => new Date().toISOString());

    async function prepareSample(stage, replace) {
        const existing = await store.load(SCENARIO_ID);
        if (!existing || replace || (stage && existing.scenario?.stage !== stage)) {
            const wanted = stage ?? existing?.scenario?.stage ?? DEFAULT_STAGE;
            try {
                const session = await store.create(buildScenario(wanted), { replace: replace === true });
                return { sessionId: SCENARIO_ID, source: { kind: 'sample', stage: wanted }, session, note: '' };
            } catch (error) {
                if (error instanceof ModelError && error.code === 'scenario_exists' && existing) {
                    return { sessionId: SCENARIO_ID, source: { kind: 'sample', stage: existing.scenario?.stage }, session: existing, note: ' (kept your changes; load_scenario with replace: true starts over)' };
                }
                throw error;
            }
        }
        return { sessionId: SCENARIO_ID, source: { kind: 'sample', stage: existing.scenario?.stage }, session: existing, note: '' };
    }

    /**
     * Reads a task by ID, `current`, or state path, and starts following its files.
     *
     * @param {{ task?: string, state?: string }} ref
     * @param {{ root: string, tracking: string } | null} workspace
     * @param {(string | null | undefined)[]} [candidates]
     * @param {{ paused?: boolean }} [follow]
     */
    async function prepareTask(ref, workspace, candidates, follow = {}) {
        if (ref.state === undefined && (typeof ref.task !== 'string' || (ref.task !== 'current' && !TASK_REF_RE.test(ref.task)))) {
            throw new ModelError('invalid_input', 'task must be "current" or a task ID such as trail-maps.');
        }
        if (ref.state !== undefined && !validStatePath(ref.state)) {
            throw new ModelError('invalid_input', 'state must be the workspace-relative path of a state file.');
        }
        const resolvedWorkspace = workspace ?? await resolveWorkspace(candidates ?? []);
        const resolved = ref.state !== undefined ? await resolveState(resolvedWorkspace, ref.state.trim()) : await resolveTask(resolvedWorkspace, /** @type {string} */ (ref.task));
        const source = {
            kind: 'rpi',
            workspace: resolvedWorkspace,
            taskId: resolved.taskId,
            statePath: resolved.statePath,
            sessionKey: sessionOf(resolved.statePath)?.key ?? null,
            follower: /** @type {any} */ (null),
            follow: { paused: follow.paused === true },
            tasks: /** @type {any[]} */ ([]),
            record: /** @type {any} */ (null),
        };
        source.follower = createFollower({
            store,
            workspace: resolvedWorkspace,
            statePath: resolved.statePath,
            intervalMs: deps.intervalMs,
            now,
            log,
            onImport: async (loaded) => {
                source.tasks = loaded.tree.tasks;
                if (source.record) await followRunning(source.record);
            },
        });
        const { session } = await source.follower.importNow();
        return {
            sessionId: session.id,
            source,
            session,
            note: resolved.warnings.length ? ` (${resolved.warnings.join(' ')})` : '',
        };
    }

    /**
     * Moves a following instance to the session's running task once the task it shows is no
     * longer running. Concurrent calls share one move.
     *
     * @param {{ sessionId: string, source?: any, server?: any, moving?: Promise<void> | null }} record
     */
    function followRunning(record) {
        if (record.moving) return record.moving;
        const run = async () => {
            for (let step = 0; step < 20; step += 1) {
                const source = record.source;
                if (source?.kind !== 'rpi' || source.follow.paused) return;
                const target = nextFollowTarget(source.tasks, source.statePath);
                if (!target) return;
                const prepared = await prepareTask({ state: target.statePath }, source.workspace);
                if (record.source !== source) return;
                attach(record, prepared, { moved: { from: source.taskId, to: prepared.source.taskId, title: target.title } });
            }
        };
        // Cleared only after the assignment below, even when the run finishes synchronously.
        const moving = run()
            .catch((error) => log(`Following the running loop failed: ${error instanceof Error ? error.message : 'error'}`))
            .finally(() => {
                if (record.moving === moving) record.moving = null;
            });
        record.moving = moving;
        return moving;
    }

    /**
     * Points an instance at a prepared source, stops the previous follower, and lets the
     * server rebind its watchers and tell the page to reload.
     *
     * @param {{ sessionId: string, source?: any, server?: any }} record
     * @param {{ sessionId: string, source: any }} prepared
     * @param {{ moved?: { from: string, to: string, title: string } }} [detail]
     */
    function attach(record, prepared, detail = {}) {
        const previous = record.source;
        record.sessionId = prepared.sessionId;
        record.source = prepared.source;
        if (prepared.source.kind === 'rpi') prepared.source.record = record;
        if (previous?.follower && previous.follower !== prepared.source.follower) previous.follower.stop();
        record.server?.rebind?.(detail);
        remember(record);
    }

    /** Remembers what an instance shows in its conversation, so it returns there when the host reopens it. */
    function remember(record) {
        if (typeof record.instanceId !== 'string' || typeof store.rememberInstance !== 'function') return;
        const source = record.source;
        // A canvas that shows no session keeps its last place, so a session that returns can still reopen.
        if (source?.kind === 'none') return;
        const shown = source?.kind === 'rpi' ? { kind: 'rpi', state: source.statePath, paused: source.follow?.paused === true } : { kind: 'sample' };
        record.remembering = store.rememberInstance(record.instanceId, shown, { hostSessionId: record.hostSessionId }).catch((error) => log(`Could not remember what canvas ${record.instanceId} shows: ${error instanceof Error ? error.message : 'error'}`));
    }

    /** The tree of the task an instance shows. */
    async function treeOf(record) {
        const current = await store.load(record.sessionId);
        return current?.followUps?.tree?.tasks ?? [];
    }

    async function switchTo(record, ref, paused) {
        const prepared = await prepareTask(ref, record.source.workspace, undefined, { paused });
        attach(record, prepared);
        void followRunning(record);
        return prepared;
    }

    function requireRpi(record) {
        if (record.source?.kind === 'none') {
            throw new ModelError('not_connected', 'This canvas is not connected to an RPI session. Ask the agent to connect it.');
        }
        if (record.source?.kind !== 'rpi') {
            throw new ModelError('invalid_state', 'This canvas shows the sample session, which has no other tasks.');
        }
    }

    return {
        /**
         * Prepares a source without attaching it: `{ state }` or `{ task }` reads a task from
         * the workspace, `task: "sample"`, a stage, or a scenario prepares the sample, and a
         * request with none of these is not connected.
         *
         * @param {{ task?: string, state?: string, stage?: string, scenario?: string, replace?: boolean, paused?: boolean }} request `paused` keeps following paused for `state`
         * @param {{ workspace?: { root: string, tracking: string } | null, candidates?: (string | null | undefined)[] }} [context]
         */
        prepare(request, context = {}) {
            if (request.state !== undefined) return prepareTask({ state: request.state }, context.workspace ?? null, context.candidates, { paused: request.paused === true });
            if (request.task !== undefined && request.task !== 'sample') return prepareTask({ task: request.task }, context.workspace ?? null, context.candidates);
            // Only a request that names the sample, or one of its stages, shows the sample.
            if (request.task === 'sample' || request.stage !== undefined || request.scenario !== undefined) return prepareSample(request.stage, request.replace);
            return Promise.resolve(notConnected('no-input'));
        },

        /**
         * Attaches a prepared source and, when it follows a task, moves on to the running
         * loop when that is due.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {{ sessionId: string, source: any }} prepared
         */
        attach(record, prepared) {
            attach(record, prepared);
            if (prepared.source.kind === 'rpi') void followRunning(record);
        },

        /**
         * Shows what the agent asks for with `show_task` or `load_scenario`. A task it names that
         * is not running stays shown, with following paused as when the user chooses it on the
         * page; `task: "current"` keeps following, because it asks for where the work is.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {{ task?: string, state?: string, stage?: string, replace?: boolean }} request
         * @param {{ workspace?: any, candidates?: (string | null | undefined)[] }} [context]
         */
        async show(record, request, context = {}) {
            const prepared = await this.prepare(request, context);
            if (prepared.source.kind === 'rpi' && request.task !== 'current') {
                const shown = prepared.source.tasks.find((task) => task.statePath === prepared.source.statePath);
                if (shown?.status !== 'running') prepared.source.follow.paused = true;
            }
            this.attach(record, prepared);
            return prepared;
        },

        /** Stops an instance's follower. */
        detach(record) {
            record.source?.follower?.stop();
        },

        /** Resolves once a pending automatic move and the memory write it causes finish; for tests and callers that need a settled source. */
        async settled(record) {
            await record.moving;
            await record.remembering;
        },

        /**
         * Shows another task of the instance's session, or the parent a task continues
         * from another session. Showing a task that is not running pauses following, and
         * `paused` keeps it paused even for a running task.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {{ taskId?: string, statePath?: string } | string} ref
         * @param {{ paused?: boolean }} [options]
         */
        async switchToTask(record, ref, options = {}) {
            requireRpi(record);
            const want = typeof ref === 'string' ? { taskId: ref } : ref ?? {};
            const tasks = await treeOf(record);
            const candidates = [...tasks, ...tasks.map((task) => task.continues).filter(Boolean)];
            const match = candidates.find((task) => (want.statePath ? task.statePath === want.statePath : task.id === want.taskId));
            if (!match?.statePath) {
                throw new ModelError('invalid_input', `${String(want.statePath ?? want.taskId).slice(0, 120)} is not in this session.`);
            }
            return switchTo(record, { state: match.statePath }, options.paused === true || match.status !== 'running');
        },

        /**
         * Shows another session: its running task, or its most recently changed task.
         * `paused` keeps following paused even when the session has a running task.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {string} key `<date>/<session>`
         * @param {{ paused?: boolean }} [options]
         */
        async switchToSession(record, key, options = {}) {
            requireRpi(record);
            const { states } = await scanStates(record.source.workspace);
            const entries = states.filter((entry) => entry.session === key);
            if (!entries.length) throw new ModelError('not_found', `No session ${String(key).slice(0, 80)} was found.`);
            let pick = null;
            for (const entry of entries) {
                const loaded = await loadState(record.source.workspace, entry.path).catch(() => null);
                if (!loaded?.state.taskId) continue;
                pick ??= loaded;
                if (lineageStatusOf(loaded.state) === 'running') {
                    pick = loaded;
                    break;
                }
            }
            if (!pick) throw new ModelError('not_found', `No readable task was found in session ${String(key).slice(0, 80)}.`);
            return switchTo(record, { state: pick.path }, options.paused === true || lineageStatusOf(pick.state) !== 'running');
        },

        /**
         * Pauses following: the canvas stays on the task it shows until following resumes.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         */
        async pauseFollowing(record) {
            requireRpi(record);
            if (!record.source.follow.paused) {
                record.source.follow.paused = true;
                record.server?.rebind?.({});
                remember(record);
            }
            return { sessionId: record.sessionId, source: record.source };
        },

        /**
         * Resumes following from wherever the instance is: shows where the agent works, the
         * session's running task, or its latest loop when none runs.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         */
        async resumeFollowing(record) {
            requireRpi(record);
            const { workspace, statePath } = record.source;
            const self = await loadState(workspace, statePath).catch(() => null);
            const target = self ? agentTask((await sessionTreeOf(workspace, self)).tasks) : null;
            if (target && target.statePath !== statePath) return switchTo(record, { state: target.statePath }, false);
            record.source.follow.paused = false;
            record.server?.rebind?.({});
            remember(record);
            await followRunning(record);
            return { sessionId: record.sessionId, source: record.source };
        },

        /** Every session in the instance's workspace. */
        async sessions(record) {
            requireRpi(record);
            return listSessions(record.source.workspace);
        },
    };
}

/**
 * What get_state reports about where an instance's content comes from.
 *
 * @param {{ source?: any, server?: any }} record
 * @param {any} session
 */
export function sourceSummary(record, session) {
    if (record.source?.kind === 'rpi') {
        const tree = session.followUps?.tree ?? { key: null, name: null, tasks: [] };
        return {
            kind: 'rpi',
            taskId: record.source.taskId,
            statePath: record.source.statePath,
            artifacts: session.source?.artifacts ?? {},
            importedAt: session.source?.importedAt ?? null,
            warnings: session.source?.warnings ?? [],
            session: {
                key: tree.key,
                name: tree.name,
                tasks: tree.tasks.map((task) => ({ taskId: task.id, status: task.status, depth: task.depth, shown: task.shown, statePath: task.statePath })),
            },
            following: record.source.follow?.paused ? 'paused' : 'enabled',
            polling: Boolean(record.server?.streamClients > 0),
        };
    }
    if (record.source?.kind === 'none') return { kind: 'none', reason: record.source.reason, detail: record.source.detail ?? null };
    return { kind: 'sample', stage: session.scenario?.stage ?? null };
}
