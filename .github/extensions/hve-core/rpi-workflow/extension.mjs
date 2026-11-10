// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createDelivery } from './lib/delivery.mjs';
import { createEditorOpener, findEditor } from './lib/editor.mjs';
import { createInboxRunner } from './lib/inbox.mjs';
import { createPickupTracker } from './lib/pickup.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { ModelError, PHASE_LABELS } from './lib/model.mjs';
import { SCENARIO_ID, STAGES } from './lib/scenario.mjs';
import { createCanvasServer } from './lib/server.mjs';
import { resolveSessionStateRoot } from './lib/source/sessions.mjs';
import { createSourceController, NOT_CONNECTED_WHY, openPlan, validateOpenInput } from './lib/sources.mjs';
import { createStore } from './lib/store.mjs';

const CANVAS_ID = 'hve-core-rpi-workflow';

/** @type {import('@github/copilot-sdk/extension').CopilotSession | null} */
let joined = null;

function log(message, level = 'info') {
    joined?.log(`RPI Workflow: ${message}`, { level, ephemeral: true }).catch(() => {});
}

const makeError = (code, message) => new CanvasError(code, message);
const store = createStore({ log: (message) => log(message, 'warning') });
const sources = createSourceController({
    store,
    log: (message) => log(message, 'warning'),
    sessionRoot: () => resolveSessionStateRoot({ workspacePath: joined?.workspacePath }).root,
    ownSessionId: () => joined?.sessionId ?? null,
});
const pickups = createPickupTracker({ store, log: (message) => log(message, 'warning') });
/** This process's runner for the joined session, once it starts; null while the session is unknown. */
let inbox = null;

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
        const why = NOT_CONNECTED_WHY[source.reason] ?? '';
        return { url: instance.server.url, title: 'RPI Workflow', status: `Not connected to an RPI session${why}. Connect it with show_task, giving this conversation's RPI state file or task "current" · canvas ${instance.handle}` };
    }
    const phase = PHASE_LABELS[session.session.activePhase] ?? session.session.activePhase;
    const bound = source.boundSession ? ` · Copilot session ${source.boundSession}` : '';
    const status = source.kind === 'rpi' ? `RPI session: ${session.task.title} · ${phase}${bound}${note}` : `Sample session: ${phase}${note}`;
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
            getJoinedSessionId: () => joined?.sessionId ?? null,
            getEditor: () => editor,
            switchTask: (ref, options) => sources.switchToTask(record, ref, options),
            switchSession: (key, options) => sources.switchToSession(record, key, options),
            resumeFollowing: () => sources.resumeFollowing(record),
            pauseFollowing: () => sources.pauseFollowing(record),
            listSessions: () => sources.sessions(record),
            showSample: () => sources.show(record, { task: 'sample' }, {}),
            deliver: createDelivery({ getSession: () => joined }),
            pickups,
            wakeOutbox: () => inbox?.wakeOutbox(),
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
            return await sources.show(instance, request, { candidates: [context.workingDirectory, process.cwd()] });
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
            session: { type: 'string', description: 'Copilot session ID (a UUID) of a local session whose RPI task to show, read from that session\'s workspace. Alone, it shows the session\'s current task; with state or task, that task is in the session. The canvas keeps the session when the host reopens it. Cannot be combined with scenario or stage.' },
            state: { type: 'string', description: 'Workspace-relative path of the RPI state file to show, in a session folder such as .copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json. With session, the path is relative to that session\'s workspace. The canvas follows the session\'s running loop from there.' },
            task: { type: 'string', description: 'RPI task to show from the workspace .copilot-tracking folder, or from the session\'s workspace when session is given: "current" (the most recently changed task whose session is running) or a task ID. Omit task, state, and session to show the sample.' },
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
                    // A reopen repeats an earlier input; when it carries one, the open result says the input did not apply.
                    prepared = await sources.restore(plan.restore, { candidates });
                    if (prepared.source.kind !== 'none') {
                        prepared.note = `${prepared.note} (reopened where this canvas was${Object.keys(input).length ? '; its input was not applied, so use show_task to show another task' : ''})`;
                    }
                    return { sessionId: prepared.sessionId, source: prepared.source };
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
// Runs whether or not a canvas panel is open: announces this process for the session, sends the items other canvases hand to it,
// and relays the items this session's canvases handed to other sessions when no process of those sessions takes them.
// Its timers are unref'd, so they never keep the process alive; an exited process's presence entry ages out after two minutes.
if (joined?.sessionId) {
    inbox = createInboxRunner({
        store,
        sessionId: joined.sessionId,
        deliver: createDelivery({ getSession: () => joined }),
        pickups,
        canDeliver: () => typeof joined?.send === 'function',
        log,
    });
    inbox.start().catch(() => {});
}
