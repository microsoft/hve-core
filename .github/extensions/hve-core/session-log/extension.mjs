// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';

import { ACTION_DEFINITIONS, createActionHandlers } from './lib/actions.mjs';
import { createLiveDefinitionProvider } from './lib/definitions.mjs';
import { createLiveInventoryProvider } from './lib/inventory.mjs';
import { createInstanceRegistry } from './lib/lifecycle.mjs';
import { isSessionId, resolveSessionStateRoot } from './lib/paths.mjs';
import { createSessionLogServer } from './lib/server.mjs';

const CANVAS_ID = 'hve-core-session-log';
const STATUS_TITLE_MAX = 60;

/** @type {import('@github/copilot-sdk/extension').CopilotSession | null} */
let joined = null;
let liveInventory = null;
let liveDefinitions = null;

function log(message, level = 'info') {
    joined?.log(`Session Log: ${message}`, { level, ephemeral: true }).catch(() => {});
}

function validateInput(input) {
    if (input === undefined || input === null) {
        return {};
    }
    if (typeof input !== 'object' || Array.isArray(input)) {
        throw new CanvasError('invalid_input', 'Canvas input must be an object.');
    }
    for (const key of Object.keys(input)) {
        if (key !== 'sessionId') {
            throw new CanvasError('invalid_input', `Unknown input property: ${key}`);
        }
    }
    if (input.sessionId !== undefined && input.sessionId !== 'current' && !isSessionId(input.sessionId)) {
        throw new CanvasError('invalid_input', 'sessionId must be a session ID or "current".');
    }
    return input;
}

async function statusFor(server) {
    const sessionId = server.selectedSessionId();
    if (!sessionId) {
        return 'No session selected';
    }
    const record = await server.shared.catalog.get(sessionId).catch(() => null);
    const prefix = sessionId === server.currentSessionId() ? 'Current session' : 'Session';
    if (!record) {
        return `${prefix} (no recorded events yet)`;
    }
    const title = record.title.length > STATUS_TITLE_MAX ? `${record.title.slice(0, STATUS_TITLE_MAX - 1)}…` : record.title;
    return `${prefix}: ${title}`;
}

const makeError = (code, message) => new CanvasError(code, message);

const registry = createInstanceRegistry({
    makeError,
    createServer(record) {
        const { root, source } = resolveSessionStateRoot({ workspacePath: joined?.workspacePath });
        return createSessionLogServer({
            root,
            rootSource: source,
            getCurrentSessionId: () => record.currentSessionId,
            liveInventory: () => {
                const joinedId = isSessionId(joined?.sessionId) ? joined.sessionId.toLowerCase() : null;
                return record.currentSessionId && record.currentSessionId === joinedId && liveInventory ? liveInventory() : Promise.resolve(null);
            },
            liveDefinitions: {
                sessionId: () => (liveDefinitions && isSessionId(joined?.sessionId) ? joined.sessionId.toLowerCase() : null),
                lookup: (kind, name) => (liveDefinitions ? liveDefinitions.lookup(kind, name) : Promise.resolve(null)),
                catalog: (kind) => (liveDefinitions ? liveDefinitions.catalog(kind) : Promise.resolve({ status: 'unavailable', items: [] })),
            },
            log,
        });
    },
});

const handlers = createActionHandlers({
    getInstance: (instanceId) => registry.get(instanceId),
    makeError,
});

const canvas = createCanvas({
    id: CANVAS_ID,
    displayName: 'Session Log',
    description: 'Readable, live log of a Copilot session with its prompts, responses, tools, and subagents.',
    inputSchema: {
        type: 'object',
        properties: {
            sessionId: { type: 'string', description: 'Session ID to show first, or "current" for the session that opens the canvas.' },
        },
        additionalProperties: false,
    },
    actions: ACTION_DEFINITIONS.map((definition) => ({ ...definition, handler: handlers[definition.name] })),

    async open(ctx) {
        const input = validateInput(ctx.input);
        const currentSessionId = isSessionId(ctx.sessionId) ? ctx.sessionId.toLowerCase() : isSessionId(joined?.sessionId) ? joined.sessionId.toLowerCase() : null;
        const instance = await registry.open({ instanceId: ctx.instanceId, currentSessionId, sessionId: input.sessionId });
        return { url: instance.server.url, title: 'Session Log', status: await statusFor(instance.server) };
    },

    async onClose(ctx) {
        await registry.close(ctx.instanceId);
    },
});

joined = await joinSession({ canvases: [canvas] });
liveInventory = createLiveInventoryProvider(joined);
liveDefinitions = createLiveDefinitionProvider(joined);
