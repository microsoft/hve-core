// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
    claimDelivery,
    composeInboxDelivery,
    composeSessionDelivery,
    createFeedback,
    discardFeedback,
    editFeedback,
    feedbackOverview,
    heldItemIds,
    isClaimed,
    isDeliveryUncertain,
    markDelivered,
    markDeliveryUncertain,
    queueForAgent,
    releaseDelivery,
    takeFeedback,
} from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';

const NOW = '2026-11-09T18:00:00.000Z';
const LATER = '2026-11-09T18:00:30.000Z';
const ELEVEN_MINUTES = '2026-11-09T18:11:00.000Z';
const FROM = { sessionId: 'a0b1c2d3-e4f5-4a6b-8c7d-9e0f1a2b3c4d', handle: 'K7QF' };
const TASK_DOC = 'rpi-report-export-csv-0123456789';
const HANDOFF = Object.freeze({ sessionId: '6f1c3c1e-2a7b-4d1e-9d7a-1b2c3d4e5f60', entryId: 'entry-1', relayAfter: '2026-11-09T18:00:20.000Z' });

/** A task document of a real RPI task with three queued comments, FB-001 to FB-003. */
function taskDoc() {
    const sample = buildScenario('research', Date.parse(NOW));
    let session = {
        ...sample,
        id: TASK_DOC,
        feedback: [],
        task: { ...sample.task, id: 'report-export-csv', title: 'Export the report as CSV' },
        source: {
            kind: 'rpi',
            statePath: 'workspace/rpi-sessions/2026-11-09/report/report-export-csv-state.json',
            artifacts: { research: 'workspace/research/2026-11-09/report-export-csv-research.md' },
        },
    };
    for (const text of ['Keep the header row.', 'Quote the commas.', 'Ship it on Friday.']) {
        session = createFeedback(session, { kind: 'comment', text, target: { id: 'F1' } }, NOW).session;
    }
    return session;
}

const itemOf = (session, id) => session.feedback.find((item) => item.id === id);

