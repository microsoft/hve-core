// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Inbox runner for one Copilot session, started by each canvas process that joins the session.
 * The process announces itself in the session's presence file, and it sends the items that other
 * canvases addressed to the session into its own chat, whether or not a canvas panel is open.
 *
 * An inbox entry moves from `waiting` to `claimed` to `sending`. Each change happens under the
 * store's lock, so processes that poll one inbox claim an entry once. The entry's items carry its
 * handoff in the task document, which holds them until they are sent, relayed, or marked
 * uncertain, so no other path sends them meanwhile. An entry is removed only after its send is
 * recorded, or after its items are marked uncertain; a send whose outcome is unknown is never repeated.
 *
 * The same runner watches the session's outbox, the handoffs this session's canvases made. When an
 * entry falls due and the target's inbox entry is still waiting, a process relays the items through
 * this session's chat. The relay claim on the items and the removal of the inbox entry happen under
 * locks, so an item is relayed only when the target never claimed it, and at most once.
 */

import { CLAIM_STALE_MS, claimRelay, composeInboxDelivery, composeRelayDelivery, handedItemIds, heldItemIds, markDelivered, markDeliveryUncertain, ModelError, releaseRelay, relayItemIds } from './model.mjs';

/** Version of the presence and inbox protocol. A process reports it; only processes that speak it take entries. */
export const INBOX_VERSION = 1;
/** How often a process refreshes its presence entry. */
export const PRESENCE_BEAT_MS = 30 * 1000;
/** A presence entry that has not been refreshed for this long is dropped. */
export const PRESENCE_TTL_MS = 2 * 60 * 1000;
/** How often a process checks its inbox and outbox files for changes. */
export const INBOX_CHECK_MS = 2 * 1000;
/** How long a handed-off inbox entry waits to be claimed before its source canvas relays the items. */
export const CLAIM_WINDOW_MS = 20 * 1000;

/** Attempts to record a send in the task document. When all of them fail, the entry stays in `sending`. */
const MARK_ATTEMPTS = 3;
/** The pause before the first retry of recording a send; each later retry waits one step longer. */
const MARK_RETRY_MS = 50;
/** Store errors that a later check cannot fix, because the stored data itself is wrong. */
const PERMANENT = new Set(['storage_corrupt', 'storage_unsupported', 'invalid_input', 'not_found']);
/** The change that returns an entry to the queue that any process may take. */
const WAITING = Object.freeze({ state: 'waiting', owner: null });

const iso = (ms) => new Date(ms).toISOString();
const sameOwner = (a, b) => Boolean(a) && Boolean(b) && a.pid === b.pid && a.at === b.at;
/** Matches an entry in `state` that `owner` holds. */
const ownedBy = (owner, state) => (entry) => entry.state === state && sameOwner(entry.owner, owner);

/**
 * The change that removes the entry with `id` from an inbox or outbox. Returns the same array when
 * no entry has that ID, so the file is not written.
 *
 * @param {any[]} entries
 * @param {string} id
 * @returns {{ entries: any[], result: null }}
 */
export function withoutEntry(entries, id) {
    const kept = entries.filter((entry) => entry.id !== id);
    return { entries: kept.length === entries.length ? entries : kept, result: null };
}

/**
 * Whether a session's presence lists a canvas process that speaks this protocol and refreshed within
 * the presence window at `at`, in milliseconds.
 *
 * @param {{ processes: { version: number, updatedAt: string }[] } | null | undefined} presence
 * @param {number} at
 * @returns {boolean}
 */
export function hasLiveProcess(presence, at) {
    return Boolean(presence?.processes.some((entry) => entry.version >= INBOX_VERSION && at - Date.parse(entry.updatedAt) <= PRESENCE_TTL_MS));
}

/**
 * Whether a failure may pass on a later check: a busy or failed write, or a file error. Data
 * that is wrong fails the same way every time, so its claim is left to go stale rather than
 * being returned to the queue, which would retry it on every check.
 */
const retryable = (error) => !(error instanceof ModelError) || error.code === 'storage_busy' || error.code === 'storage_failed';

/**
 * Reports a failure whenever its message differs from the last one reported. `recovered` clears
 * that memory, so the same failure is reported again after a success.
 *
 * @param {string} prefix
 * @param {(message: string, level: string) => void} log
 */
