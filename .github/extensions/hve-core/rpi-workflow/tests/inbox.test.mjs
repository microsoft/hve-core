// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';

import { CLAIM_STALE_MS, claimDelivery, claimRelay, isDeliveryUncertain, markDelivered, ModelError, takeFeedback } from '../lib/model.mjs';
import { createInboxRunner, hasLiveProcess, INBOX_VERSION, PRESENCE_TTL_MS } from '../lib/inbox.mjs';
import { createPickupTracker } from '../lib/pickup.mjs';
import { createStore, StoreError } from '../lib/store.mjs';
import { scratchFolder } from './helpers/scratch.mjs';
import { TASK_DOC, taskDoc } from './helpers/task-doc.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const NOW = '2026-11-09T18:00:00.000Z';
const LATER = '2026-11-09T18:00:30.000Z';
const T0 = Date.parse(NOW);
const SESSION = '6f1c3c1e-2a7b-4d1e-9d7a-1b2c3d4e5f60';
const OTHER_SESSION = 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e';
const FROM = { sessionId: 'a0b1c2d3-e4f5-4a6b-8c7d-9e0f1a2b3c4d', handle: 'K7QF' };
const iso = (ms) => new Date(ms).toISOString();
/** The session whose canvas hands the items over; its outbox records the handoffs. */
const SOURCE = FROM.sessionId;
/** When a handoff made at NOW is relayed, if no process claims it in the default window. */
const AFTER = iso(T0 + 20_000);
let scratch;

before(async () => {
    scratch = await scratchFolder('inbox');
});
after(async () => {
    await fs.rm(scratch, { recursive: true, force: true });
});

/**
 * A clock for tests. `advance` fires every interval that falls due, in time order, and waits for
 * each callback, so the store work a tick starts finishes before the next tick runs.
 */
function fakeClock(start = T0) {
    let time = start;
    const timers = [];
    return {
        now: () => time,
        timers,
        setInterval(fn, ms) {
            const timer = {
                fn,
                ms,
                due: time + ms,
                cleared: false,
                unrefCalls: 0,
                unref() {
                    this.unrefCalls += 1;
                    return this;
                },
            };
            timers.push(timer);
            return timer;
        },
        clearInterval(timer) {
            if (timer) timer.cleared = true;
        },
        async advance(ms) {
            const end = time + ms;
            for (;;) {
                const next = timers.filter((timer) => !timer.cleared && timer.due <= end).sort((a, b) => a.due - b.due)[0];
                if (!next) break;
                time = next.due;
                next.due += next.ms;
                await next.fn();
            }
            time = end;
        },
    };
}

/**
 * Stores a task document and the inbox entry `entry-1` for SESSION, as the source canvas does.
 * `holds` lists the items handed off with each inbox entry.
 */
async function seed(store, { itemIds = ['FB-001', 'FB-002'], holds = [{ ids: itemIds, entryId: 'entry-1' }], createdAt = NOW, state = 'waiting', owner = null } = {}) {
    let doc = taskDoc(NOW);
    for (const hold of holds) {
        doc = claimDelivery(doc, hold.ids, NOW, { handoff: { sessionId: SESSION, entryId: hold.entryId, relayAfter: iso(T0 + 20_000) } }).session;
    }
    await store.create(doc);
    await store.updateInbox(SESSION, (entries) => ({
        entries: [...entries, { id: 'entry-1', taskDoc: TASK_DOC, itemIds, from: FROM, createdAt, state, owner }],
        result: null,
    }));
    return doc;
}

/**
 * Stores the source task document with the items held for `entry-1` (the handoff to SESSION), the
 * outbox entry that records that handoff for SOURCE, and optionally the target's inbox entry and a
 * relay claim on the items taken at `claim.at`. `state` sets the outbox entry's state when given;
 * `note` names the held item that is the handoff's note.
 */
async function seedRelay(store, { holds = ['FB-001', 'FB-002'], relayAfter = NOW, claim = null, inbox = null, state, note = null } = {}) {
    let doc = claimDelivery(taskDoc(NOW), holds, NOW, { handoff: { sessionId: SESSION, entryId: 'entry-1', relayAfter }, note }).session;
    if (claim) doc = claimRelay(doc, 'entry-1', claim, claim.at, { policy: 'take' }).session;
    await store.create(doc);
    await store.updateOutbox(SOURCE, (entries) => ({ entries: [...entries, { id: 'entry-1', taskDoc: TASK_DOC, target: SESSION, handle: FROM.handle, relayAfter, createdAt: NOW, ...(state === undefined ? {} : { state }) }], result: null }));
    if (inbox) {
        await store.updateInbox(SESSION, (entries) => ({ entries: [...entries, { id: 'entry-1', taskDoc: TASK_DOC, itemIds: holds, from: { sessionId: SOURCE, handle: FROM.handle }, createdAt: NOW, state: inbox.state, owner: inbox.owner }], result: null }));
    }
    return doc;
}

