// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';

/**
 * Builds the adapter behind Send to agent. It enqueues one user message in the session
 * that opened the canvas: the chat shows `displayPrompt`, and the agent reads `prompt`.
 * It only sends text the model composed from stored feedback items; callers never supply
 * the text.
 *
 * @param {{ getSession: () => any }} deps
 * @returns {(request: { prompt: string, displayPrompt: string, ids: string[] }) => Promise<void>}
 */
export function createDelivery(deps) {
    return async function deliver(request) {
        const session = deps.getSession();
        if (!session) {
            throw new ModelError('delivery_unavailable', 'The canvas is not connected to a Copilot session. Your items stay here; ask the agent to collect them with take_feedback.');
        }
        if (typeof session.send !== 'function') {
            throw new ModelError('delivery_unavailable', 'This host cannot take messages from the canvas. Your items stay here; ask the agent to collect them with take_feedback.');
        }
        await session.send({ prompt: request.prompt, displayPrompt: request.displayPrompt, mode: 'enqueue' });
    };
}
