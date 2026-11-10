// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
    CLAIM_STALE_MS,
    claimDelivery,
    claimRelay,
    composeInboxDelivery,
    composeRelayDelivery,
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
    markPickedUp,
    queueForAgent,
    releaseDelivery,
    releaseRelay,
    relayItemIds,
    takeBackFeedback,
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

    it('lists the uncertain items and the relayed items the chat has not taken yet in a task\'s overview', () => {
        const uncertain = markDeliveryUncertain(claimDelivery(taskDoc(), ['FB-001'], NOW).session, ['FB-001'], LATER, { sessionId: HANDOFF.sessionId }).session;
        assert.equal(itemOf(uncertain, 'FB-001').uncertainIn, HANDOFF.sessionId);
        const relayed = markDelivered(uncertain, ['FB-002'], 'send', LATER, { messageId: 'message-1', route: 'relay', relayedVia: FROM.sessionId }).session;
        assert.equal(itemOf(relayed, 'FB-002').relayedVia, FROM.sessionId);
        const overview = feedbackOverview(relayed, LATER, { viewer: FROM.sessionId });
        assert.deepEqual([overview.pending.map((item) => item.id), overview.awaiting, overview.relayed, overview.uncertain, overview.uncertainIn], [['FB-003'], 1, ['FB-002'], ['FB-001'], [HANDOFF.sessionId]]);
        assert.deepEqual(feedbackOverview(relayed, LATER, { viewer: HANDOFF.sessionId }).relayed, [], 'only the session that relayed an item lists it as relayed');
        assert.deepEqual(feedbackOverview(relayed, LATER).relayed, [], 'a page that does not know its session lists no relay');
        const picked = markPickedUp(relayed, ['FB-002'], { at: LATER, how: 'idle' }, LATER).session;
        assert.deepEqual(feedbackOverview(picked, LATER, { viewer: FROM.sessionId }).relayed, [], 'once the chat\'s agent has the relayed item, it is no longer pending a relay');
        const direct = markDelivered(uncertain, ['FB-002'], 'send', LATER, { messageId: 'message-2', route: 'inbox', relayedVia: FROM.sessionId }).session;
        assert.deepEqual([feedbackOverview(direct, LATER, { viewer: FROM.sessionId }).relayed, itemOf(direct, 'FB-002').relayedVia], [[], undefined], 'an item sent straight to its session is not relayed');
        const settled = markDelivered(uncertain, ['FB-001'], 'send', LATER, { messageId: 'message-3' }).session;
        assert.deepEqual([itemOf(settled, 'FB-001').deliveryUncertainAt, itemOf(settled, 'FB-001').uncertainIn], [undefined, undefined], 'a late record settles the item');
    });

    it('refuses to take back an uncertain item, which can only be discarded', () => {
        const queued = queueForAgent(taskDoc(), ['FB-001'], NOW).session;
        const uncertain = markDeliveryUncertain(claimDelivery(queued, ['FB-001'], NOW).session, ['FB-001'], LATER).session;
        assert.throws(() => takeBackFeedback(uncertain, ['FB-001'], ELEVEN_MINUTES), { code: 'invalid_state' });
        assert.equal(itemOf(uncertain, 'FB-001').queuedForAgentAt, NOW, 'the item keeps its place in the agent\'s queue');
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

describe('relay claims', () => {
    const T0 = Date.parse(NOW);
    const iso = (ms) => new Date(ms).toISOString();
    const CLAIM = Object.freeze({ pid: 101, at: NOW });
    const OTHER = Object.freeze({ pid: 202, at: LATER });
    const ENTRY_ITEMS = ['FB-001', 'FB-002'];
    const handed = () => claimDelivery(taskDoc(), ENTRY_ITEMS, NOW, { handoff: HANDOFF }).session;

    it('takes the relay of the items an entry holds, and a fresh claim by another process blocks it', () => {
        const { session, result } = claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'take' });
        assert.deepEqual(result, { state: 'claimed', ids: ENTRY_ITEMS });
        assert.deepEqual(itemOf(session, 'FB-001').handoff.relaying, CLAIM);
        assert.equal(itemOf(session, 'FB-003').handoff, undefined, 'an item not held for the entry is not taken');
        assert.deepEqual(relayItemIds(session, 'entry-1', CLAIM), ENTRY_ITEMS);
        assert.deepEqual(relayItemIds(session, 'entry-1', OTHER), [], 'only the claim that took the items names them');
        assert.deepEqual(claimRelay(session, 'entry-1', OTHER, LATER, { policy: 'take' }).result, { state: 'busy', ids: ENTRY_ITEMS, staleAt: iso(T0 + CLAIM_STALE_MS + 1) });
        assert.deepEqual(claimRelay(session, 'entry-2', OTHER, LATER, { policy: 'take' }).result, { state: 'none', ids: [] });
    });

    it('takes over a stale claim only under take, and under the other policies reports it busy or lapsed', () => {
        const claimed = claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'take' }).session;
        const waiting = claimRelay(claimed, 'entry-1', OTHER, ELEVEN_MINUTES, { policy: 'wait' });
        assert.deepEqual([waiting.result, waiting.session === claimed], [{ state: 'busy', ids: ENTRY_ITEMS, staleAt: null }, true]);
        const lapsed = claimRelay(claimed, 'entry-1', OTHER, ELEVEN_MINUTES, { policy: 'lapse' });
        assert.deepEqual([lapsed.result, lapsed.session === claimed], [{ state: 'lapsed', ids: ENTRY_ITEMS }, true]);
        const taken = claimRelay(claimed, 'entry-1', OTHER, ELEVEN_MINUTES, { policy: 'take' });
        assert.equal(taken.result.state, 'claimed');
        assert.deepEqual(itemOf(taken.session, 'FB-001').handoff.relaying, OTHER);
    });

    it('claims a lapsed entry without a relay claim, since no process has relayed the items', () => {
        const lapsed = claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'lapse' });
        assert.equal(lapsed.result.state, 'claimed');
    });

    it('refuses a claim without a process ID or time, and an unknown policy', () => {
        assert.throws(() => claimRelay(handed(), 'entry-1', { pid: 0, at: NOW }, NOW, { policy: 'take' }), { code: 'invalid_input' });
        assert.throws(() => claimRelay(handed(), 'entry-1', { pid: 1, at: 'soon' }, NOW, { policy: 'take' }), { code: 'invalid_input' });
        assert.throws(() => claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'maybe' }), { code: 'invalid_input' });
    });

    it('releases only the relay claim that took the items', () => {
        const claimed = claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'take' }).session;
        assert.deepEqual(releaseRelay(claimed, ENTRY_ITEMS, OTHER, LATER).result, [], 'another process cannot clear the claim');
        const released = releaseRelay(claimed, ENTRY_ITEMS, CLAIM, LATER);
        assert.deepEqual(released.result, ENTRY_ITEMS);
        assert.deepEqual([itemOf(released.session, 'FB-001').handoff.relaying, itemOf(released.session, 'FB-001').handoff.entryId], [undefined, 'entry-1']);
        assert.deepEqual(releaseRelay(released.session, ENTRY_ITEMS, CLAIM, LATER).result, [], 'a released claim is not released twice');
    });

    it('ends the relay claim with the handoff when the items are sent, released, or marked uncertain', () => {
        const claimed = claimRelay(handed(), 'entry-1', CLAIM, NOW, { policy: 'take' }).session;
        const sent = markDelivered(claimed, ['FB-001'], 'send', LATER, { messageId: 'relay-1', route: 'relay' }).session;
        assert.deepEqual([itemOf(sent, 'FB-001').handoff, itemOf(sent, 'FB-001').route], [undefined, 'relay']);
        assert.equal(itemOf(markDeliveryUncertain(claimed, ['FB-001'], LATER).session, 'FB-001').handoff, undefined);
        assert.equal(itemOf(releaseDelivery(claimed, ['FB-001'], LATER).session, 'FB-001').handoff, undefined);
    });
});