/** Counts the store calls a test checks, and can make task document writes fail. */
function countingStore(store, { failDocUpdate = () => false } = {}) {
    const counts = { stamps: 0, reads: 0, presence: 0, outboxStamps: 0, outboxReads: 0 };
    return {
        ...store,
        counts,
        inboxStamp: async (id) => {
            counts.stamps += 1;
            return store.inboxStamp(id);
        },
        loadInbox: async (id) => {
            counts.reads += 1;
            return store.loadInbox(id);
        },
        outboxStamp: async (id) => {
            counts.outboxStamps += 1;
            return store.outboxStamp(id);
        },
        loadOutbox: async (id) => {
            counts.outboxReads += 1;
            return store.loadOutbox(id);
        },
        updatePresence: async (id, change) => {
            counts.presence += 1;
            return store.updatePresence(id, change);
        },
        update: async (id, change, options) => {
            if (failDocUpdate(id)) throw new StoreError('storage_failed', 'The task document could not be written.');
            return store.update(id, change, options);
        },
    };
}

/** An inbox runner for SESSION (or `options.sessionId`) on the fake clock, with an injectable send function. */
function runnerFor(store, clock, options = {}) {
    return createInboxRunner({
        store,
        sessionId: options.sessionId ?? SESSION,
        deliver: options.deliver ?? (async () => ({ messageId: 'message-1' })),
        pickups: options.pickups ?? null,
        canDeliver: options.canDeliver,
        log: options.log,
        pid: options.pid ?? 101,
        now: clock.now,
        setInterval: (fn, ms) => clock.setInterval(fn, ms),
        clearInterval: (timer) => clock.clearInterval(timer),
        pause: async () => {},
    });
}

const pidsOf = (presence) => presence.processes.map((entry) => entry.pid).sort((a, b) => a - b);
const itemOf = (doc, id) => doc.feedback.find((item) => item.id === id);

describe('presence heartbeat', () => {
    it('refreshes presence about every 30 seconds and drops processes not refreshed for two minutes', async () => {
        const store = createStore({ root: path.join(scratch, 'heartbeat') });
        await store.updatePresence(SESSION, () => [
            { pid: 111, version: 1, updatedAt: iso(T0 - 3 * 60_000) },
            { pid: 222, version: 1, updatedAt: iso(T0 - 60_000) },
        ]);
        const clock = fakeClock();
        const counted = countingStore(store);
        const runner = runnerFor(counted, clock, { pid: 333 });
        await runner.start();
        assert.deepEqual(pidsOf(await store.loadPresence(SESSION)), [222, 333], 'a stale process is dropped at once');
        await clock.advance(29_000);
        assert.equal(counted.counts.presence, 1);
        await clock.advance(1_000);
        assert.equal(counted.counts.presence, 2);
        await clock.advance(60_000);
        assert.equal(counted.counts.presence, 4);
        assert.deepEqual(pidsOf(await store.loadPresence(SESSION)), [333], 'a process silent for over two minutes is dropped');
        await runner.stop();
        store.close();
    });

    it('unrefs its timers, and stop ends both loops and removes the process from presence', async () => {
        const store = createStore({ root: path.join(scratch, 'stop') });
        const clock = fakeClock();
        const counted = countingStore(store);
        const runner = runnerFor(counted, clock, { pid: 444 });
        await runner.start();
        assert.deepEqual(clock.timers.map((timer) => timer.unrefCalls), [1, 1]);
        await runner.stop();
        const stopped = { ...counted.counts };
        await clock.advance(10 * 60_000);
        assert.deepEqual(counted.counts, stopped, 'no check or heartbeat runs after stop');
        assert.deepEqual(pidsOf(await store.loadPresence(SESSION)), []);
        store.close();
    });
});

describe('inbox check', () => {
    it('stats the inbox every two seconds and reads it only when the file changed', async () => {
        const store = createStore({ root: path.join(scratch, 'cadence') });
        const clock = fakeClock();
        const counted = countingStore(store);
        const runner = runnerFor(counted, clock, { canDeliver: () => false });
        await runner.start();
        assert.deepEqual({ stamps: counted.counts.stamps, reads: counted.counts.reads }, { stamps: 1, reads: 1 });
        await clock.advance(2_000);
        assert.deepEqual({ stamps: counted.counts.stamps, reads: counted.counts.reads }, { stamps: 2, reads: 1 }, 'an absent, unchanged inbox is not read');
        await store.updateInbox(SESSION, (entries) => ({ entries: [...entries, { id: 'entry-1', taskDoc: TASK_DOC, itemIds: ['FB-001'], from: FROM, createdAt: NOW, state: 'waiting', owner: null }], result: null }));
        await clock.advance(2_000);
        assert.deepEqual({ stamps: counted.counts.stamps, reads: counted.counts.reads }, { stamps: 3, reads: 2 }, 'a changed inbox is read once');
        await clock.advance(10_000);
        assert.deepEqual({ stamps: counted.counts.stamps, reads: counted.counts.reads }, { stamps: 8, reads: 2 }, 'an unchanged inbox is not read again');
        await runner.stop();
        store.close();
    });
});

