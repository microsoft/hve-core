// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, describe, it } from 'node:test';

import { CLAIM_STALE_MS, claimDelivery, createFeedback, isDeliveryUncertain, ModelError, takeFeedback } from '../lib/model.mjs';
import { createInboxRunner } from '../lib/inbox.mjs';
import { createPickupTracker } from '../lib/pickup.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { createStore, StoreError } from '../lib/store.mjs';
import { scratchFolder } from './helpers/scratch.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const NOW = '2026-11-09T18:00:00.000Z';
const LATER = '2026-11-09T18:00:30.000Z';
const T0 = Date.parse(NOW);
const SESSION = '6f1c3c1e-2a7b-4d1e-9d7a-1b2c3d4e5f60';
const OTHER_SESSION = 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e';
const FROM = { sessionId: 'a0b1c2d3-e4f5-4a6b-8c7d-9e0f1a2b3c4d', handle: 'K7QF' };
const TASK_DOC = 'rpi-report-export-csv-0123456789';
const iso = (ms) => new Date(ms).toISOString();
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

/** A task document of one RPI task with three queued comments, FB-001 to FB-003. */
function taskDoc() {
    const sample = buildScenario('research', T0);
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

/**
 * Stores a task document and the inbox entry `entry-1` for SESSION, as the source canvas does.
 * `holds` lists the items handed off with each inbox entry.
 */
async function seed(store, { itemIds = ['FB-001', 'FB-002'], holds = [{ ids: itemIds, entryId: 'entry-1' }], createdAt = NOW, state = 'waiting', owner = null } = {}) {
    let doc = taskDoc();
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

/** Counts the store calls a test checks, and can make task document writes fail. */
function countingStore(store, { failDocUpdate = () => false } = {}) {
    const counts = { stamps: 0, reads: 0, presence: 0 };
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

/** An inbox runner for SESSION on the fake clock, with an injectable send function. */
function runnerFor(store, clock, options = {}) {
    return createInboxRunner({
        store,
        sessionId: SESSION,
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
});
