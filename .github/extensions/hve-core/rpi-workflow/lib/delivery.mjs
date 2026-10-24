// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';

/**
 * Builds the delivery adapter for Attach to my next message and Send now. It only sends
 * text the model composed from stored feedback items; callers never supply the text.
 *
 * @param {{ getSession: () => any, getInstanceId: () => string | null }} deps
 * @returns {(request: { mode: 'attach' | 'send', prompt: string, displayPrompt: string, ids: string[] }) => Promise<void>}
 */
export function createDelivery(deps) {
    return async function deliver(request) {
        const session = deps.getSession();
        if (!session) {
            throw new ModelError('delivery_unavailable', 'The canvas is not connected to a Copilot session.');
        }
        if (request.mode === 'attach') {
            const push = session.rpc?.extensions?.sendAttachmentsToMessage;
            if (typeof push !== 'function') {
                throw new ModelError('delivery_unavailable', 'This host cannot attach canvas feedback to your next message. Use Queue for the agent instead.');
            }
            const instanceId = deps.getInstanceId();
            await session.rpc.extensions.sendAttachmentsToMessage({
                ...(instanceId ? { instanceId } : {}),
                attachments: [{ type: 'extension_context', title: request.displayPrompt, payload: { text: request.prompt, feedbackIds: request.ids } }],
            });
            return;
        }
        if (request.mode === 'send') {
            if (typeof session.send !== 'function') {
                throw new ModelError('delivery_unavailable', 'This host cannot receive messages from the canvas.');
            }
            await session.send({ prompt: request.prompt, displayPrompt: request.displayPrompt, mode: 'enqueue' });
            return;
        }
        throw new ModelError('invalid_input', 'mode must be attach or send.');
    };
}
