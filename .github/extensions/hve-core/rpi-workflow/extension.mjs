// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createDelivery } from './lib/delivery.mjs';
import { createEditorOpener, findEditor } from './lib/editor.mjs';
import { createPickupTracker } from './lib/pickup.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { ModelError, PHASE_LABELS } from './lib/model.mjs';
import { SCENARIO_ID, STAGES } from './lib/scenario.mjs';
import { createCanvasServer } from './lib/server.mjs';
import { createSourceController, notConnected, openPlan, validateOpenInput } from './lib/sources.mjs';
import { createStore } from './lib/store.mjs';

const CANVAS_ID = 'hve-core-rpi-workflow';

/** @type {import('@github/copilot-sdk/extension').CopilotSession | null} */
let joined = null;

function log(message, level = 'info') {
    joined?.log(`RPI Workflow: ${message}`, { level, ephemeral: true }).catch(() => {});
}

const makeError = (code, message) => new CanvasError(code, message);
const store = createStore({ log: (message) => log(message, 'warning') });
const sources = createSourceController({ store, log: (message) => log(message, 'warning') });
const pickups = createPickupTracker({ store, log: (message) => log(message, 'warning') });

/** The VS Code that hosts this extension, when it is one; found once at startup. */
let editor = null;
findEditor().then((found) => {
    editor = found ? { name: found.name, open: createEditorOpener(found) } : null;
}).catch(() => {
    editor = null;
});

/** The open result: the page address and a status naming what the canvas shows. */
function openResult(instance, source, session, note) {
    if (source.kind === 'none') {
        const why = source.reason === 'missing-session' ? '; the session it showed was not found' : '';
        return { url: instance.server.url, title: 'RPI Workflow', status: `Not connected to an RPI session${why}. Connect it with show_task, giving this conversation's RPI state file or task "current" · canvas ${instance.handle}` };
    }
    const phase = PHASE_LABELS[session.session.activePhase] ?? session.session.activePhase;
    const status = source.kind === 'rpi' ? `RPI session: ${session.task.title} · ${phase}${note}` : `Sample session: ${phase}${note}`;
    return { url: instance.server.url, title: 'RPI Workflow', status: `${status} · canvas ${instance.handle}` };
}

/** Converts model and source errors into canvas errors the host shows. */
const asCanvasError = (error) => (error instanceof ModelError
    ? makeError(error.code, error.message)
    : makeError('storage_failed', error instanceof Error ? error.message : 'The canvas could not load its session.'));

const registry = createInstanceRegistry({
    makeError,
    createServer(record) {
        return createCanvasServer({
            store,
            getSessionId: () => record.sessionId,
            getCanvas: () => ({ handle: record.handle, instanceId: record.instanceId }),
            getSource: () => record.source,
            getEditor: () => editor,
            switchTask: (ref, options) => sources.switchToTask(record, ref, options),
            switchSession: (key, options) => sources.switchToSession(record, key, options),
            resumeFollowing: () => sources.resumeFollowing(record),
            pauseFollowing: () => sources.pauseFollowing(record),
            listSessions: () => sources.sessions(record),
            showSample: () => sources.show(record, { task: 'sample' }, {}),
            deliver: createDelivery({ getSession: () => joined }),
            pickups,
            log,
        });
    },
});

const handlers = createActionHandlers({
    getInstance: (instanceId) => registry.get(instanceId),
    store,
    makeError,
    chatEvents: () => pickups.status(),
    async switchSource(instance, request, context) {
        try {
            const fromWorkspace = request.task !== undefined || request.state !== undefined;
            return await sources.show(instance, request, {
                workspace: fromWorkspace && instance.source?.kind === 'rpi' ? instance.source.workspace : null,
                candidates: [context.workingDirectory, process.cwd()],
            });
        } catch (error) {
            throw asCanvasError(error);
        }
    },
});

const canvas = createCanvas({
    id: CANVAS_ID,
    displayName: 'RPI Workflow',
    description: 'Phase-aware RPI session view where the user reads, decides, edits, and steers research, plans, implementation, and reviews with the agent.',
    inputSchema: {
        type: 'object',
        properties: {
            state: { type: 'string', description: 'Workspace-relative path of the RPI state file to show, in a session folder such as .copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json. The canvas follows the session\'s running loop from there.' },
            task: { type: 'string', description: 'RPI task to show from the workspace .copilot-tracking folder: "current" (the most recently changed task whose session is running) or a task ID. Omit task and state to show the sample.' },
            scenario: { type: 'string', enum: [SCENARIO_ID], description: 'Sample session to show; the canvas ships one.' },
            stage: { type: 'string', enum: [...STAGES], description: 'Stage of the sample session to show when opening.' },
        },
        additionalProperties: false,
    },
    actions: ACTION_DEFINITIONS.map((definition) => ({ ...definition, handler: handlers[definition.name] })),

    async open(ctx) {
        const input = validateOpenInput(ctx.input, makeError);
        const current = registry.get(ctx.instanceId);
        const hostSessionId = typeof ctx.sessionId === 'string' ? ctx.sessionId : undefined;
        const open = Boolean(current?.source && current.server.listening);
        const plan = openPlan(input, {
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
                    try {
                        prepared = await sources.prepare(plan.restore, { candidates });
                        // A reopen repeats an earlier input; when it carries one, the open result says the input did not apply.
                        prepared.note = `${prepared.note} (reopened where this canvas was${Object.keys(input).length ? '; its input was not applied, so use show_task to show another task' : ''})`;
                        return { sessionId: prepared.sessionId, source: prepared.source };
                    } catch (error) {
                        // The reopen's input is a replay, not a request, so a session that is gone leaves the canvas not connected.
                        log(`Could not reopen ${plan.restore.state ?? 'the sample'}, so the canvas is not connected: ${error instanceof Error ? error.message : 'error'}`, 'warning');
                        prepared = notConnected('missing-session', plan.restore.state ?? null);
                        return { sessionId: prepared.sessionId, source: prepared.source };
                    }
                }
                try {
                    prepared = await sources.prepare(input, { candidates });
                } catch (error) {
                    throw asCanvasError(error);
                }
                return { sessionId: prepared.sessionId, source: prepared.source };
            },
        });
        const ready = /** @type {{ sessionId: string, source: any, session: any, note: string }} */ (prepared);
        // The conversation keys the instance's memory.
        instance.hostSessionId = hostSessionId;
        sources.attach(instance, ready);
        return openResult(instance, ready.source, ready.session, ready.note);
    },

    async onClose(ctx) {
        const record = registry.get(ctx.instanceId);
        if (record) sources.detach(record);
        await registry.close(ctx.instanceId);
    },
});

joined = await joinSession({ canvases: [canvas] });
// Tells the canvas when the agent picks up a message it sent, where the host passes these events on.
if (typeof joined?.on === 'function') {
    joined.on('user.message', (event) => {
        pickups.observe(event).catch((error) => log(`Could not read a chat event: ${error instanceof Error ? error.message : 'error'}`, 'warning'));
    });
}
