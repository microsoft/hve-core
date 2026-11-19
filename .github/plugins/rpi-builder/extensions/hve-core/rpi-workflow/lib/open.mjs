// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { PHASE_LABELS } from './model.mjs';
import { providerOf } from './panels.mjs';
import { SCENARIO_ID } from './scenario.mjs';
import { NOT_CONNECTED_WHY, openPlan, splitOpenInput, validateOpenInput } from './sources.mjs';

/**
 * The open result: the page address and a status naming what the canvas shows.
 *
 * @param {{ server: { url: string }, handle: string }} instance
 * @param {{ kind: string, reason?: string, boundSession?: string | null }} source
 * @param {any} session
 * @param {string} note
 */
function openResult(instance, source, session, note) {
    if (source.kind === 'none') {
        const why = NOT_CONNECTED_WHY[source.reason] ?? '';
        return { url: instance.server.url, title: 'RPI Workflow', status: `Not connected to an RPI session${why}. The user can pick a session in its session picker, or connect it with show_task, giving this conversation's RPI state file, task "current", or another session's ID · canvas ${instance.handle}` };
    }
    const phase = PHASE_LABELS[session.session.activePhase] ?? session.session.activePhase;
    const bound = source.boundSession ? ` · Copilot session ${source.boundSession}` : '';
    const status = source.kind === 'rpi' ? `RPI session: ${session.task.title} · ${phase}${bound}${note}` : `Sample session: ${phase}${note}`;
    return { url: instance.server.url, title: 'RPI Workflow', status: `${status} · canvas ${instance.handle}` };
}

/**
 * Opens a canvas instance for the host's open request. The input is validated and split from the
 * picker's sessions, which apply on every open, including one that keeps an open instance's view or
 * restores a remembered one. Otherwise `openPlan` decides whether the instance keeps what it shows,
 * restores what the conversation remembers, or shows the input.
 *
 * @param {{ instanceId: string, sessionId?: string, input?: unknown, session?: { workingDirectory?: string } | null, extensionId?: unknown }} ctx the host's open request
 * @param {{
 *   registry: { get: (instanceId: string) => any, open: (request: any) => Promise<any> },
 *   store: { loadInstance: (instanceId: string, hostSessionId?: string) => Promise<any>, load: (id: string) => Promise<any> },
 *   sources: { restore: (request: any, context?: any) => Promise<any>, prepare: (request: any, context?: any) => Promise<any>, attach: (record: any, prepared: any) => void },
 *   makeError: (code: string, message: string) => Error,
 *   asCanvasError: (error: unknown) => Error,
 * }} deps
 */
export async function openCanvas(ctx, deps) {
    const { registry, store, sources, makeError, asCanvasError } = deps;
    const { target, sessions } = splitOpenInput(validateOpenInput(ctx.input, makeError));
    const current = registry.get(ctx.instanceId);
    if (current && sessions !== undefined) current.sessions = sessions;
    const hostSessionId = typeof ctx.sessionId === 'string' ? ctx.sessionId : undefined;
    const open = Boolean(current?.source && current.server.listening);
    const plan = openPlan(target, {
        open,
        remembered: open ? null : await store.loadInstance(ctx.instanceId, hostSessionId).catch(() => null),
    });
    if (plan.keep && current) {
        if (current.source?.kind === 'none') return openResult(current, current.source, null, '');
        const session = await store.load(current.sessionId).catch(() => null);
        if (session) return openResult(current, current.source, session, '');
    }
    const candidates = [ctx.session?.workingDirectory, process.cwd()];
    /** @type {{ sessionId: string, source: any, session: any, note: string } | undefined} */
    let prepared;
    const instance = await registry.open({
        instanceId: ctx.instanceId,
        sessionId: SCENARIO_ID,
        prepare: async () => {
            if (!plan.keep && plan.restore) {
                // A reopen repeats an earlier input; when it carries one, the open result says the input did not apply.
                prepared = await sources.restore(plan.restore, { candidates });
                if (prepared.source.kind !== 'none') {
                    prepared.note = `${prepared.note} (reopened where this canvas was${Object.keys(target).length ? '; its input was not applied, so use show_task to show another task' : ''})`;
                }
                return { sessionId: prepared.sessionId, source: prepared.source };
            }
            try {
                prepared = await sources.prepare(target, { candidates });
            } catch (error) {
                throw asCanvasError(error);
            }
            return { sessionId: prepared.sessionId, source: prepared.source };
        },
    });
    const ready = /** @type {{ sessionId: string, source: any, session: any, note: string }} */ (prepared);
    // The conversation keys the instance's memory.
    instance.hostSessionId = hostSessionId;
    // The provider the host opened this instance through, which its panels reuse.
    instance.extensionId = providerOf(ctx);
    // The workspace candidates the instance's session requests resolve from, as this open did.
    instance.candidates = candidates;
    if (sessions !== undefined) instance.sessions = sessions;
    sources.attach(instance, ready);
    return openResult(instance, ready.source, ready.session, ready.note);
}
