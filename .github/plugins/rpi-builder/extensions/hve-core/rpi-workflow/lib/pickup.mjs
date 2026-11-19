// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { markPickedUp } from './model.mjs';

/** Messages remembered at once; the oldest goes first. */
const MAX_REMEMBERED = 200;
/** How long an event for a message the canvas has not recorded yet waits for it, in milliseconds. */
const EARLY_EVENT_MS = 2 * 60 * 1000;

/**
 * Learns when the agent picks up a message the canvas sent. The chat reports each user message
 * it hands to the agent as a `user.message` event carrying the ID `send` returned, the turn that
 * consumed it, and how it arrived: idle, steering, or queued. The tracker remembers in memory
 * which items each message carried and marks them picked up when that event arrives, even when
 * the event comes before the canvas finished recording the send. It also counts the events it
 * sees, so a check can tell whether the host passes them on at all.
 *
 * @param {{ store: { update: Function }, log?: (message: string) => void, now?: () => number }} deps
 */
export function createPickupTracker(deps) {
    const now = deps.now ?? (() => Date.now());
    const log = deps.log ?? (() => {});
    /** @type {Map<string, { id: string, ids: string[] }[]>} */
    const sent = new Map();
    /** @type {Map<string, { at: string, how: string | null, seenAt: number }>} */
    const early = new Map();
    const seen = { events: 0, withMessageId: 0, matched: 0, lastAt: null, lastDelivery: null, lastConsumed: null };

    const consumed = (data) => Boolean(data.turnId) || data.delivery === 'idle' || data.delivery === 'steering';

    async function apply(groups, pickup) {
        seen.matched += 1;
        for (const group of groups) {
            await deps.store.update(group.id, (current) => markPickedUp(current, group.ids, pickup, new Date(now()).toISOString()), { by: 'agent' })
                .catch((error) => log(`Could not record that the agent picked up items: ${error instanceof Error ? error.message : 'error'}`));
        }
    }

    function prune() {
        for (const [messageId, event] of early) {
            if (now() - event.seenAt > EARLY_EVENT_MS) early.delete(messageId);
        }
    }

    return {
        /**
         * Records the items one message carried, by task document, once the canvas marked them sent.
         *
         * @param {string | null} messageId
         * @param {{ id: string, ids: string[] }[]} groups
         */
        async remember(messageId, groups) {
            if (!messageId || !groups.length) return;
            prune();
            const pickup = early.get(messageId);
            if (pickup) {
                early.delete(messageId);
                await apply(groups, pickup);
                return;
            }
            sent.set(messageId, groups.map((group) => ({ id: group.id, ids: [...group.ids] })));
            if (sent.size > MAX_REMEMBERED) sent.delete(sent.keys().next().value);
        },

        /**
         * Handles a `user.message` event from the session.
         *
         * @param {{ timestamp?: string, data?: { messageId?: string, turnId?: string, delivery?: string } }} event
         */
        async observe(event) {
            const data = event?.data ?? {};
            seen.events += 1;
            seen.lastAt = typeof event?.timestamp === 'string' ? event.timestamp : new Date(now()).toISOString();
            seen.lastDelivery = data.delivery ?? null;
            seen.lastConsumed = consumed(data);
            if (!data.messageId) return;
            seen.withMessageId += 1;
            if (!consumed(data)) return;
            const pickup = { at: seen.lastAt, how: data.delivery ?? null };
            const groups = sent.get(data.messageId);
            if (!groups) {
                prune();
                early.set(data.messageId, { ...pickup, seenAt: now() });
                return;
            }
            sent.delete(data.messageId);
            await apply(groups, pickup);
        },

        /** What the tracker has seen, for get_state. */
        status() {
            return { ...seen, waiting: sent.size };
        },
    };
}
