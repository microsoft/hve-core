// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { claimDelivery, createFeedback, markDelivered, markDeliveryUncertain, markPickedUp, queueForAgent } from '../lib/model.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { rootSession } from './helpers/rpi-fixture.mjs';

const NOW = '2026-11-09T12:00:00.000Z';
const LATER = '2026-11-09T12:05:00.000Z';
const CHILD = '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b';
const NAME = 'Offline trail maps';
const html = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).map(serialize).join('');
const keyed = (nodes, key) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).flatMap((node) => [node, ...elements(node)]).find((element) => (element.dataset?.key ?? element.getAttribute?.('data-key')) === key) ?? null;
const byId = (nodes, id) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).flatMap((node) => [node, ...elements(node)]).find((element) => element.getAttribute?.('id') === id) ?? null;
const textOf = (markup) => markup.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

let restore;
let components;
let makeContext;
let initialUi;
before(async () => {
    restore = installFakeDom();
    components = await import('../ui/components.mjs');
    ({ makeContext, initialUi } = await import('./helpers/render-views.mjs'));
});
after(() => restore());

const INBOX = { kind: 'inbox', sessionId: CHILD, sessionName: NAME };
const RELAY = { kind: 'relay', sessionId: CHILD, sessionName: NAME };
const OWN = { kind: 'own', sessionId: '7b2e8f10-3c4d-4e5f-8a6b-1c2d3e4f5a6b', sessionName: null };

/** A session with one comment per text, and the IDs the comments got. */
function withComments(texts, session = rootSession().session) {
    let next = session;
    const ids = texts.map((text) => {
        const made = createFeedback(next, { kind: 'comment', text, target: { id: 'F1' } }, NOW);
        next = made.session;
        return made.result.id;
    });
    return { session: next, ids };
}

/** The context of the page for a session shown from another Copilot session, with its route and the dialog's state. */
function contextFor(session, { delivery = { sessionId: CHILD, sessionName: NAME }, ui = initialUi('research'), otherTasks = [], ownSessionId = OWN.sessionId } = {}) {
    const ctx = makeContext(session, 'research', ui);
    ctx.data.delivery = delivery;
    ctx.data.otherTasks = otherTasks;
    ctx.data.ownSessionId = ownSessionId;
    return ctx;
}

/** A Copilot session that is neither this canvas's own nor the one it sends to. */
const ELSEWHERE = 'c0ffee00-1111-4222-8333-444455556666';

/** Items held for a handoff to another session and then marked uncertain, naming the chat that may hold them. */
function uncertainSession(texts, chat = CHILD) {
    const { session, ids } = withComments(texts);
    const held = claimDelivery(session, ids, NOW, { handoff: { sessionId: CHILD, entryId: 'entry-1', relayAfter: NOW } }).session;
    return { session: markDeliveryUncertain(held, ids, LATER, chat ? { sessionId: chat } : {}).session, ids };
}