describe('inbox consumer', () => {
    it('sends an entry once when two processes check one inbox, and ignores another session\'s entries', async () => {
        const root = path.join(scratch, 'two-processes');
        const seedStore = createStore({ root });
        await seed(seedStore);
        await seedStore.updateInbox(OTHER_SESSION, (entries) => ({ entries: [...entries, { id: 'entry-2', taskDoc: TASK_DOC, itemIds: ['FB-003'], from: FROM, createdAt: NOW, state: 'waiting', owner: null }], result: null }));
        const sends = [];
        const deliver = async (request) => {
            sends.push(request.ids);
            return { messageId: `message-${sends.length}` };
        };
        const clock = fakeClock();
        const first = runnerFor(createStore({ root }), clock, { pid: 101, deliver });
        const second = runnerFor(createStore({ root }), clock, { pid: 202, deliver });
        await Promise.all([first.checkInbox(), second.checkInbox()]);
        await first.checkInbox();
        await second.checkInbox();
        assert.deepEqual(sends, [['FB-001', 'FB-002']]);
        assert.equal((await seedStore.loadInbox(OTHER_SESSION)).entries[0].state, 'waiting', 'another session\'s entry is left for its own process');
        seedStore.close();
    });

    it('reclaims a claim whose process stopped before sending once the claim is stale, and sends the items once', async () => {
        const store = createStore({ root: path.join(scratch, 'reclaim') });
        await seed(store, { state: 'claimed', owner: { pid: 999, at: NOW } });
        const sends = [];
        const clock = fakeClock();
        const deliver = async (request) => {
            sends.push(request.ids);
            return { messageId: 'message-5' };
        };
        const runner = runnerFor(store, clock, { pid: 202, deliver });
        await runner.start();
        assert.deepEqual(sends, [], 'a fresh claim is left to its process');
        await clock.advance(CLAIM_STALE_MS);
        assert.deepEqual(sends, [], 'a claim is not stale at the end of the window');
        const meanwhile = await store.load(TASK_DOC);
        assert.deepEqual(takeFeedback(meanwhile, iso(clock.now())).result.map((item) => item.id), ['FB-003'], 'the handoff keeps the items from the agent past the claim window');
        await clock.advance(2_000);
        assert.deepEqual(sends, [['FB-001', 'FB-002']]);
        await clock.advance(CLAIM_STALE_MS);
        assert.equal(sends.length, 1);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).messageId]), [['sent', 'message-5'], ['sent', 'message-5']]);
        await runner.stop();
        store.close();
    });

    it('never sends an entry left in sending; its items become uncertain and stay out of every resend path', async () => {
        const store = createStore({ root: path.join(scratch, 'sending') });
        await seed(store, { state: 'sending', owner: { pid: 999, at: NOW } });
        const sends = [];
        const clock = fakeClock();
        const deliver = async (request) => {
            sends.push(request.ids);
            return { messageId: 'message-6' };
        };
        const runner = runnerFor(store, clock, { pid: 202, deliver });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.deepEqual(sends, []);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, [], 'the entry is removed');
        const doc = await store.load(TASK_DOC);
        for (const id of ['FB-001', 'FB-002']) {
            assert.ok(isDeliveryUncertain(itemOf(doc, id)));
            assert.equal(itemOf(doc, id).uncertainIn, SESSION, 'the message may be in this session\'s chat');
            assert.deepEqual([itemOf(doc, id).deliveringSince, itemOf(doc, id).handoff], [undefined, undefined]);
            assert.equal(itemOf(doc, id).state, 'queued');
        }
        assert.deepEqual(takeFeedback(doc, iso(clock.now() + CLAIM_STALE_MS)).result.map((item) => item.id), ['FB-003'], 'the agent does not collect them');
        await clock.advance(CLAIM_STALE_MS);
        assert.deepEqual(sends, [], 'nothing is sent later either');
        await runner.stop();
        store.close();
    });

    it('marks items uncertain when a send fails with an unknown outcome, and does not send them again', async () => {
        const store = createStore({ root: path.join(scratch, 'unknown') });
        await seed(store);
        const sends = [];
        const warnings = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, {
            deliver: async (request) => {
                sends.push(request.ids);
                throw new Error('connection reset');
            },
            log: (message, level) => warnings.push(level),
        });
        await runner.start();
        assert.deepEqual(sends, [['FB-001', 'FB-002']]);
        assert.deepEqual(warnings, ['warning']);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.ok(isDeliveryUncertain(itemOf(doc, 'FB-001')) && isDeliveryUncertain(itemOf(doc, 'FB-002')));
        await clock.advance(2 * CLAIM_STALE_MS);
        assert.equal(sends.length, 1);
        await runner.stop();
        store.close();
    });

    it('keeps an entry in sending when the send cannot be recorded, so it is not sent again', async () => {
        const root = path.join(scratch, 'unrecorded');
        const store = createStore({ root });
        await seed(store);
        let refuseWrites = true;
        const counted = countingStore(store, { failDocUpdate: (id) => refuseWrites && id === TASK_DOC });
        const sends = [];
        const clock = fakeClock();
        const deliver = async (request) => {
            sends.push(request.ids);
            return { messageId: 'message-7' };
        };
        const runner = runnerFor(counted, clock, { deliver });
        await runner.start();
        assert.deepEqual(sends, [['FB-001', 'FB-002']]);
        assert.equal((await store.loadInbox(SESSION)).entries[0].state, 'sending');
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.equal(sends.length, 1, 'the items are not sent while the record cannot be written');
        refuseWrites = false;
        await clock.advance(2_000);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.ok(isDeliveryUncertain(itemOf(doc, 'FB-001')));
        assert.equal(sends.length, 1);
        await runner.stop();
        store.close();
    });

    it('sends only the items the delivery still holds, behind the inbox contract line', async () => {
        const store = createStore({ root: path.join(scratch, 'held-only') });
        await seed(store, {
            itemIds: ['FB-001', 'FB-002', 'FB-003'],
            holds: [{ ids: ['FB-001'], entryId: 'entry-1' }, { ids: ['FB-003'], entryId: 'entry-9' }],
        });
        const requests = [];
        const clock = fakeClock();
        const deliver = async (request) => {
            requests.push(request);
            return { messageId: 'message-8' };
        };
        const runner = runnerFor(store, clock, { deliver });
        await runner.checkInbox();
        assert.equal(requests.length, 1);
        const [request] = requests;
        assert.equal(request.prompt.split('\n')[0], `RPI canvas K7QF in session ${FROM.sessionId} sent 1 item for this task. They are the user's input from that canvas.`);
        assert.match(request.prompt, /Keep the header row\./);
        assert.doesNotMatch(request.prompt, /Quote the commas\./, 'an item the delivery does not hold stays out');
        assert.doesNotMatch(request.prompt, /Ship it on Friday\./, 'an item handed off with another entry stays out');
        assert.deepEqual(request.ids, ['FB-001']);
        assert.equal(request.mode, 'immediate');
        assert.equal(request.displayPrompt, 'RPI canvas K7QF sent 1 item: 1 comment.');
        store.close();
    });

    it('marks the items picked up when the chat reports the message the canvas recorded', async () => {
        const store = createStore({ root: path.join(scratch, 'pickup') });
        await seed(store);
        const pickups = createPickupTracker({ store });
        const clock = fakeClock();
        const runner = runnerFor(store, clock, {
            pickups,
            deliver: async () => {
                // The chat can report the pickup before the canvas has recorded the send.
                await pickups.observe({ timestamp: LATER, data: { messageId: 'message-9', turnId: 'turn-1', delivery: 'idle' } });
                return { messageId: 'message-9' };
            },
        });
        await runner.checkInbox();
        const doc = await store.load(TASK_DOC);
        for (const id of ['FB-001', 'FB-002']) {
            assert.equal(itemOf(doc, id).state, 'sent');
            assert.equal(itemOf(doc, id).pickedUpAt, LATER);
            assert.equal(itemOf(doc, id).pickedUpHow, 'idle');
        }
        store.close();
    });

    it('removes an entry without sending when no item it names is still held, or its task document is gone', async () => {
        const store = createStore({ root: path.join(scratch, 'nothing-held') });
        await seed(store, { holds: [] });
        await store.updateInbox(SESSION, (entries) => ({
            entries: [...entries, { id: 'entry-2', taskDoc: 'rpi-gone-0123456789', itemIds: ['FB-001'], from: FROM, createdAt: NOW, state: 'waiting', owner: null }],
            result: null,
        }));
        const sends = [];
        const deliver = async (request) => {
            sends.push(request.ids);
            return { messageId: 'message-4' };
        };
        const runner = runnerFor(store, fakeClock(), { deliver });
        await runner.checkInbox();
        assert.deepEqual(sends, []);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        store.close();
    });

    it('returns the entry to the queue when the session cannot take messages, so another process may send it', async () => {
        const store = createStore({ root: path.join(scratch, 'unavailable') });
        await seed(store);
        const clock = fakeClock();
        const runner = runnerFor(store, clock, {
            deliver: async () => {
                throw new ModelError('delivery_unavailable', 'This host cannot take messages.');
            },
        });
        await runner.checkInbox();
        const [entry] = (await store.loadInbox(SESSION)).entries;
        assert.deepEqual([entry.state, entry.owner], ['waiting', null]);
        const doc = await store.load(TASK_DOC);
        assert.equal(itemOf(doc, 'FB-001').handoff?.entryId, 'entry-1', 'the items stay held for the entry');
        assert.equal(isDeliveryUncertain(itemOf(doc, 'FB-001')), false);
        store.close();
    });

    it('keeps the claim of an entry whose task document cannot be read, and retries it once the claim is stale', async () => {
        const root = path.join(scratch, 'unreadable');
        const store = createStore({ root });
        await seed(store);
        await fs.writeFile(path.join(root, 'sessions', `${TASK_DOC}.json`), '{ not json');
        const warnings = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { pid: 202, log: (message, level) => warnings.push(level) });
        await runner.start();
        const [claimed] = (await store.loadInbox(SESSION)).entries;
        assert.deepEqual([claimed.state, claimed.owner.pid, claimed.owner.at], ['claimed', 202, NOW]);
        await clock.advance(CLAIM_STALE_MS);
        assert.equal((await store.loadInbox(SESSION)).entries[0].owner.at, NOW, 'the claim is not returned to the queue and retried on every check');
        await clock.advance(2_000);
        assert.equal((await store.loadInbox(SESSION)).entries[0].owner.at, iso(T0 + CLAIM_STALE_MS + 2_000), 'the stale claim is retried once');
        assert.deepEqual(warnings, ['warning'], 'a repeated failure is reported once');
        await runner.stop();
        store.close();
    });

    it('sends one entry once when separate processes check the same inbox at the same time', async () => {
        const root = path.join(scratch, 'separate-processes');
        const store = createStore({ root });
        await seed(store);
        store.close();
        const log = path.join(scratch, 'separate-processes-sends.log');
        const worker = path.join(HERE, 'helpers', 'inbox-check.mjs');
        const run = (pid) => new Promise((resolve, reject) => {
            const child = spawn(process.execPath, [worker, root, SESSION, String(pid), log], { stdio: ['ignore', 'ignore', 'pipe'] });
            let stderr = '';
            child.stderr.on('data', (chunk) => {
                stderr += chunk;
            });
            child.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(stderr || `exit ${code}`))));
        });
        await Promise.all([run(301), run(302)]);
        const lines = (await fs.readFile(log, 'utf8').catch(() => '')).split('\n').filter(Boolean);
        assert.deepEqual(lines, ['FB-001,FB-002']);
    });

    it('records the inbox route on the items the target process sends', async () => {
        const store = createStore({ root: path.join(scratch, 'inbox-route') });
        await seed(store);
        await runnerFor(store, fakeClock()).checkInbox();
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => itemOf(doc, id).route), ['inbox', 'inbox']);
        store.close();
    });
});

