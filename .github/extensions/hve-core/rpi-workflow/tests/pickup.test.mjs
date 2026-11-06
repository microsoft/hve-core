// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createFeedback, markDelivered, recordInterpretation, takeFeedback } from '../lib/model.mjs';
import { createPickupTracker } from '../lib/pickup.mjs';
import { buildScenario } from '../lib/scenario.mjs';

const NOW = '2026-10-27T12:00:00.000Z';
const AT = '2026-10-27T12:00:05.000Z';

/** A store holding one session, with two comments sent in one message. */
function sentSession() {
    let session = buildScenario('research', Date.parse(NOW));
    session = createFeedback(session, { kind: 'comment', text: 'One', target: { id: 'F1' } }, NOW).session;
    session = createFeedback(session, { kind: 'comment', text: 'Two', target: { id: 'F1' } }, NOW).session;
    const ids = session.feedback.slice(-2).map((item) => item.id);
    session = markDelivered(session, ids, 'send', NOW, { messageId: 'msg-1' }).session;
    const docs = new Map([[session.id, session]]);
    const store = {
        async update(id, change) {
            const { session: next, result } = change(docs.get(id));
            docs.set(id, next);
            return { session: next, result };
        },
    };
    const item = (id) => docs.get(session.id).feedback.find((entry) => entry.id === id);
    return { store, docs, ids, id: session.id, item };
}

describe('pickup tracker', () => {
    it('marks the items a message carried once the chat reports the agent picked it up', async () => {
        const { store, ids, id, item } = sentSession();
        const tracker = createPickupTracker({ store });
        await tracker.remember('msg-1', [{ id, ids }]);
        assert.equal(tracker.status().waiting, 1);
        await tracker.observe({ timestamp: AT, data: { messageId: 'msg-1', turnId: 'turn-9', delivery: 'steering' } });
        assert.ok(ids.every((entry) => item(entry).pickedUpAt === AT && item(entry).pickedUpHow === 'steering'));
        assert.equal(item(ids[0]).state, 'sent', 'a pickup does not read the item back');
        assert.deepEqual({ ...tracker.status(), lastAt: null }, { events: 1, withMessageId: 1, matched: 1, lastAt: null, lastDelivery: 'steering', lastConsumed: true, waiting: 0 });
    });

    it('keeps an event that comes before the canvas recorded the send, and applies it then', async () => {
        const { store, ids, id, item } = sentSession();
        const tracker = createPickupTracker({ store });
        await tracker.observe({ timestamp: AT, data: { messageId: 'msg-1', turnId: 'turn-1', delivery: 'idle' } });
        assert.equal(item(ids[0]).pickedUpAt, undefined);
        await tracker.remember('msg-1', [{ id, ids }]);
        assert.equal(item(ids[0]).pickedUpAt, AT);
        assert.equal(item(ids[0]).pickedUpHow, 'idle');
        assert.equal(tracker.status().waiting, 0);
    });

    it('counts other chat messages without changing anything, and waits for a queued message to be consumed', async () => {
        const { store, ids, id, item } = sentSession();
        const tracker = createPickupTracker({ store });
        await tracker.remember('msg-1', [{ id, ids }]);
        await tracker.observe({ timestamp: AT, data: { content: 'typed in the chat' } });
        await tracker.observe({ timestamp: AT, data: { messageId: 'someone-else', turnId: 't', delivery: 'idle' } });
        await tracker.observe({ timestamp: AT, data: { messageId: 'msg-1', delivery: 'queued' } });
        assert.equal(item(ids[0]).pickedUpAt, undefined, 'queued without a turn is not picked up yet');
        assert.deepEqual([tracker.status().events, tracker.status().withMessageId, tracker.status().matched], [3, 2, 0]);
        await tracker.observe({ timestamp: '2026-10-27T12:01:00.000Z', data: { messageId: 'msg-1', turnId: 'turn-2', delivery: 'queued' } });
        assert.equal(item(ids[0]).pickedUpAt, '2026-10-27T12:01:00.000Z');
        assert.equal(item(ids[0]).pickedUpHow, 'queued');
    });

    it('leaves an item already read back as it is, and ignores sends without an ID', async () => {
        const { store, docs, ids, id, item } = sentSession();
        docs.set(id, recordInterpretation(docs.get(id), { feedbackId: ids[0], text: 'Read.', applied: true }, NOW).session);
        const tracker = createPickupTracker({ store });
        await tracker.remember(null, [{ id, ids }]);
        assert.equal(tracker.status().waiting, 0);
        await tracker.remember('msg-1', [{ id, ids }]);
        await tracker.observe({ timestamp: AT, data: { messageId: 'msg-1', turnId: 't', delivery: 'steering' } });
        assert.equal(item(ids[0]).pickedUpAt, undefined, 'already read back');
        assert.equal(item(ids[1]).pickedUpAt, AT);
    });
});

describe('collecting feedback', () => {
    it('counts as the agent picking it up', () => {
        let session = createFeedback(buildScenario('research', Date.parse(NOW)), { kind: 'comment', text: 'Take me' }, NOW).session;
        const id = session.feedback.at(-1).id;
        session = takeFeedback(session, AT).session;
        const item = session.feedback.find((entry) => entry.id === id);
        assert.equal(item.pickedUpAt, AT);
        assert.equal(item.pickedUpHow, 'collected');
    });
});