describe('route words', () => {
    it('say where an inbox route goes, with the claim window before this chat\'s agent forwards', () => {
        assert.equal(components.routeSentence(INBOX), 'Goes straight to the agent in Offline trail maps through its canvas. If that canvas does not take them within 20 seconds, this chat\'s agent forwards them instead.');
    });

    it('say where a relay goes, and that no canvas runs for the session', () => {
        assert.equal(components.routeSentence(RELAY), 'Goes to this chat\'s agent, which forwards them to Offline trail maps. No canvas is running for that session.');
    });

    it('add no words for the own route, which keeps the existing wording', () => {
        assert.equal(components.routeSentence(OWN), null);
    });

    it('names a session by its short ID when it has no name', () => {
        assert.equal(components.routeName({ kind: 'relay', sessionId: CHILD, sessionName: null }), 'session 5e6f7a8b');
        assert.equal(components.routeName(null), 'the other session');
    });

    it('shows the route line in Review and send for an inbox or a relay, and leaves it hidden for the own route', () => {
        const { session, ids } = withComments(['Keep the header row.']);
        const ui = initialUi('research');
        const preview = (route) => ({ prompt: 'P', displayPrompt: 'x', ids, digest: 'd', route });
        ui.send = { note: '', preview: preview(INBOX), previewNote: '', sending: false, error: null, routeNote: null };
        const sheet = components.reviewSheet(contextFor(session, { ui }));
        const line = byId(sheet, 'send-route');
        assert.equal(line.getAttribute('hidden'), null);
        assert.match(textOf(serialize(line)), /Goes straight to the agent in Offline trail maps through its canvas\./);
        assert.equal(keyed(sheet, 'send-confirm').getAttribute('aria-describedby'), 'send-modes send-route', 'Send now is described by the route in words');

        ui.send.preview = preview(RELAY);
        const relay = byId(components.reviewSheet(contextFor(session, { ui })), 'send-route');
        assert.match(textOf(serialize(relay)), /Goes to this chat's agent, which forwards them to Offline trail maps\./);

        ui.send.preview = preview(OWN);
        const own = byId(components.reviewSheet(contextFor(session, { ui })), 'send-route');
        assert.ok(own.getAttribute('hidden') !== null, 'the own route adds nothing');
        assert.equal(textOf(serialize(own)), '');
    });

    it('shows a note beside the route when the route changed since the preview, in the attention tone', () => {
        const { session, ids } = withComments(['Keep the header row.']);
        const ui = initialUi('research');
        ui.send = { note: '', preview: { prompt: 'P', displayPrompt: 'x', ids, digest: 'd', route: RELAY }, previewNote: '', sending: false, error: null, routeNote: components.ROUTE_CHANGED_NOTE };
        const out = textOf(serialize(byId(components.reviewSheet(contextFor(session, { ui })), 'send-route')));
        assert.match(out, /Where these items go has changed\. Check where they go below, then send again\./);
        assert.match(serialize(byId(components.reviewSheet(contextFor(session, { ui })), 'send-route-note')), /class="notice tone-attention"/);
    });

    it('states the route before Send now is pressed, and names the same route in its request', () => {
        const { ids } = withComments(['Keep the header row.']);
        const preview = { prompt: 'P', displayPrompt: 'x', ids, digest: 'abc', route: INBOX };
        assert.deepEqual(components.deliveryRequest(preview, [{ taskId: 'trail-maps', id: ids[0] }], 'send', ''), { items: [{ taskId: 'trail-maps', id: ids[0] }], digest: 'abc', mode: 'send', route: 'inbox' });
        assert.deepEqual(components.deliveryRequest(preview, [{ taskId: 'trail-maps', id: ids[0] }], 'send', ' Start here. '), { items: [{ taskId: 'trail-maps', id: ids[0] }], digest: 'abc', mode: 'send', note: ' Start here. ', route: 'inbox' });
    });

    it('sends no route with Queue, which has no route, or with a preview from a server that names none', () => {
        const preview = { prompt: 'P', displayPrompt: 'x', ids: [], digest: 'abc', route: RELAY };
        assert.equal('route' in components.deliveryRequest(preview, [], 'queue', ''), false);
        const older = { prompt: 'P', displayPrompt: 'x', ids: [], digest: 'abc' };
        assert.equal('route' in components.deliveryRequest(older, [], 'send', ''), false, 'older callers keep today\'s request');
    });
});

describe('announcements', () => {
    const handed = (route, ids) => ({ handedOff: [{ taskId: 'trail-maps', ids, entryId: 'e' }], delivered: [], route });

    it('announce an inbox hand-off as items handed to the other session\'s canvas, by the count of items handed', () => {
        assert.equal(components.handAnnouncement(handed(INBOX, ['FB-001', 'FB-002'])), 'Handed 2 items to the canvas in Offline trail maps. If it does not take them within 20 seconds, this chat\'s agent forwards them.');
        const twoTasks = { handedOff: [{ taskId: 'a', ids: ['FB-001'] }, { taskId: 'b', ids: ['FB-001', 'FB-002'] }], delivered: [], route: INBOX };
        assert.match(components.handAnnouncement(twoTasks), /^Handed 3 items to the canvas in Offline trail maps\./);
    });

    it('announce a relay hand-off as items sent to this chat\'s agent to forward', () => {
        assert.equal(components.handAnnouncement(handed(RELAY, ['FB-001'])), 'Sent 1 item to this chat\'s agent to forward to Offline trail maps.');
    });

    it('say the list changed, where the items go changed, or both, with the verb of the action', () => {
        assert.equal(components.staleAnnouncement({ listChanged: true, routeMoved: false, route: INBOX, verb: 'send' }), 'Your items changed since this opened. Check the list, then send again.');
        assert.equal(components.staleAnnouncement({ listChanged: false, routeMoved: true, route: INBOX, verb: 'send' }), 'Where these items go has changed: they now go to the agent in Offline trail maps, through its canvas. Check it, then send again.');
        assert.equal(components.staleAnnouncement({ listChanged: true, routeMoved: true, route: OWN, verb: 'send' }), 'Your items changed, and where they go has changed: they now go to this chat\'s agent. Check the list, then send again.');
    });

    it('announce only items whose delivery became uncertain since the page last showed them', () => {
        const before = { session: rootSession().session, otherTasks: [], delivery: null, ownSessionId: OWN.sessionId };
        assert.equal(components.uncertainAnnouncement(before, before), null);
        const { session } = uncertainSession(['Keep the header row.']);
        const after = { session, otherTasks: [], delivery: { sessionId: CHILD, sessionName: NAME }, ownSessionId: OWN.sessionId };
        assert.equal(components.uncertainAnnouncement(before, after), '1 item may already have been sent. Check the chat in Offline trail maps; it is not sent again.');
        assert.equal(components.uncertainAnnouncement(after, after), null, 'the same items are not announced again');
    });
});

describe('sent items show their route', () => {
    it('say that an inbox item went direct to its session, and a relayed one went through this chat or the sending session\'s chat', () => {
        const { session, ids } = withComments(['Direct', 'Relayed', 'Relayed elsewhere']);
        const [direct, relayed, elsewhere] = ids;
        const sent = markDelivered(session, [direct], 'send', NOW, { messageId: 'm1', route: 'inbox' }).session;
        const mine = markDelivered(sent, [relayed], 'send', NOW, { messageId: 'm2', route: 'relay', relayedVia: OWN.sessionId }).session;
        const all = markDelivered(mine, [elsewhere], 'send', NOW, { messageId: 'm3', route: 'relay', relayedVia: ELSEWHERE }).session;
        const ctx = contextFor(all);
        const stage = (id) => components.stageOf(ctx, all.feedback.find((item) => item.id === id));
        assert.deepEqual([stage(direct).badge.label, stage(direct).words], ['Sent', 'as a chat message, direct to its session']);
        assert.deepEqual([stage(relayed).badge.label, stage(relayed).words], ['Sent', 'as a chat message, relayed through this chat']);
        assert.deepEqual([stage(elsewhere).badge.label, stage(elsewhere).words], ['Sent', "as a chat message, relayed through the sending session's chat"]);
    });

    it('keep the route with its pickup, once the agent has the item', () => {
        const { session, ids } = withComments(['Relayed and picked up']);
        const relayed = markDelivered(session, ids, 'send', NOW, { messageId: 'm1', route: 'relay', relayedVia: OWN.sessionId }).session;
        const picked = markPickedUp(relayed, ids, { at: LATER, how: 'steering' }, LATER).session;
        const stage = components.stageOf(contextFor(picked), picked.feedback[0]);
        assert.deepEqual([stage.badge.label, stage.words], ['The agent has it', 'at its next step, relayed through this chat']);
    });

    it('leave own sends with the words they had', () => {
        const { session, ids } = withComments(['Own']);
        const sent = markDelivered(session, ids, 'send', NOW, { messageId: 'm1' }).session;
        assert.deepEqual(components.stageOf(contextFor(sent), sent.feedback[0]).words, 'as a chat message');
    });
});

describe('items whose delivery may have reached their session', () => {
    it('show the May have been sent badge in the attention tone, with the words that say what to do', () => {
        const { session, ids } = uncertainSession(['Maybe sent']);
        const stage = components.stageOf(contextFor(session), session.feedback.find((item) => item.id === ids[0]));
        assert.deepEqual(stage, { badge: { icon: 'alert', label: 'May have been sent', tone: 'attention' }, at: LATER, words: 'check the chat in Offline trail maps; not sent again' });
        const words = (chat) => {
            const made = uncertainSession(['Maybe sent'], chat);
            return components.stageOf(contextFor(made.session), made.session.feedback.find((item) => item.id === made.ids[0])).words;
        };
        assert.equal(words(OWN.sessionId), 'check this chat; not sent again', 'a relay that may be in this chat');
        assert.equal(words(ELSEWHERE), 'check the chat in session c0ffee00; not sent again');
        assert.equal(words(null), 'check the chat it went to; not sent again', 'an item that names no chat');
    });

    it('are never offered in Review and send, and do not count toward what waits for you', () => {
        const { session, ids } = uncertainSession(['Maybe sent']);
        const ctx = contextFor(session);
        assert.deepEqual(components.pendingItems(ctx), []);
        assert.deepEqual(components.sendItems(ctx), []);
        assert.equal(components.waitingCount(ctx), 0);
        const sheet = components.reviewSheet(ctx);
        assert.match(textOf(html(sheet)), /has nothing waiting to send\./);
        assert.equal(keyed(sheet, `review-discard-trail-maps-${ids[0]}`), null);
    });

    it('show in Your feedback with Discard as their only action, and no Take back for an item queued for the agent', () => {
        const { session: asked, ids } = withComments(['Maybe sent']);
        const queued = queueForAgent(asked, ids, NOW).session;
        const held = claimDelivery(queued, ids, NOW, { handoff: { sessionId: CHILD, entryId: 'entry-1', relayAfter: NOW } }).session;
        const session = markDeliveryUncertain(held, ids, LATER, { sessionId: CHILD }).session;
        const steer = components.steerPanel(contextFor(session));
        const out = textOf(html(steer));
        assert.match(out, /May have been sent \(1\)/);
        assert.match(out, /Check the chat in Offline trail maps before you discard these\. They are not sent again\./);
        const id = ids[0];
        assert.ok(keyed(steer, `fb-discard-${id}`), 'Discard');
        assert.equal(keyed(steer, `fb-edit-${id}`), null, 'no Edit');
        assert.equal(keyed(steer, `fb-goto-${id}`), null, 'no Go to');
        assert.equal(keyed(steer, `take-back-${id}`), null, 'no Take back');
        assert.equal(components.agentQueueItems(contextFor(session)).length, 0, 'the agent does not collect it either');
    });

    it('turn Discard into a labeled question that names the item, and disarm on Escape', () => {
        const { session, ids } = uncertainSession(['Maybe sent']);
        const id = ids[0];
        const key = `fb-discard-${id}`;
        const ui = initialUi('research');
        const disarmed = [];
        const ctx = contextFor(session, { ui });
        ctx.act = { pressConfirm: () => {}, disarmConfirm: (name) => disarmed.push(name), confirmBlurred: () => {}, discardFeedback: () => {} };
        ui.confirm = { key, at: Date.now() };
        const armed = keyed(components.steerPanel(ctx), key);
        assert.match(serialize(armed), new RegExp(`class="btn btn-confirm is-armed"[^>]*><svg[^>]*>.*</svg><span>Discard ${id}\\?</span>`));
        assert.equal(armed.localName, 'button');
        assert.equal(armed.getAttribute('type'), 'button');
        let prevented = 0;
        for (const listener of armed.listeners.keydown ?? []) listener({ key: 'Escape', repeat: false, preventDefault: () => { prevented += 1; }, stopPropagation: () => {} });
        assert.deepEqual([prevented, disarmed], [1, [key]], 'Escape disarms the armed button without leaving the panel');
    });

    it('confirm a deliberate second press by discarding that item alone', () => {
        const { session, ids } = uncertainSession(['Maybe sent']);
        const discarded = [];
        const ctx = contextFor(session);
        ctx.act = { pressConfirm: (key, onConfirm) => onConfirm(), disarmConfirm: () => {}, confirmBlurred: () => {}, discardFeedback: (items) => discarded.push(items) };
        for (const listener of keyed(components.steerPanel(ctx), `fb-discard-${ids[0]}`).listeners.click ?? []) listener();
        assert.deepEqual(discarded, [[{ taskId: 'trail-maps', id: ids[0] }]]);
    });

    it('count the uncertain items of a session\'s other tasks', () => {
        const session = rootSession().session;
        const ctx = contextFor(session, { otherTasks: [{ taskId: 'trail-maps-fixes', title: 'Fixes', status: 'running', statePath: 'x', pending: [], awaiting: 0, relayed: [], uncertain: ['FB-009'] }] });
        assert.deepEqual(components.uncertainFeedback(ctx.data), [{ taskId: 'trail-maps-fixes', id: 'FB-009' }]);
    });
});

describe('delivery notices', () => {
    it('show a relay notice that names the route and dismisses by keyboard, until more items are relayed', () => {
        const { session, ids } = withComments(['Relayed', 'Relayed later']);
        const [first, later] = ids;
        const relayed = markDelivered(session, [first], 'send', NOW, { messageId: 'm1', route: 'relay', relayedVia: OWN.sessionId }).session;
        const ui = initialUi('research');
        const [note] = components.deliveryNotices(contextFor(relayed, { ui }));
        assert.match(textOf(html(note)), /Relayed to Offline trail maps: 1 item went to this chat's agent, which forwards it\./);
        assert.match(serialize(note), /class="status-note notice tone-accent"/);
        const signature = note.dataset.note;
        assert.equal(signature, `relay:trail-maps:${first}`);
        const dismiss = keyed(note, 'dismiss-relay');
        assert.equal(dismiss.localName, 'button');
        assert.match(serialize(dismiss), /<span class="visually-hidden">Dismiss relay note<\/span>/, 'a labeled button');
        assert.match(serialize(dismiss), /title="Dismiss this note"/);
        const dismissed = [];
        const pressing = contextFor(relayed, { ui });
        pressing.act = { dismissDeliveryNotice: (key) => dismissed.push(key) };
        for (const listener of keyed(components.deliveryNotices(pressing), 'dismiss-relay').listeners.click ?? []) listener();
        assert.deepEqual(dismissed, [signature]);
        ui.dismissedNotices.add(signature);
        assert.deepEqual(components.deliveryNotices(contextFor(relayed, { ui })), [], 'dismissed until the relayed items change');
        const both = markDelivered(relayed, [later], 'send', LATER, { messageId: 'm2', route: 'relay', relayedVia: OWN.sessionId }).session;
        const [returned] = components.deliveryNotices(contextFor(both, { ui }));
        assert.match(textOf(html(returned)), /Relayed to Offline trail maps: 2 items went to this chat's agent, which forwards them\./);
        assert.notEqual(returned.dataset.note, signature, 'a new set of relayed items shows again');
    });

    it('drop the relay notice once this chat\'s agent has taken the items, and show none for other routes or another session\'s relay', () => {
        const { session, ids } = withComments(['Taken', 'Direct']);
        const relayed = markDelivered(session, [ids[0]], 'send', NOW, { messageId: 'm1', route: 'relay', relayedVia: OWN.sessionId }).session;
        const theirs = markDelivered(session, [ids[0]], 'send', NOW, { messageId: 'm1', route: 'relay', relayedVia: ELSEWHERE }).session;
        assert.deepEqual(components.deliveryNotices(contextFor(theirs)), [], 'a relay through another session\'s chat is that canvas\'s to report');
        const taken = markPickedUp(relayed, [ids[0]], { at: LATER, how: 'steering' }, LATER).session;
        assert.deepEqual(components.deliveryNotices(contextFor(taken)), []);
        const direct = markDelivered(session, [ids[1]], 'send', NOW, { messageId: 'm2', route: 'inbox' }).session;
        assert.deepEqual(components.deliveryNotices(contextFor(direct)), []);
    });

    it('show an uncertain notice that asks for a check of the chat, and offers Discard once checked', () => {
        const { session, ids } = uncertainSession(['One', 'Two']);
        const ctx = contextFor(session);
        const [note] = components.deliveryNotices(ctx);
        assert.equal(note.dataset.note, 'uncertain');
        const out = textOf(html(note));
        assert.match(out, /May have been sent: 2 items\. Check the chat in Offline trail maps\. They are not sent again, so you can discard them once you have checked\./);
        assert.match(serialize(note), /class="status-note notice tone-attention"/);
        const discard = keyed(note, 'notice-discard-uncertain');
        assert.equal(discard.localName, 'button');
        assert.match(serialize(discard), /<span>Discard 2 items<\/span>/);
        ctx.ui.confirm = { key: 'notice-discard-uncertain', at: Date.now() };
        assert.match(serialize(keyed(components.deliveryNotices(ctx), 'notice-discard-uncertain')), /<span>Discard 2 items\?<\/span>/);
        const discarded = [];
        ctx.act = { discardFeedback: (items) => discarded.push(items), pressConfirm: (key, onConfirm) => onConfirm(), disarmConfirm: () => {}, confirmBlurred: () => {} };
        ctx.ui.confirm = null;
        for (const listener of keyed(components.deliveryNotices(ctx), 'notice-discard-uncertain').listeners.click ?? []) listener();
        assert.deepEqual(discarded, [ids.map((id) => ({ taskId: 'trail-maps', id }))]);
    });

    it('count a session\'s other tasks in the uncertain notice, and show nothing when no item is uncertain', () => {
        const other = { taskId: 'trail-maps-fixes', title: 'Fixes', status: 'running', statePath: 'x', pending: [], awaiting: 0, relayed: [], uncertain: ['FB-009'], uncertainIn: [CHILD] };
        const [note] = components.deliveryNotices(contextFor(rootSession().session, { otherTasks: [other] }));
        assert.match(textOf(html(note)), /May have been sent: 1 item\. Check the chat in Offline trail maps\. It is not sent again/);
        const mine = uncertainSession(['Relay that may be here'], OWN.sessionId);
        const [mixed] = components.deliveryNotices(contextFor(mine.session, { otherTasks: [other] }));
        assert.match(textOf(html(mixed)), /May have been sent: 2 items\. Check the chat each item names\./, 'items in different chats name no single chat');
        assert.deepEqual(components.deliveryNotices(contextFor(rootSession().session)), []);
    });
});