describe('route an item was sent by', () => {
    it('stores the inbox or relay route on sent items, refuses other routes, and leaves own sends without one', () => {
        const held = claimDelivery(taskDoc(), ['FB-001', 'FB-002'], NOW, { handoff: HANDOFF }).session;
        const inbox = markDelivered(held, ['FB-001'], 'send', LATER, { messageId: 'message-3', route: 'inbox' }).session;
        assert.equal(itemOf(inbox, 'FB-001').route, 'inbox');
        assert.equal(itemOf(markDelivered(held, ['FB-002'], 'send', LATER, { route: 'relay' }).session, 'FB-002').route, 'relay');
        assert.throws(() => markDelivered(held, ['FB-001'], 'send', LATER, { route: 'own' }), { code: 'invalid_input' });
        const own = markDelivered(claimDelivery(taskDoc(), ['FB-002'], NOW).session, ['FB-002'], 'send', LATER, { messageId: 'message-4' }).session;
        assert.equal(itemOf(own, 'FB-002').route, undefined);
    });
});

describe('relay message', () => {
    const FROM_CANVAS = { handle: 'K7QF', sessionId: HANDOFF.sessionId };
    const held = () => claimRelay(claimDelivery(taskDoc(), ['FB-001', 'FB-003'], NOW, { handoff: HANDOFF }).session, 'entry-1', { pid: 101, at: NOW }, NOW, { policy: 'take' }).session;

    it('opens with the canvas, count, session, task, and state, then the forwarding request, then the items', () => {
        const message = composeRelayDelivery(held(), ['FB-001', 'FB-003'], FROM_CANVAS);
        const [first, second] = message.prompt.split('\n');
        assert.equal(first, `RPI canvas K7QF has 2 items for session ${HANDOFF.sessionId} (task report-export-csv, state workspace/rpi-sessions/2026-11-09/report/report-export-csv-state.json).`);
        assert.equal(second, 'Forward them to that session with send_session_message: put the items below in the message as the user\'s words, and keep any note of your own in coordinator_instructions.');
        assert.match(message.prompt, /1\. FB-001: Comment on F1/);
        assert.match(message.prompt, /2\. FB-003: Comment on F1/);
        assert.match(message.prompt, /Keep the header row\./);
        assert.doesNotMatch(message.prompt, /Quote the commas\./, 'an item not held for the relay stays out');
        assert.equal(message.displayPrompt, 'RPI canvas K7QF: 2 items for another session to forward.');
        assert.deepEqual(message.ids, ['FB-001', 'FB-003']);
        const one = composeRelayDelivery(held(), ['FB-003'], FROM_CANVAS);
        assert.equal(one.prompt.split('\n')[0], `RPI canvas K7QF has 1 item for session ${HANDOFF.sessionId} (task report-export-csv, state workspace/rpi-sessions/2026-11-09/report/report-export-csv-state.json).`);
        assert.equal(one.displayPrompt, 'RPI canvas K7QF: 1 item for another session to forward.');
    });

    it('refuses items that are not held for a relay: not handed off, uncertain, or sent', () => {
        const from = FROM_CANVAS;
        assert.throws(() => composeRelayDelivery(taskDoc(), ['FB-001'], from), { code: 'invalid_state' });
        assert.throws(() => composeRelayDelivery(held(), [], from), { code: 'invalid_state' });
        assert.throws(() => composeRelayDelivery(markDeliveryUncertain(held(), ['FB-001'], LATER).session, ['FB-001'], from), { code: 'invalid_state' });
        assert.throws(() => composeRelayDelivery(markDelivered(held(), ['FB-001'], 'send', LATER).session, ['FB-001'], from), { code: 'invalid_state' });
    });
});
