// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ModelError } from './model.mjs';

/**
 * Builds the adapter behind Review and send and the Not connected screen's Ask the agent. It
 * sends one user message in the session that opened the canvas: the chat shows
 * `displayPrompt`, and the agent reads `prompt`. `immediate` reaches the agent at its next
 * step, even mid-turn; `enqueue`, the default, waits until its turn ends. It only sends text
 * the server composed, from stored feedback items or the fixed request to connect the canvas;
 * the page never supplies the text.
 *
 * @param {{ getSession: () => any }} deps
 * @returns {(request: { prompt: string, displayPrompt: string, ids: string[], mode?: 'enqueue' | 'immediate' }) => Promise<{ messageId: string | null }>}
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
        const messageId = await session.send({ prompt: request.prompt, displayPrompt: request.displayPrompt, mode: request.mode === 'immediate' ? 'immediate' : 'enqueue' });
        return { messageId: typeof messageId === 'string' && messageId ? messageId : null };
    };
}