function failureReport(prefix, log) {
    let last = null;
    return {
        failed(error) {
            const message = `${prefix}: ${error instanceof Error ? error.message : 'unknown error'}`;
            if (message !== last) {
                last = message;
                log(message, 'warning');
            }
        },
        recovered() {
            last = null;
        },
    };
}

/**
 * Creates the runner for one Copilot session. `start` begins the presence heartbeat and the inbox
 * and outbox checks as unref'd timers; `stop` ends them and removes the process from the session's
 * presence. `wakeOutbox` checks the outbox now, so a handoff that is due goes out at once. The store,
 * the send function, the process ID, the clocks and timers, and the stale window are all injectable.
 *
 * @param {{
 *   store: any,
 *   sessionId: string,
 *   deliver: (request: { prompt: string, displayPrompt: string, ids: string[], mode: 'immediate' }) => Promise<{ messageId: string | null }>,
 *   pickups?: { remember: (messageId: string | null, groups: { id: string, ids: string[] }[]) => Promise<void> } | null,
 *   canDeliver?: () => boolean,
 *   log?: (message: string, level: string) => void,
 *   pid?: number,
 *   version?: number,
 *   now?: () => number,
 *   setInterval?: (fn: () => unknown, ms: number) => any,
 *   clearInterval?: (handle: any) => void,
 *   pause?: (ms: number) => Promise<void>,
 *   beatMs?: number,
 *   presenceTtlMs?: number,
 *   checkMs?: number,
 *   claimStaleMs?: number,
 *   markRetryMs?: number,
 * }} deps
 */
