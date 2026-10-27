// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';
import { buildScenario, SCENARIO_ID, STAGES } from './scenario.mjs';
import { nextFollowTarget } from './source/tree.mjs';
import { createFollower, listSessions, loadState, resolveState, resolveTask, resolveWorkspace, scanStates, sessionOf } from './source/workspace.mjs';
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
 * What a canvas open shows. An open with input shows that input. An open without input keeps
 * an instance that is already open, and otherwise restores what the instance showed last:
 * after the host restarts the extension, it reopens canvases without their input.
 *
 * @param {Record<string, unknown>} requested validated open input
 * @param {{ open: boolean, remembered: any }} instance whether the instance is open here, and what it showed last
 * @returns {{ keep: true } | { keep: false, restore: { state: string, paused: boolean } | null }}
 */
export function openPlan(requested, instance) {
    if (Object.keys(requested).length > 0) return { keep: false, restore: null };
    if (instance.open) return { keep: true };
    const remembered = instance.remembered;
    const restore = remembered?.kind === 'rpi' && validStatePath(remembered.state) ? { state: remembered.state.trim(), paused: remembered.paused === true } : null;
    return { keep: false, restore };
}

/** A non-empty state path without control characters, within the length cap. */
function validStatePath(value) {
    return typeof value === 'string' && value.trim() !== '' && value.length <= STATE_PATH_MAX && !/[\u0000-\u001f]/.test(value) && /-state\.json$/.test(value.trim());
}

/**
 * Decides what a canvas instance shows, the bundled sample at a stage or an RPI task read
 * from the workspace, and moves an instance between them. A task's follower polls only
 * while the instance's server has a page connected. While following, the canvas moves to
 * the one running child of a task that is no longer running; showing a task that is not
 * running, by hand or by `show_task`, pauses following until it resumes.
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
     * Moves a following instance to the one running child of its task once that task is
     * no longer running, repeating down the tree. Concurrent calls share one move.
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

    /** Remembers what an instance shows, so it reopens there after the host restarts the extension. */
    function remember(record) {
        if (typeof record.instanceId !== 'string' || typeof store.rememberInstance !== 'function') return;
        const source = record.source;
        const shown = source?.kind === 'rpi' ? { kind: 'rpi', state: source.statePath, paused: source.follow?.paused === true } : { kind: 'sample' };
        store.rememberInstance(record.instanceId, shown).catch((error) => log(`Could not remember what canvas ${record.instanceId} shows: ${error instanceof Error ? error.message : 'error'}`));
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
        if (record.source?.kind !== 'rpi') {
            throw new ModelError('invalid_state', 'This canvas shows the sample session, which has no other tasks.');
        }
    }

    return {
        /**
         * Prepares a source without attaching it: `{ state }` or `{ task }` reads a task
         * from the workspace, anything else prepares the sample.
         *
         * @param {{ task?: string, state?: string, stage?: string, replace?: boolean, paused?: boolean }} request `paused` keeps following paused for `state`
         * @param {{ workspace?: { root: string, tracking: string } | null, candidates?: (string | null | undefined)[] }} [context]
         */
        prepare(request, context = {}) {
            if (request.state !== undefined) return prepareTask({ state: request.state }, context.workspace ?? null, context.candidates, { paused: request.paused === true });
            return request.task !== undefined && request.task !== 'sample'
                ? prepareTask({ task: request.task }, context.workspace ?? null, context.candidates)
                : prepareSample(request.stage, request.replace);
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

        /** Stops an instance's follower. */
        detach(record) {
            record.source?.follower?.stop();
        },

        /** Resolves once a pending automatic move finishes; for tests and callers that need a settled source. */
        settled(record) {
            return record.moving ?? Promise.resolve();
        },

        /**
         * Shows another task of the instance's session, or the parent a task continues
         * from another session. Showing a task that is not running pauses following.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {{ taskId?: string, statePath?: string } | string} ref
         */
        async switchToTask(record, ref) {
            requireRpi(record);
            const want = typeof ref === 'string' ? { taskId: ref } : ref ?? {};
            const tasks = await treeOf(record);
            const candidates = [...tasks, ...tasks.map((task) => task.continues).filter(Boolean)];
            const match = candidates.find((task) => (want.statePath ? task.statePath === want.statePath : task.id === want.taskId));
            if (!match?.statePath) {
                throw new ModelError('invalid_input', `${String(want.statePath ?? want.taskId).slice(0, 120)} is not in this session.`);
            }
            return switchTo(record, { state: match.statePath }, match.status !== 'running');
        },

        /**
         * Shows another session: its running task, or its most recently changed task.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {string} key `<date>/<session>`
         */
        async switchToSession(record, key) {
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
            return switchTo(record, { state: pick.path }, lineageStatusOf(pick.state) !== 'running');
        },

        /**
         * Resumes following: shows the session's most recently changed running task, or
         * keeps the shown task when none runs.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         */
        async resumeFollowing(record) {
            requireRpi(record);
            const { states } = await scanStates(record.source.workspace);
            for (const entry of states.filter((item) => item.session === record.source.sessionKey)) {
                const loaded = await loadState(record.source.workspace, entry.path).catch(() => null);
                if (loaded && lineageStatusOf(loaded.state) === 'running') {
                    if (loaded.path === record.source.statePath) break;
                    return switchTo(record, { state: loaded.path }, false);
                }
            }
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
    return { kind: 'sample', stage: session.scenario?.stage ?? null };
}
