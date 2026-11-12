// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createDelivery } from './lib/delivery.mjs';
import { createEditorOpener, findEditor } from './lib/editor.mjs';
import { createInboxRunner } from './lib/inbox.mjs';
import { openCanvas } from './lib/open.mjs';
import { createPickupTracker } from './lib/pickup.mjs';
import { CANVAS_ID, createPanelOpener } from './lib/panels.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { ModelError } from './lib/model.mjs';
import { SCENARIO_ID, STAGES } from './lib/scenario.mjs';
import { createCanvasServer } from './lib/server.mjs';
import { resolveSessionStateRoot, resolveSessionWorkspace } from './lib/source/sessions.mjs';
import { listRpiSessions } from './lib/source/session-list.mjs';
import { createSourceController, MAX_SESSIONS } from './lib/sources.mjs';
import { createStore } from './lib/store.mjs';

/** @type {import('@github/copilot-sdk/extension').CopilotSession | null} */
let joined = null;

function log(message, level = 'info') {
    joined?.log(`RPI Workflow: ${message}`, { level, ephemeral: true }).catch(() => {});
}

const makeError = (code, message) => new CanvasError(code, message);
const store = createStore({ log: (message) => log(message, 'warning') });
const sessionRoot = () => resolveSessionStateRoot({ workspacePath: joined?.workspacePath }).root;
const sources = createSourceController({
    store,
    log: (message) => log(message, 'warning'),
    sessionRoot,
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
            listCopilotSessions: () => listRpiSessions({
                root: sessionRoot(),
                mine: record.sessions ?? [],
                own: joined?.sessionId ?? null,
                loadPresence: (sessionId) => store.loadPresence(sessionId),
                now: () => Date.now(),
            }),
            showSession: (session) => sources.show(record, { session }, { candidates: record.candidates ?? [process.cwd()] }),
            showSample: () => sources.show(record, { task: 'sample' }, {}),
            deliver: createDelivery({ getSession: () => joined }),
            pickups,
            wakeOutbox: () => inbox?.wakeOutbox(),
            resolveSession: (sessionId) => resolveSessionWorkspace(sessionId, { root: sessionRoot() }),
            // The provider that opened this instance opens its canvas panels too.
            getExtensionId: () => record.extensionId ?? null,
            openPanel: createPanelOpener({ rpc: () => joined?.rpc, extensionId: () => record.extensionId, canvasId: CANVAS_ID }),
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
            sessions: { type: 'array', items: { type: 'string' }, maxItems: MAX_SESSIONS, description: 'Copilot session IDs (UUIDs) of the sessions this conversation started; the picker lists them first, with Show here and Open in new panel. Applied on every open, and it combines with the other inputs. Alone, it changes nothing else: the canvas opens as it would with an empty input.' },
        },
        additionalProperties: false,
    },
    actions: ACTION_DEFINITIONS.map((definition) => ({ ...definition, handler: handlers[definition.name] })),

    open: (ctx) => openCanvas(ctx, { registry, store, sources, makeError, asCanvasError }),

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
