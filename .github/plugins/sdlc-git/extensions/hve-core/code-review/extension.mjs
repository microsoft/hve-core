// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { CanvasError, createCanvas, joinSession } from '@github/copilot-sdk/extension';
import { ACTIONS, invokeAction, OPEN_SCHEMA } from './lib/actions.mjs';
import { createRegistry } from './lib/lifecycle.mjs';
import { CANVAS_ID, openReview } from './lib/model.mjs';
import { createCanvasServer } from './lib/server.mjs';

const registry = createRegistry();
let session;
function log(message) {
    if (!session) {
        process.stderr.write(`${message}\n`);
        return;
    }
    session.log(message, { level: 'warning', ephemeral: true }).catch(() => {
        process.stderr.write('Code Review diagnostic logging failed.\n');
    });
}
async function action(callback) {
    try {
        return await callback();
    } catch (error) {
        throw new CanvasError(error.code ?? 'operation_failed', error.message);
    }
}

const canvas = createCanvas({
    id: CANVAS_ID,
    displayName: 'Code Review',
    description: 'Connect captured changes, review coverage, findings, PR discussion, and your feedback in one read-only review canvas.',
    inputSchema: OPEN_SCHEMA,
    actions: ACTIONS.map((definition) => ({ ...definition, handler: (context) => action(() => invokeAction(registry, context)) })),
    open: (context) => action(async () => {
        const record = await registry.open(context.instanceId, async () => {
            const source = await openReview(context.session?.workingDirectory, context.input);
            const instance = { source, focus: null, server: null };
            instance.server = createCanvasServer(instance, {
                log,
                deliver: async (request) => {
                    if (typeof session?.send !== 'function') throw new CanvasError('delivery_unavailable', 'Host delivery is unavailable; ask the agent to collect the preserved feedback.');
                    return session.send(request);
                },
            });
            return instance;
        });
        const current = await record.server.state();
        return {
            title: 'Code Review',
            url: record.server.url,
            status: `${current.stale ? 'Stale source' : current.status}: ${current.reviewId}`,
        };
    }),
    onClose: (context) => registry.close(context.instanceId),
});

session = await joinSession({ canvases: [canvas] });
