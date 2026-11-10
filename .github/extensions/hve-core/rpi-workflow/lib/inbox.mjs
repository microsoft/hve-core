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
 */

import { CLAIM_STALE_MS, composeInboxDelivery, heldItemIds, markDelivered, markDeliveryUncertain, ModelError } from './model.mjs';

/** Version of the presence and inbox protocol. A process reports it; only processes that speak it take entries. */
export const INBOX_VERSION = 1;
/** How often a process refreshes its presence entry. */
export const PRESENCE_BEAT_MS = 30 * 1000;
/** A presence entry that has not been refreshed for this long is dropped. */
export const PRESENCE_TTL_MS = 2 * 60 * 1000;
/** How often a process checks its inbox file for changes. */
export const INBOX_CHECK_MS = 2 * 1000;

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
 * Creates the inbox runner for one Copilot session. `start` begins the presence heartbeat and the
 * inbox check as unref'd timers; `stop` ends them and removes the process from the session's
 * presence. The store, the send function, the process ID, the clocks and timers, and the claim
 * window are all injectable.
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

    /** Records the items as sent with the chat's message ID. Resolves to the IDs marked, or null when recording keeps failing. */
    async function markSent(taskDoc, ids, messageId) {
        for (let attempt = 1; attempt <= MARK_ATTEMPTS; attempt += 1) {
            try {
                const { result } = await store.update(taskDoc, (doc) => markDelivered(doc, ids, 'send', iso(now()), { messageId }), { by: 'user' });
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
            await store.update(entry.taskDoc, (doc) => markDeliveryUncertain(doc, ids, iso(now())), { by: 'agent' });
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
        const recorded = await markSent(entry.taskDoc, message.ids, messageId);
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
            await store.update(entry.taskDoc, (current) => markDeliveryUncertain(current, ids, iso(now())), { by: 'agent' });
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

    /** Runs one inbox check. A call made while a check runs shares it, so a slow send never runs twice. */
    function poll() {
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

    /** Starts the presence heartbeat and the inbox check as unref'd timers, and runs each once now. */
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

    return { start, stop, heartbeat, checkInbox: poll };
}
