// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createDelivery } from './lib/delivery.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { ModelError, PHASE_LABELS } from './lib/model.mjs';
import { buildScenario, SCENARIO_ID, STAGES } from './lib/scenario.mjs';
import { createCanvasServer } from './lib/server.mjs';
import { createStore } from './lib/store.mjs';

const CANVAS_ID = 'hve-core-rpi-workflow';
const DEFAULT_STAGE = 'implement';

/** @type {import('@github/copilot-sdk/extension').CopilotSession | null} */
let joined = null;

function log(message, level = 'info') {
    joined?.log(`RPI Workflow: ${message}`, { level, ephemeral: true }).catch(() => {});
}

const makeError = (code, message) => new CanvasError(code, message);
const store = createStore({ log: (message) => log(message, 'warning') });

function validateInput(input) {
    if (input === undefined || input === null) {
        return {};
    }
    if (typeof input !== 'object' || Array.isArray(input)) {
        throw makeError('invalid_input', 'Canvas input must be an object.');
    }
    for (const key of Object.keys(input)) {
        if (key !== 'scenario' && key !== 'stage') {
            throw makeError('invalid_input', `Unknown input property: ${key}`);
        }
    }
    if (input.scenario !== undefined && input.scenario !== SCENARIO_ID) {
        throw makeError('invalid_input', `scenario must be ${SCENARIO_ID}; it is the only sample available.`);
    }
    if (input.stage !== undefined && !STAGES.includes(input.stage)) {
        throw makeError('invalid_input', `stage must be one of: ${STAGES.join(', ')}.`);
    }
    return input;
}

const registry = createInstanceRegistry({
    makeError,
    createServer(record) {
        return createCanvasServer({
            store,
            getSessionId: () => record.sessionId,
            deliver: createDelivery({ getSession: () => joined, getInstanceId: () => record.instanceId }),
            log,
        });
    },
});

const handlers = createActionHandlers({ getInstance: (instanceId) => registry.get(instanceId), store, makeError });

/**
 * Makes sure a session exists, loading the requested stage when asked without overwriting
 * changes the user made.
 *
 * @param {string | undefined} stage
 */
async function ensureSession(stage) {
    let existing;
    try {
        existing = await store.load(SCENARIO_ID);
    } catch (error) {
        throw makeError(error instanceof ModelError ? error.code : 'storage_failed', error instanceof Error ? error.message : 'Stored session could not be read.');
    }
    if (!existing || (stage && existing.scenario?.stage !== stage)) {
        try {
            return { session: await store.create(buildScenario(stage ?? DEFAULT_STAGE)), note: '' };
        } catch (error) {
            if (error instanceof ModelError && error.code === 'scenario_exists' && existing) {
                return { session: existing, note: ' (kept your changes; load_scenario with replace: true starts over)' };
            }
            throw makeError(error instanceof ModelError ? error.code : 'storage_failed', error instanceof Error ? error.message : 'Session could not be saved.');
        }
    }
    return { session: existing, note: '' };
}

const canvas = createCanvas({
    id: CANVAS_ID,
    displayName: 'RPI Workflow',
    description: 'Phase-aware RPI session view where the user reads, decides, edits, and steers research, plans, implementation, and reviews with the agent.',
    inputSchema: {
        type: 'object',
        properties: {
            scenario: { type: 'string', enum: [SCENARIO_ID], description: 'Sample session to show; the mockup ships one.' },
            stage: { type: 'string', enum: [...STAGES], description: 'Stage of the sample session to show when opening.' },
        },
        additionalProperties: false,
    },
    actions: ACTION_DEFINITIONS.map((definition) => ({ ...definition, handler: handlers[definition.name] })),

    async open(ctx) {
        const input = validateInput(ctx.input);
        /** @type {{ session: any, note: string } | undefined} */
        let prepared;
        const instance = await registry.open({
            instanceId: ctx.instanceId,
            sessionId: SCENARIO_ID,
            prepare: async () => {
                prepared = await ensureSession(input.stage);
            },
        });
        const { session, note } = /** @type {{ session: any, note: string }} */ (prepared);
        const phase = PHASE_LABELS[session.session.activePhase] ?? session.session.activePhase;
        return { url: instance.server.url, title: 'RPI Workflow', status: `Sample session: ${phase}${note}` };
    },

    async onClose(ctx) {
        await registry.close(ctx.instanceId);
    },
});

joined = await joinSession({ canvases: [canvas] });
