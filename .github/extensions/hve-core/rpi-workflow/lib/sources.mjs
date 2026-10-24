// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';
import { buildScenario, SCENARIO_ID, STAGES } from './scenario.mjs';
import { createFollower, resolveTask, resolveWorkspace } from './source/workspace.mjs';

export const DEFAULT_STAGE = 'implement';
const TASK_REF_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;

/**
 * Validates canvas open input: `task` opens an RPI task, and `scenario` and `stage` open the
 * sample. Returns the input, or an empty object when none was given.
 *
 * @param {unknown} input
 * @param {(code: string, message: string) => Error} makeError
 * @returns {{ task?: string, scenario?: string, stage?: string }}
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
        if (key !== 'scenario' && key !== 'stage' && key !== 'task') {
            throw makeError('invalid_input', `Unknown input property: ${key}`);
        }
    }
    if (value.scenario !== undefined && value.scenario !== SCENARIO_ID) {
        throw makeError('invalid_input', `scenario must be ${SCENARIO_ID}; it is the only sample available.`);
    }
    if (value.stage !== undefined && !STAGES.includes(/** @type {any} */ (value.stage))) {
        throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
    }
    if (value.task !== undefined) {
        if (typeof value.task !== 'string' || (value.task !== 'current' && !TASK_REF_RE.test(value.task)) || value.task === 'sample') {
            throw makeError('invalid_input', 'task must be "current" or a task ID; omit it to open the sample.');
        }
        if (value.stage !== undefined || value.scenario !== undefined) {
            throw makeError('invalid_input', 'task opens an RPI task from the workspace; stage and scenario apply only to the sample.');
        }
    }
    return /** @type {any} */ (value);
}

/**
 * Decides what a canvas instance shows, the bundled sample at a stage or an RPI task read
 * from the workspace, and moves an instance between them. A task's follower polls only
 * while the instance's server has a page connected.
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

    async function prepareTask(ref, workspace, candidates) {
        if (typeof ref !== 'string' || (ref !== 'current' && !TASK_REF_RE.test(ref))) {
            throw new ModelError('invalid_input', 'task must be "current" or a task ID such as trail-maps.');
        }
        const resolvedWorkspace = workspace ?? await resolveWorkspace(candidates ?? []);
        const resolved = await resolveTask(resolvedWorkspace, ref);
        const follower = createFollower({ store, workspace: resolvedWorkspace, statePath: resolved.statePath, intervalMs: deps.intervalMs, now, log });
        const { session } = await follower.importNow();
        return {
            sessionId: session.id,
            source: { kind: 'rpi', workspace: resolvedWorkspace, taskId: resolved.taskId, statePath: resolved.statePath, follower },
            session,
            note: resolved.warnings.length ? ` (${resolved.warnings.join(' ')})` : '',
        };
    }

    return {
        /**
         * Prepares a source without attaching it: `{ task }` reads a task from the
         * workspace, anything else prepares the sample.
         *
         * @param {{ task?: string, stage?: string, replace?: boolean }} request
         * @param {{ workspace?: { root: string, tracking: string } | null, candidates?: (string | null | undefined)[] }} [context]
         */
        prepare(request, context = {}) {
            return request.task !== undefined && request.task !== 'sample'
                ? prepareTask(request.task, context.workspace ?? null, context.candidates)
                : prepareSample(request.stage, request.replace);
        },

        /**
         * Points an instance at a prepared source, stops the previous follower, and lets
         * the server rebind its watchers and tell the page to reload.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {{ sessionId: string, source: any }} prepared
         */
        attach(record, prepared) {
            const previous = record.source;
            record.sessionId = prepared.sessionId;
            record.source = prepared.source;
            if (previous?.follower && previous.follower !== prepared.source.follower) previous.follower.stop();
            record.server?.rebind?.();
        },

        /** Stops an instance's follower. */
        detach(record) {
            record.source?.follower?.stop();
        },

        /**
         * Switches an instance to another task in its current lineage.
         *
         * @param {{ sessionId: string, source?: any, server?: any }} record
         * @param {string} taskId
         */
        async switchToTask(record, taskId) {
            if (record.source?.kind !== 'rpi') {
                throw new ModelError('invalid_state', 'This canvas shows the sample session, which has no other tasks.');
            }
            const current = await store.load(record.sessionId);
            if (!current?.followUps?.lineage?.some((item) => item.id === taskId)) {
                throw new ModelError('invalid_input', `${String(taskId).slice(0, 80)} is not in this session's lineage.`);
            }
            const prepared = await prepareTask(taskId, record.source.workspace);
            this.attach(record, prepared);
            return prepared;
        },
    };
}

/**
 * What get_state reports about where an instance's content comes from.
 *
 * @param {{ source?: any }} record
 * @param {any} session
 */
export function sourceSummary(record, session) {
    if (record.source?.kind === 'rpi') {
        return {
            kind: 'rpi',
            taskId: record.source.taskId,
            statePath: record.source.statePath,
            artifacts: session.source?.artifacts ?? {},
            importedAt: session.source?.importedAt ?? null,
            warnings: session.source?.warnings ?? [],
            lineage: session.followUps.lineage.map((item) => ({ taskId: item.id, relation: item.relation, status: item.status })),
            following: Boolean(record.source.follower?.running),
        };
    }
    return { kind: 'sample', stage: session.scenario?.stage ?? null };
}