describe('outbox relay', () => {
    const idsOf = (sends) => sends.map((request) => request.ids);
    const relayOnce = (sends) => async (request) => {
        sends.push(request);
        return { messageId: `relay-${sends.length}` };
    };

    it('stats the outbox every two seconds, and reads it only when it changed or an entry fell due', async () => {
        const store = createStore({ root: path.join(scratch, 'outbox-cadence') });
        const clock = fakeClock();
        const counted = countingStore(store);
        const sends = [];
        const runner = runnerFor(counted, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        const counts = () => [counted.counts.outboxStamps, counted.counts.outboxReads];
        await runner.start();
        assert.deepEqual(counts(), [1, 1]);
        await clock.advance(10_000);
        assert.deepEqual(counts(), [6, 1], 'an absent, unchanged outbox is not read');
        await seedRelay(store, { relayAfter: iso(T0 + 30_000) });
        await clock.advance(2_000);
        assert.deepEqual(counts(), [7, 2], 'a changed outbox is read once');
        await clock.advance(16_000);
        assert.deepEqual(counts(), [15, 2], 'an entry that is not due yet is not read');
        await clock.advance(2_000);
        assert.deepEqual(idsOf(sends), [['FB-001', 'FB-002']], 'the entry is read when it falls due, and relayed');
        assert.equal(counted.counts.outboxReads, 3);
        await clock.advance(2_000);
        assert.deepEqual(counts(), [17, 4], 'removing the entry changes the outbox once more');
        await clock.advance(10_000);
        assert.deepEqual(counts(), [22, 4], 'an empty outbox is not read again');
        await runner.stop();
        store.close();
    });

    it('relays a due entry through the session\'s own chat when a fresh process starts, and writes no inbox entry', async () => {
        const store = createStore({ root: path.join(scratch, 'restart') });
        await seedRelay(store);
        const sends = [];
        const runner = runnerFor(store, fakeClock(), { sessionId: SOURCE, pid: 303, deliver: relayOnce(sends) });
        await runner.start();
        assert.equal(sends.length, 1);
        assert.equal(sends[0].prompt.split('\n')[0], `RPI canvas K7QF has 2 items for session ${SESSION} (task report-export-csv, state workspace/rpi-sessions/2026-11-09/report/report-export-csv-state.json).`);
        assert.equal(sends[0].displayPrompt, 'RPI canvas K7QF: 2 items for another session to forward.');
        assert.equal(sends[0].mode, 'immediate');
        assert.deepEqual((await store.loadInbox(SESSION)).entries, [], 'no inbox entry is written');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route, itemOf(doc, id).messageId, itemOf(doc, id).handoff]), [['sent', 'relay', 'relay-1', undefined], ['sent', 'relay', 'relay-1', undefined]]);
        await runner.stop();
        store.close();
    });

    it('withdraws a waiting entry that no process claimed within the window, so no process can claim it, then relays its items', async () => {
        const store = createStore({ root: path.join(scratch, 'window') });
        await seedRelay(store, { relayAfter: AFTER, inbox: { state: 'waiting', owner: null } });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(18_000);
        assert.deepEqual(sends, [], 'nothing is relayed before the window ends');
        await clock.advance(2_000);
        assert.equal(sends.length, 1);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, [], 'the waiting entry is withdrawn');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route]), [['sent', 'relay'], ['sent', 'relay']]);
        await runner.stop();
        store.close();
    });

    it('leaves an entry its target process owns, and relays nothing once that process records the items', async () => {
        const store = createStore({ root: path.join(scratch, 'owned') });
        await seedRelay(store, { inbox: { state: 'claimed', owner: { pid: 202, at: NOW } } });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        assert.deepEqual(sends, [], 'a fresh claim is left to its process');
        assert.equal(itemOf(await store.load(TASK_DOC), 'FB-001').handoff.relaying, undefined, 'no relay claim is taken while the target owns the entry');
        await store.update(TASK_DOC, (current) => markDelivered(current, ['FB-001', 'FB-002'], 'send', iso(clock.now()), { messageId: 'child-1', route: 'inbox' }), { by: 'user' });
        await store.updateInbox(SESSION, (entries) => ({ entries: [], result: null }));
        await clock.advance(2_000);
        assert.deepEqual(sends, []);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        await runner.stop();
        store.close();
    });

    it('does not relay when its target claims the entry as the window ends, and the target sends the items once', async () => {
        const store = createStore({ root: path.join(scratch, 'claims-at-end') });
        await seedRelay(store, { relayAfter: NOW, inbox: { state: 'waiting', owner: null } });
        const targetSends = [];
        const target = runnerFor(store, fakeClock(), { pid: 202, deliver: async (request) => {
            targetSends.push(request.ids);
            return { messageId: 'child-1' };
        } });
        let raced = false;
        const racing = Object.create(store);
        racing.updateInbox = async (id, change, options) => {
            if (id === SESSION && !raced) {
                raced = true;
                await target.checkInbox();
            }
            return store.updateInbox(id, change, options);
        };
        const sourceSends = [];
        const source = runnerFor(racing, fakeClock(), { sessionId: SOURCE, deliver: relayOnce(sourceSends) });
        await source.checkOutbox();
        assert.deepEqual(targetSends, [['FB-001', 'FB-002']]);
        assert.deepEqual(sourceSends, [], 'the source finds the entry gone and relays nothing');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route]), [['sent', 'inbox'], ['sent', 'inbox']]);
        await target.stop();
        await source.stop();
        store.close();
    });

    it('leaves a fresh relay claim of another process alone until it goes stale, then takes the items over', async () => {
        const store = createStore({ root: path.join(scratch, 'fresh-claim') });
        await seedRelay(store, { claim: { pid: 999, at: NOW }, inbox: { state: 'waiting', owner: null } });
        const sends = [];
        const clock = fakeClock(T0 + 60_000);
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        assert.deepEqual(sends, [], 'a fresh claim is not taken over');
        assert.deepEqual((await store.loadInbox(SESSION)).entries.map((entry) => entry.state), ['waiting']);
        await clock.advance(CLAIM_STALE_MS);
        assert.equal(sends.length, 1, 'once the claim is stale, the items are relayed');
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        await runner.stop();
        store.close();
    });

    it('takes over a stale relay claim while the target entry still waits, and relays the items', async () => {
        const store = createStore({ root: path.join(scratch, 'stale-claim-waiting') });
        await seedRelay(store, { claim: { pid: 999, at: NOW }, inbox: { state: 'waiting', owner: null } });
        const sends = [];
        const runner = runnerFor(store, fakeClock(T0 + CLAIM_STALE_MS + 1_000), { sessionId: SOURCE, pid: 303, deliver: relayOnce(sends) });
        await runner.start();
        assert.equal(sends.length, 1);
        assert.deepEqual((await store.loadInbox(SESSION)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route, itemOf(doc, id).handoff]), [['sent', 'relay', undefined], ['sent', 'relay', undefined]]);
        await runner.stop();
        store.close();
    });

    it('marks items uncertain when their stale relay claim finds the target entry gone, and sends nothing', async () => {
        const store = createStore({ root: path.join(scratch, 'stale-claim-gone') });
        await seedRelay(store, { claim: { pid: 999, at: NOW } });
        const sends = [];
        const clock = fakeClock(T0 + CLAIM_STALE_MS + 1_000);
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS);
        assert.deepEqual(sends, [], 'a relay that may have been sent is never sent again');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        const doc = await store.load(TASK_DOC);
        for (const id of ['FB-001', 'FB-002']) {
            assert.ok(isDeliveryUncertain(itemOf(doc, id)));
            assert.equal(itemOf(doc, id).uncertainIn, SOURCE, 'a lapsed relay may be in the relaying session\'s chat');
            assert.equal(itemOf(doc, id).handoff, undefined);
        }
        await runner.stop();
        store.close();
    });

    it('marks items uncertain in the target\'s chat when the target left its entry in sending, and relays nothing', async () => {
        const store = createStore({ root: path.join(scratch, 'target-unconfirmed') });
        await seedRelay(store, { inbox: { state: 'sending', owner: { pid: 999, at: NOW } } });
        const sends = [];
        const clock = fakeClock(T0 + CLAIM_STALE_MS + 1_000);
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        assert.deepEqual(sends, [], 'the target may have sent them, so they are not relayed');
        assert.deepEqual([(await store.loadInbox(SESSION)).entries, (await store.loadOutbox(SOURCE)).entries], [[], []]);
        const doc = await store.load(TASK_DOC);
        for (const id of ['FB-001', 'FB-002']) {
            assert.ok(isDeliveryUncertain(itemOf(doc, id)));
            assert.equal(itemOf(doc, id).uncertainIn, SESSION, 'the message may be in the target session\'s chat');
        }
        await clock.advance(CLAIM_STALE_MS);
        assert.deepEqual(sends, []);
        await runner.stop();
        store.close();
    });

    it('releases a relay the session cannot take, and retries it at a later check', async () => {
        const store = createStore({ root: path.join(scratch, 'unavailable-relay') });
        await seedRelay(store);
        const attempts = [];
        let available = false;
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: async (request) => {
            attempts.push(request.ids);
            if (!available) throw new ModelError('delivery_unavailable', 'This host cannot take messages.');
            return { messageId: 'relay-6' };
        } });
        await runner.start();
        assert.equal(attempts.length, 1);
        const held = await store.load(TASK_DOC);
        assert.deepEqual([itemOf(held, 'FB-001').handoff.entryId, itemOf(held, 'FB-001').handoff.relaying], ['entry-1', undefined], 'the items stay held, without a relay claim');
        assert.equal((await store.loadOutbox(SOURCE)).entries.length, 1, 'the entry stays for a later check');
        available = true;
        await clock.advance(2_000);
        assert.equal(attempts.length, 2);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route]), [['sent', 'relay'], ['sent', 'relay']]);
        await runner.stop();
        store.close();
    });

    it('retries a relay whose target inbox cannot be read yet, and relays once the file can be read', async () => {
        const root = path.join(scratch, 'unreadable-target');
        const store = createStore({ root });
        await seedRelay(store);
        await fs.mkdir(path.join(root, 'inbox'), { recursive: true });
        const inboxFile = path.join(root, 'inbox', `${SESSION}.json`);
        await fs.writeFile(inboxFile, '{ not json');
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        assert.deepEqual(sends, [], 'the items wait while the target inbox cannot be read');
        assert.equal(itemOf(await store.load(TASK_DOC), 'FB-001').handoff.relaying, undefined, 'no relay claim is left behind');
        await fs.rm(inboxFile);
        await clock.advance(2_000);
        assert.equal(sends.length, 1);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        await runner.stop();
        store.close();
    });

    it('marks items uncertain when a relay fails with an unknown outcome, and never relays them again', async () => {
        const store = createStore({ root: path.join(scratch, 'unknown-relay') });
        await seedRelay(store);
        const attempts = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: async (request) => {
            attempts.push(request.ids);
            throw new Error('connection reset');
        } });
        await runner.start();
        assert.deepEqual(attempts, [['FB-001', 'FB-002']]);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        const doc = await store.load(TASK_DOC);
        assert.ok(isDeliveryUncertain(itemOf(doc, 'FB-001')) && isDeliveryUncertain(itemOf(doc, 'FB-002')));
        assert.equal(itemOf(doc, 'FB-001').uncertainIn, SOURCE);
        await clock.advance(2 * CLAIM_STALE_MS);
        assert.equal(attempts.length, 1);
        await runner.stop();
        store.close();
    });

    it('keeps the relay claim while the relay cannot be recorded, so the items are not relayed again before the claim goes stale', async () => {
        const store = createStore({ root: path.join(scratch, 'relay-unrecorded') });
        await seedRelay(store);
        let armed = false;
        const counted = countingStore(store, { failDocUpdate: (id) => armed && id === TASK_DOC });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(counted, clock, { sessionId: SOURCE, deliver: async (request) => {
            sends.push(request.ids);
            armed = true;
            return { messageId: 'relay-7' };
        } });
        await runner.start();
        assert.equal(sends.length, 1);
        assert.equal((await store.loadOutbox(SOURCE)).entries.length, 1, 'the entry stays while the relay is unrecorded');
        assert.ok(itemOf(await store.load(TASK_DOC), 'FB-001').handoff.relaying, 'the relay claim stays');
        armed = false;
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.equal(sends.length, 1, 'the relay is not sent again');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        assert.ok(isDeliveryUncertain(itemOf(await store.load(TASK_DOC), 'FB-001')));
        await runner.stop();
        store.close();
    });

    it('relays an entry once when two processes of the source session check its outbox together', async () => {
        const root = path.join(scratch, 'two-relayers');
        const seedStore = createStore({ root });
        await seedRelay(seedStore);
        const sends = [];
        const deliver = relayOnce(sends);
        const clock = fakeClock();
        const firstStore = createStore({ root });
        const secondStore = createStore({ root });
        const first = runnerFor(firstStore, clock, { sessionId: SOURCE, pid: 101, deliver });
        const second = runnerFor(secondStore, clock, { sessionId: SOURCE, pid: 202, deliver });
        await Promise.all([first.checkOutbox(), second.checkOutbox()]);
        await first.checkOutbox();
        await second.checkOutbox();
        assert.deepEqual(idsOf(sends), [['FB-001', 'FB-002']]);
        assert.deepEqual((await seedStore.loadOutbox(SOURCE)).entries, []);
        firstStore.close();
        secondStore.close();
        seedStore.close();
    });

    it('checks the outbox at once when woken, without waiting for the timer', async () => {
        const store = createStore({ root: path.join(scratch, 'wake') });
        await seedRelay(store);
        const sends = [];
        const runner = runnerFor(store, fakeClock(), { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.wakeOutbox();
        assert.deepEqual(idsOf(sends), [['FB-001', 'FB-002']]);
        store.close();
    });

    it('never relays a pending hand-off, and leaves it held until its claim window has passed', async () => {
        const store = createStore({ root: path.join(scratch, 'pending-window') });
        await seedRelay(store, { relayAfter: NOW, state: 'pending' });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS);
        assert.deepEqual(sends, [], 'a pending hand-off is not relayed, even though its relay time has passed');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries.map((entry) => entry.state), ['pending']);
        assert.equal(itemOf(await store.load(TASK_DOC), 'FB-001').handoff.entryId, 'entry-1', 'its items stay held');
        await clock.advance(2_000);
        assert.deepEqual(sends, []);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, [], 'the entry is settled');
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).handoff, itemOf(doc, id).deliveringSince]), [[undefined, undefined], [undefined, undefined]], 'the runner releases the items');
        assert.deepEqual(takeFeedback(doc, iso(clock.now())).result.map((item) => item.id), ['FB-001', 'FB-002', 'FB-003'], 'the agent may collect them again');
        await runner.stop();
        store.close();
    });

    it('releases the items and dismisses the note of a pending hand-off that never reached its target', async () => {
        const store = createStore({ root: path.join(scratch, 'pending-note') });
        await seedRelay(store, { relayAfter: NOW, state: 'pending', note: 'FB-002' });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.deepEqual(sends, []);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual([itemOf(doc, 'FB-001').state, itemOf(doc, 'FB-001').handoff], ['queued', undefined]);
        assert.equal(itemOf(doc, 'FB-002').state, 'dismissed', 'the note is dismissed');
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries, []);
        await runner.stop();
        store.close();
    });

    it('commits a pending hand-off whose target entry is waiting once its claim window has passed, then relays it', async () => {
        const store = createStore({ root: path.join(scratch, 'pending-commits') });
        await seedRelay(store, { relayAfter: NOW, state: 'pending', inbox: { state: 'waiting', owner: null } });
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.deepEqual((await store.loadOutbox(SOURCE)).entries.map((entry) => entry.state), ['committed'], 'the target entry exists, so the hand-off commits');
        assert.deepEqual(sends, []);
        await clock.advance(2_000);
        assert.deepEqual(sends.map((request) => request.ids), [['FB-001', 'FB-002']], 'the committed hand-off is relayed once the target has not claimed it');
        assert.deepEqual([(await store.loadInbox(SESSION)).entries, (await store.loadOutbox(SOURCE)).entries], [[], []]);
        const doc = await store.load(TASK_DOC);
        assert.deepEqual(['FB-001', 'FB-002'].map((id) => [itemOf(doc, id).state, itemOf(doc, id).route]), [['sent', 'relay'], ['sent', 'relay']]);
        await runner.stop();
        store.close();
    });

    it('forgets a pending hand-off whose task document is gone, and sends nothing', async () => {
        const store = createStore({ root: path.join(scratch, 'pending-gone') });
        await store.updateOutbox(SOURCE, (entries) => ({ entries: [...entries, { id: 'entry-1', taskDoc: 'rpi-gone-0123456789', target: SESSION, handle: FROM.handle, relayAfter: NOW, createdAt: NOW, state: 'pending' }], result: null }));
        const sends = [];
        const clock = fakeClock();
        const runner = runnerFor(store, clock, { sessionId: SOURCE, deliver: relayOnce(sends) });
        await runner.start();
        await clock.advance(CLAIM_STALE_MS + 2_000);
        assert.deepEqual([sends, (await store.loadOutbox(SOURCE)).entries], [[], []]);
        await runner.stop();
        store.close();
    });
});

describe('live presence', () => {
    const AT = Date.parse('2026-01-15T12:00:00.000Z');
    const beat = (updatedAt) => ({ pid: 1, version: INBOX_VERSION, updatedAt: new Date(updatedAt).toISOString() });

    it('counts a process that refreshed within the presence window, through its last moment', () => {
        assert.equal(hasLiveProcess({ processes: [beat(AT - PRESENCE_TTL_MS)] }, AT), true);
        assert.equal(hasLiveProcess({ processes: [beat(AT - PRESENCE_TTL_MS - 1)] }, AT), false);
        assert.equal(hasLiveProcess({ processes: [beat(AT - PRESENCE_TTL_MS - 1), beat(AT - 1000)] }, AT), true, 'one live process is enough');
    });

    it('reads a missing presence, or one with no processes, as not live', () => {
        assert.equal(hasLiveProcess(null, AT), false);
        assert.equal(hasLiveProcess({ processes: [] }, AT), false);
    });
});