export function createInboxRunner(deps) {
    const { store, sessionId, deliver } = deps;
    const pickups = deps.pickups ?? null;
    const canDeliver = deps.canDeliver ?? (() => true);
    const log = deps.log ?? (() => {});
    const pid = deps.pid ?? process.pid;
    const version = deps.version ?? INBOX_VERSION;
    const now = deps.now ?? (() => Date.now());
    const schedule = deps.setInterval ?? ((fn, ms) => setInterval(fn, ms));
    const unschedule = deps.clearInterval ?? ((handle) => clearInterval(handle));
    const pause = deps.pause ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    const beatMs = deps.beatMs ?? PRESENCE_BEAT_MS;
    const presenceTtlMs = deps.presenceTtlMs ?? PRESENCE_TTL_MS;
    const checkMs = deps.checkMs ?? INBOX_CHECK_MS;
    const claimStaleMs = deps.claimStaleMs ?? CLAIM_STALE_MS;
    const markRetryMs = deps.markRetryMs ?? MARK_RETRY_MS;
    const reports = {
        presence: failureReport('Could not record that this canvas is live', log),
        inbox: failureReport('Could not check the inbox', log),
        entries: failureReport('Could not handle an inbox entry', log),
        outbox: failureReport('Could not check the outbox', log),
        relays: failureReport('Could not relay items to another session', log),
    };

    let started = false;
    let stopped = false;
    let beatTimer = null;
    let checkTimer = null;
    let checking = null;
    /** The inbox stamp seen by the last read; the file is read again when it differs. */
    let stamp = null;
    /** Set when a read failed transiently, so the next check reads whatever the stamp says. */
    let dirty = true;
    /** When the earliest fresh claim goes stale, so the inbox is read then even if the file did not change. */
    let staleAt = null;
    /** The outbox stamp seen by the last read; the file is read again when it differs. */
    let outboxSeen = null;
    /** Set when the outbox must be read on the next check: a retry, or a wake. */
    let outboxDirty = true;
    /** When the earliest outbox entry falls due, so the outbox is read then even if the file did not change. */
    let outboxDueAt = null;
    let outboxChecking = null;
    /** Set when a wake arrives during an outbox check, so the check runs once more. */
    let outboxAgain = false;

    /** Refreshes this process's presence entry and drops the entries of processes that stopped refreshing. */
    async function heartbeat() {
        if (stopped) return;
        const at = now();
        try {
            await store.updatePresence(sessionId, (processes) => [
                ...processes.filter((entry) => entry.pid !== pid && at - Date.parse(entry.updatedAt) <= presenceTtlMs),
                { pid, version, updatedAt: iso(at) },
            ]);
            reports.presence.recovered();
        } catch (error) {
            reports.presence.failed(error);
        }
    }

    /** A claim is stale once its process has held it past the claim window. */
    const stale = (entry) => now() - Date.parse(entry.owner.at) > claimStaleMs;

    /** Remembers when a fresh claim goes stale, so the inbox is read then. Staleness starts one millisecond past the window. */
    function noteDeadline(entry) {
        const deadline = Date.parse(entry.owner.at) + claimStaleMs + 1;
        staleAt = staleAt === null ? deadline : Math.min(staleAt, deadline);
    }

    /**
     * Changes the entry with `id` under the lock when its current state passes `allowed`. A null
     * `patch` removes the entry; otherwise the patch replaces its fields. Resolves to whether it changed.
     *
     * @param {string} id
     * @param {(entry: any) => boolean} allowed
     * @param {{ state: string, owner: { pid: number, at: string } | null } | null} patch
     */
    async function move(id, allowed, patch) {
        const { result } = await store.updateInbox(sessionId, (entries) => {
            const index = entries.findIndex((entry) => entry.id === id);
            if (index < 0 || !allowed(entries[index])) {
                return { entries, result: false };
            }
            const next = patch === null
                ? entries.filter((_, at) => at !== index)
                : entries.map((entry, at) => (at === index ? { ...entry, ...patch } : entry));
            return { entries: next, result: true };
        });
        return result;
    }

    /** Returns an entry this process holds to the queue, when its send did not reach the chat. */
    const release = (id, owner, state) => move(id, ownedBy(owner, state), WAITING);

    /**
     * Records the items as sent with the chat's message ID and the route they took; a relay also
     * names this session as the chat that relayed them. Resolves to the IDs marked, or null when
     * recording keeps failing.
     */
    async function markSent(taskDoc, ids, messageId, route) {
        const how = route === 'relay' ? { route, relayedVia: sessionId } : { route };
        for (let attempt = 1; attempt <= MARK_ATTEMPTS; attempt += 1) {
            try {
                const { result } = await store.update(taskDoc, (doc) => markDelivered(doc, ids, 'send', iso(now()), { messageId, ...how }), { by: 'user' });
                return result;
            } catch (error) {
                log(`Sent, but could not record it (attempt ${attempt} of ${MARK_ATTEMPTS}): ${error instanceof Error ? error.message : 'error'}`, 'warning');
                if (attempt < MARK_ATTEMPTS) await pause(markRetryMs * attempt);
            }
        }
        return null;
    }

    /** Marks the items uncertain and removes the entry, or leaves the entry in `sending` for the stale check when marking fails. */
    async function markUncertain(entry, owner, ids) {
        try {
            await store.update(entry.taskDoc, (doc) => markDeliveryUncertain(doc, ids, iso(now()), { sessionId }), { by: 'agent' });
        } catch (error) {
            log(`Could not mark items uncertain: ${error instanceof Error ? error.message : 'error'}`, 'warning');
            return;
        }
        await move(entry.id, ownedBy(owner, 'sending'), null);
    }

    /**
     * Sends one composed message and records it. The entry is removed only after the send is
     * recorded. A send whose outcome is unknown marks its items uncertain instead of returning them.
     */
    async function sendMessage(entry, sending, message) {
        let sent;
        try {
            sent = await deliver({ prompt: message.prompt, displayPrompt: message.displayPrompt, ids: message.ids, mode: 'immediate' });
        } catch (error) {
            if (error instanceof ModelError && error.code === 'delivery_unavailable') {
                await release(entry.id, sending, 'sending');
                return;
            }
            await markUncertain(entry, sending, message.ids);
            log(`A message from RPI canvas ${entry.from.handle} may not have reached this session's chat. Check that chat; those items are not sent again.`, 'warning');
            return;
        }
        const messageId = typeof sent?.messageId === 'string' && sent.messageId ? sent.messageId : null;
        const recorded = await markSent(entry.taskDoc, message.ids, messageId, 'inbox');
        if (recorded === null) {
            log(`A message from RPI canvas ${entry.from.handle} was sent, but its items could not be recorded. They stay as sending and are not sent again.`, 'warning');
            return;
        }
        if (recorded.length > 0) {
            await pickups?.remember(messageId, [{ id: entry.taskDoc, ids: recorded }]).catch(() => {});
        }
        await move(entry.id, ownedBy(sending, 'sending'), null);
    }

    /**
     * Claims an entry that is waiting, or whose claim went stale, composes its message from the
     * items it still holds, and sends it. A retryable failure before the entry reaches `sending`
     * returns it to the queue; any other failure leaves the claim to go stale.
     */
    async function take(entry) {
        const claim = { pid, at: iso(now()) };
        const claimable = (current) => current.state === 'waiting' || (current.state === 'claimed' && stale(current));
        if (!(await move(entry.id, claimable, { state: 'claimed', owner: claim }))) return;
        let sending = null;
        try {
            const doc = await store.load(entry.taskDoc);
            const ids = doc ? heldItemIds(doc, entry.itemIds, entry.id) : [];
            if (ids.length === 0) {
                await move(entry.id, ownedBy(claim, 'claimed'), null);
                return;
            }
            const message = composeInboxDelivery(doc, ids, entry.from);
            const staging = { pid, at: iso(now()) };
            if (!(await move(entry.id, ownedBy(claim, 'claimed'), { state: 'sending', owner: staging }))) return;
            sending = staging;
            await sendMessage(entry, sending, message);
        } catch (error) {
            if (sending === null && retryable(error)) await release(entry.id, claim, 'claimed').catch(() => false);
            throw error;
        }
    }

    /**
     * An entry left in `sending` past the claim window: its items are marked uncertain and the
     * entry is removed. Nothing is sent, because the send may already have reached the chat.
     */
    async function settle(entry) {
        const doc = await store.load(entry.taskDoc);
        const ids = doc ? heldItemIds(doc, entry.itemIds, entry.id) : [];
        if (ids.length > 0) {
            await store.update(entry.taskDoc, (current) => markDeliveryUncertain(current, ids, iso(now()), { sessionId }), { by: 'agent' });
            log(`A message from RPI canvas ${entry.from.handle} was left unconfirmed. Check this session's chat; those items are not sent again.`, 'warning');
        }
        await move(entry.id, ownedBy(entry.owner, 'sending'), null);
    }

    /** Acts on one entry according to its state and age. */
    async function handleEntry(entry) {
        if (entry.state === 'sending') {
            if (stale(entry)) await settle(entry);
            else noteDeadline(entry);
            return;
        }
        if (entry.state === 'claimed' && !stale(entry)) {
            noteDeadline(entry);
            return;
        }
        if (canDeliver()) await take(entry);
    }

    /**
     * Reads the inbox when its stamp changed, a read was requested, or a claim went stale; otherwise
     * it returns after one stat.
     */
    async function scanInbox() {
        if (stopped) return;
        const seen = await store.inboxStamp(sessionId);
        if (seen === stamp && !dirty && (staleAt === null || now() < staleAt)) return;
        stamp = seen;
        dirty = false;
        staleAt = null;
        const { entries } = await store.loadInbox(sessionId);
        for (const entry of entries) {
            if (stopped) return;
            try {
                await handleEntry(entry);
            } catch (error) {
                if (!PERMANENT.has(error?.code)) throw error;
                reports.entries.failed(error);
            }
        }
    }

    /** Remembers when an outbox entry falls due, so the outbox is read then even if the file did not change. */
    function noteOutboxDue(at) {
        outboxDueAt = outboxDueAt === null ? at : Math.min(outboxDueAt, at);
    }

    /** Removes an outbox entry, or does nothing when it is already gone. */
    const forgetOutbox = (id) => store.updateOutbox(sessionId, (entries) => withoutEntry(entries, id));

    /** The target session's inbox entry with `id` as it stands now, or null when it is gone. */
    async function inboxEntryOf(target, id) {
        const { entries } = await store.loadInbox(target);
        return entries.find((entry) => entry.id === id) ?? null;
    }

    /**
     * How a relay may take its items, given the target's inbox entry as read. A missing entry lapses:
     * the items may have been sent by a relayer that went stale. A waiting entry, or a claim or send
     * gone stale, may be taken over. A fresh claim or send belongs to the target's process.
     */
    function relayPolicy(inboxEntry) {
        if (inboxEntry === null) return 'lapse';
        if (inboxEntry.state === 'waiting') return 'take';
        return stale(inboxEntry) ? 'take' : 'wait';
    }

    /** Clears the relay claim `claim` holds on `ids` in the entry's task document. */
    const releaseClaim = (entry, claim, ids) => store.update(entry.taskDoc, (doc) => releaseRelay(doc, ids, claim, iso(now())), { by: 'agent' });

    /**
     * Marks the items the entry still holds as uncertain and removes the entry. They may already be
     * in the chat of session `chat`, so nothing sends them again.
     */
    async function settleUncertain(entry, chat) {
        await store.update(entry.taskDoc, (doc) => markDeliveryUncertain(doc, handedItemIds(doc, entry.id), iso(now()), { sessionId: chat }), { by: 'agent' });
        await forgetOutbox(entry.id);
        log(`Items handed to another session may already be in ${chat === sessionId ? "this session's chat" : `the chat of session ${chat}`}. Check that chat; those items are not sent again.`, 'warning');
    }

    /**
     * Looks at the target's inbox entry under the target's lock. A waiting entry, or a claim gone
     * stale, is removed so that no process can claim it afterwards. A fresh claim or send is left to
     * its owner. A send gone stale is removed as unconfirmed. Resolves to what the relay does next.
     */
    async function withdraw(entry) {
        const { result } = await store.updateInbox(entry.target, (entries) => {
            const index = entries.findIndex((item) => item.id === entry.id);
            if (index < 0) return { entries, result: 'missing' };
            const current = entries[index];
            const removed = () => ({ entries: entries.filter((_, at) => at !== index), result: null });
            if (current.state === 'waiting' || (current.state === 'claimed' && stale(current))) return { ...removed(), result: 'withdrawn' };
            if (current.state === 'sending' && stale(current)) return { ...removed(), result: 'unconfirmed' };
            return { entries, result: 'owned' };
        });
        return result;
    }

    /**
     * Relays the items the claim still holds, once the target's entry is withdrawn or was never
     * claimed. The items go through this session's chat and are recorded as relayed. A send that
     * fails before the chat takes it releases the claim; a send whose outcome is unknown marks its
     * items uncertain.
     */
    async function relayItems(entry, claim, ids) {
        let held;
        let message;
        try {
            const outcome = await withdraw(entry);
            if (outcome === 'owned') {
                await releaseClaim(entry, claim, ids);
                outboxDirty = true;
                return;
            }
            if (outcome === 'unconfirmed') {
                await settleUncertain(entry, entry.target);
                return;
            }
            const doc = await store.load(entry.taskDoc);
            held = doc ? relayItemIds(doc, entry.id, claim) : [];
            if (held.length === 0) {
                await forgetOutbox(entry.id);
                return;
            }
            message = composeRelayDelivery(doc, held, { handle: entry.handle, sessionId: entry.target });
        } catch (error) {
            await releaseClaim(entry, claim, ids).catch(() => {});
            throw error;
        }
        let sent;
        try {
            sent = await deliver({ prompt: message.prompt, displayPrompt: message.displayPrompt, ids: message.ids, mode: 'immediate' });
        } catch (error) {
            if (error instanceof ModelError && error.code === 'delivery_unavailable') {
                await releaseClaim(entry, claim, held);
                outboxDirty = true;
                reports.relays.failed(error);
                return;
            }
            await settleUncertain(entry, sessionId);
            return;
        }
        const messageId = typeof sent?.messageId === 'string' && sent.messageId ? sent.messageId : null;
        const recorded = await markSent(entry.taskDoc, message.ids, messageId, 'relay');
        if (recorded === null) {
            noteOutboxDue(Date.parse(claim.at) + claimStaleMs + 1);
            log('Items relayed to another session were sent, but could not be recorded. They stay held until their relay claim goes stale; they are not sent again.', 'warning');
            return;
        }
        if (recorded.length > 0) {
            await pickups?.remember(messageId, [{ id: entry.taskDoc, ids: recorded }]).catch(() => {});
        }
        await forgetOutbox(entry.id);
    }

    /**
     * Acts on one due outbox entry. Its items are relayed only by the process that holds their relay
     * claim, and only once the target's inbox entry is withdrawn or was never there. A fresh claim
     * by another process, or an entry the target's process owns, is left for a later check.
     */
    async function relay(entry) {
        if (!canDeliver()) {
            outboxDirty = true;
            return;
        }
        if (!(await store.load(entry.taskDoc))) {
            await forgetOutbox(entry.id);
            return;
        }
        const claim = { pid, at: iso(now()) };
        const policy = relayPolicy(await inboxEntryOf(entry.target, entry.id));
        const { result } = await store.update(entry.taskDoc, (doc) => claimRelay(doc, entry.id, claim, iso(now()), { policy, staleMs: claimStaleMs }), { by: 'agent' });
        if (result.state === 'none') {
            await forgetOutbox(entry.id);
        } else if (result.state === 'busy') {
            if (result.staleAt) noteOutboxDue(Date.parse(result.staleAt));
            else outboxDirty = true;
        } else if (result.state === 'lapsed') {
            await settleUncertain(entry, sessionId);
        } else {
            await relayItems(entry, claim, result.ids);
        }
    }

    /**
     * Reads the outbox when its stamp changed, a retry or a wake was asked, or an entry fell due;
     * otherwise it returns after one stat. An entry that is not due yet sets the time it falls due.
     */
    async function scanOutbox() {
        if (stopped) return;
        const seen = await store.outboxStamp(sessionId);
        if (seen === outboxSeen && !outboxDirty && (outboxDueAt === null || now() < outboxDueAt)) return;
        outboxSeen = seen;
        outboxDirty = false;
        outboxDueAt = null;
        const { entries } = await store.loadOutbox(sessionId);
        for (const entry of entries) {
            if (stopped) return;
            const due = Date.parse(entry.relayAfter);
            if (now() < due) {
                noteOutboxDue(due);
                continue;
            }
            try {
                await relay(entry);
            } catch (error) {
                // The relay claim is released or goes stale, so the entry is safe to retry at the next check.
                outboxDirty = true;
                reports.relays.failed(error);
            }
        }
    }

    /** Runs one outbox check. A call made while a check runs shares it; a wake made meanwhile runs one more check. */
    function checkOutbox() {
        if (outboxChecking === null) {
            outboxChecking = (async () => {
                do {
                    outboxAgain = false;
                    try {
                        await scanOutbox();
                        reports.outbox.recovered();
                    } catch (error) {
                        outboxDirty = !PERMANENT.has(error?.code);
                        reports.outbox.failed(error);
                    }
                } while (outboxAgain && !stopped);
            })().finally(() => {
                outboxChecking = null;
            });
        }
        return outboxChecking;
    }

    /** Asks for an outbox check now, reading the outbox even when its file did not change. */
    function wakeOutbox() {
        outboxDirty = true;
        if (outboxChecking !== null) outboxAgain = true;
        return checkOutbox();
    }

    /** Runs one inbox check. A call made while a check runs shares it, so a slow send never runs twice. */
    function checkInbox() {
        if (checking === null) {
            checking = scanInbox()
                .then(() => reports.inbox.recovered(), (error) => {
                    dirty = !PERMANENT.has(error?.code);
                    reports.inbox.failed(error);
                })
                .finally(() => {
                    checking = null;
                });
        }
        return checking;
    }

    /** Runs the inbox check and the outbox check. The timer runs both. */
    function poll() {
        return Promise.all([checkInbox(), checkOutbox()]).then(() => undefined);
    }

    /** Starts the presence heartbeat and the inbox and outbox checks as unref'd timers, and runs each once now. */
    function start() {
        if (started || stopped) return Promise.resolve();
        started = true;
        beatTimer = schedule(() => heartbeat(), beatMs);
        checkTimer = schedule(() => poll(), checkMs);
        beatTimer?.unref?.();
        checkTimer?.unref?.();
        return Promise.all([heartbeat(), poll()]).then(() => undefined);
    }

    /** Ends both timers and removes this process from the session's presence. Calling it again does nothing. */
    async function stop() {
        if (stopped) return;
        stopped = true;
        if (beatTimer !== null) unschedule(beatTimer);
        if (checkTimer !== null) unschedule(checkTimer);
        beatTimer = null;
        checkTimer = null;
        await store.updatePresence(sessionId, (processes) => processes.filter((entry) => entry.pid !== pid)).catch(() => {});
    }

    return { start, stop, heartbeat, checkInbox, checkOutbox, wakeOutbox };
}