describe('held items of a delivery', () => {
    it('holds only the items handed off with the entry', () => {
        let session = claimDelivery(taskDoc(), ['FB-001'], NOW, { handoff: HANDOFF }).session;
        session = claimDelivery(session, ['FB-003'], LATER, { handoff: { ...HANDOFF, entryId: 'entry-2' } }).session;
        assert.deepEqual(heldItemIds(session, ['FB-001', 'FB-002', 'FB-003'], 'entry-1'), ['FB-001']);
        assert.deepEqual(heldItemIds(session, ['FB-001', 'FB-003'], 'entry-2'), ['FB-003']);
        const plain = claimDelivery(taskDoc(), ['FB-002'], NOW).session;
        assert.deepEqual(heldItemIds(plain, ['FB-002'], 'entry-1'), [], 'a send in the canvas\'s own chat is not an inbox hold');
        const sent = markDelivered(session, ['FB-001'], 'send', LATER).session;
        assert.deepEqual(heldItemIds(sent, ['FB-001'], 'entry-1'), [], 'a sent item is not held');
        assert.equal(itemOf(sent, 'FB-001').handoff, undefined, 'sending ends the handoff');
    });

    it('keeps a handoff hold past the claim window until the items are sent, released, or marked uncertain', () => {
        const held = claimDelivery(taskDoc(), ['FB-001'], NOW, { handoff: HANDOFF }).session;
        assert.deepEqual(itemOf(held, 'FB-001').handoff, HANDOFF);
        assert.ok(isClaimed(itemOf(held, 'FB-001'), ELEVEN_MINUTES));
        assert.deepEqual(takeFeedback(held, ELEVEN_MINUTES).result.map((item) => item.id), ['FB-002', 'FB-003'], 'the agent cannot collect a handed-off item');
        assert.throws(() => claimDelivery(held, ['FB-001'], ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.deepEqual(discardFeedback(held, ['FB-001'], ELEVEN_MINUTES).result.skipped, ['FB-001']);
        const released = releaseDelivery(held, ['FB-001'], LATER).session;
        assert.deepEqual([itemOf(released, 'FB-001').handoff, isClaimed(itemOf(released, 'FB-001'), LATER)], [undefined, false]);
        const uncertain = markDeliveryUncertain(held, ['FB-001'], LATER).session;
        assert.deepEqual([itemOf(uncertain, 'FB-001').handoff, isDeliveryUncertain(itemOf(uncertain, 'FB-001'))], [undefined, true]);
    });

    it('refuses a handoff without a Copilot session, an entry ID, or a relay time', () => {
        for (const handoff of [null, { ...HANDOFF, sessionId: 'not-a-session' }, { ...HANDOFF, entryId: '../entry' }, { ...HANDOFF, relayAfter: 'soon' }]) {
            assert.throws(() => claimDelivery(taskDoc(), ['FB-001'], NOW, { handoff }), { code: 'invalid_input' });
        }
    });

    it('marks uncertain items so that no path sends them again, while they can still be discarded', () => {
        const held = claimDelivery(taskDoc(), ['FB-001', 'FB-002'], NOW).session;
        const marked = markDeliveryUncertain(held, ['FB-001', 'FB-003'], LATER);
        assert.deepEqual(marked.result, ['FB-001', 'FB-003']);
        const uncertain = marked.session;
        assert.ok(isDeliveryUncertain(itemOf(uncertain, 'FB-001')));
        assert.equal(itemOf(uncertain, 'FB-001').deliveringSince, undefined, 'the hold ends');
        assert.equal(itemOf(uncertain, 'FB-001').state, 'queued');
        assert.equal(markDeliveryUncertain(uncertain, ['FB-001'], LATER).result.length, 0, 'marking twice changes nothing');

        assert.deepEqual(takeFeedback(uncertain, ELEVEN_MINUTES).result.map((item) => item.id), ['FB-002'], 'the agent collects only items it can send');
        assert.throws(() => claimDelivery(uncertain, ['FB-001'], ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.throws(() => queueForAgent(uncertain, ['FB-003'], ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.throws(() => editFeedback(uncertain, 'FB-001', 'Changed.', ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.throws(() => composeSessionDelivery([{ session: uncertain, ids: ['FB-001'] }], ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.deepEqual(feedbackOverview(uncertain, ELEVEN_MINUTES).pending.map((item) => item.id), ['FB-002'], 'uncertain items are not offered for sending');

        const discarded = discardFeedback(uncertain, ['FB-001'], ELEVEN_MINUTES);
        assert.deepEqual(discarded.result, { discarded: ['FB-001'], skipped: [] });
        assert.equal(itemOf(discarded.session, 'FB-001').state, 'dismissed');
    });

    it('settles an uncertain item when its send is recorded late, so it reads as sent', () => {
        const uncertain = markDeliveryUncertain(claimDelivery(taskDoc(), ['FB-001'], NOW).session, ['FB-001'], LATER).session;
        const recorded = markDelivered(uncertain, ['FB-001'], 'send', ELEVEN_MINUTES, { messageId: 'message-9' }).session;
        assert.equal(itemOf(recorded, 'FB-001').state, 'sent');
        assert.equal(itemOf(recorded, 'FB-001').deliveryUncertainAt, undefined);
        assert.equal(itemOf(recorded, 'FB-001').messageId, 'message-9');
    });
});

describe('inbox message', () => {
    it('opens with the inbox contract, then the task, its files, and only the items given', () => {
        const message = composeInboxDelivery(taskDoc(), ['FB-001', 'FB-003'], FROM);
        const [first, second] = message.prompt.split('\n');
        assert.equal(first, `RPI canvas K7QF in session ${FROM.sessionId} sent 2 items for this task. They are the user's input from that canvas.`);
        assert.equal(second, 'Task report-export-csv: Export the report as CSV (current phase: Research)');
        assert.match(message.prompt, /Task files:\n- State: workspace\/rpi-sessions\//);
        assert.match(message.prompt, /1\. FB-001: Comment on F1/);
        assert.match(message.prompt, /2\. FB-003: Comment on F1/);
        assert.match(message.prompt, /Keep the header row\./);
        assert.match(message.prompt, /Ship it on Friday\./);
        assert.doesNotMatch(message.prompt, /Quote the commas\./, 'an item that is not held stays out');
        assert.equal(message.displayPrompt, 'RPI canvas K7QF sent 2 items: 2 comments.');
        assert.deepEqual(message.ids, ['FB-001', 'FB-003']);
        const one = composeInboxDelivery(taskDoc(), ['FB-002'], FROM);
        assert.equal(one.prompt.split('\n')[0], `RPI canvas K7QF in session ${FROM.sessionId} sent 1 item for this task. They are the user's input from that canvas.`);
    });

    it('refuses items that are not queued, not held, or uncertain', () => {
        const session = taskDoc();
        assert.throws(() => composeInboxDelivery(session, [], FROM), { code: 'invalid_state' });
        assert.throws(() => composeInboxDelivery(session, ['FB-009'], FROM), { code: 'invalid_state' });
        const sent = markDelivered(claimDelivery(session, ['FB-001'], NOW).session, ['FB-001'], 'send', NOW).session;
        assert.throws(() => composeInboxDelivery(sent, ['FB-001'], FROM), { code: 'invalid_state' });
        const uncertain = markDeliveryUncertain(session, ['FB-002'], NOW).session;
        assert.throws(() => composeInboxDelivery(uncertain, ['FB-002'], FROM), { code: 'invalid_state' });
    });
});
