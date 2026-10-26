// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createDelivery } from './lib/delivery.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { ModelError, PHASE_LABELS } from './lib/model.mjs';
import { SCENARIO_ID, STAGES } from './lib/scenario.mjs';
import { createCanvasServer } from './lib/server.mjs';
import { createSourceController, validateOpenInput } from './lib/sources.mjs';
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
            switchTask: (taskId) => sources.switchToTask(record, taskId),
            deliver: createDelivery({ getSession: () => joined }),
            log,
        });
    },
});

const handlers = createActionHandlers({
    getInstance: (instanceId) => registry.get(instanceId),
    store,
    makeError,
    async switchSource(instance, request, context) {
        try {
            const prepared = await sources.prepare(request, {
                workspace: request.task !== undefined && instance.source?.kind === 'rpi' ? instance.source.workspace : null,
                candidates: [context.workingDirectory, process.cwd()],
            });
            sources.attach(instance, prepared);
            return prepared;
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
            task: { type: 'string', description: 'RPI task to show from the workspace .copilot-tracking folder: "current" (the root task of the most recently active session) or a task ID. Omit to show the sample.' },
            scenario: { type: 'string', enum: [SCENARIO_ID], description: 'Sample session to show; the canvas ships one.' },
            stage: { type: 'string', enum: [...STAGES], description: 'Stage of the sample session to show when opening.' },
        },
        additionalProperties: false,
    },
    actions: ACTION_DEFINITIONS.map((definition) => ({ ...definition, handler: handlers[definition.name] })),

    async open(ctx) {
        const input = validateOpenInput(ctx.input, makeError);
        /** @type {{ sessionId: string, source: any, session: any, note: string } | undefined} */
        let prepared;
        const instance = await registry.open({
            instanceId: ctx.instanceId,
            sessionId: SCENARIO_ID,
            prepare: async () => {
                try {
                    prepared = await sources.prepare(input, { candidates: [ctx.session?.workingDirectory, process.cwd()] });
                } catch (error) {
                    throw asCanvasError(error);
                }
                return { sessionId: prepared.sessionId, source: prepared.source };
            },
        });
        const ready = /** @type {{ sessionId: string, source: any, session: any, note: string }} */ (prepared);
        if (instance.sessionId !== ready.sessionId || instance.source !== ready.source) {
            sources.attach(instance, ready);
        }
        const { session, note } = ready;
        const phase = PHASE_LABELS[session.session.activePhase] ?? session.session.activePhase;
        const status = ready.source.kind === 'rpi' ? `RPI session: ${session.task.title} · ${phase}${note}` : `Sample session: ${phase}${note}`;
        return { url: instance.server.url, title: 'RPI Workflow', status: `${status} · canvas ${instance.handle}` };
    },

    async onClose(ctx) {
        const record = registry.get(ctx.instanceId);
        if (record) sources.detach(record);
        await registry.close(ctx.instanceId);
    },
});

joined = await joinSession({ canvases: [canvas] });
