// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { EventEmitter } from 'node:events';
import { randomBytes } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { ModelError, upgradeSession, validateSession } from './model.mjs';

export const CANVAS_ID = 'hve-core-rpi-workflow';
export const PREFERENCES_FORMAT = 'hve-core-rpi-workflow.preferences';
export const PREFERENCES_VERSION = 1;
export const INSTANCES_FORMAT = 'hve-core-rpi-workflow.instances';
/** Version 2 keys each instance by the conversation that shows it. */
export const INSTANCES_VERSION = 2;
/** The instance memory keeps this many of the most recently updated instances. */
export const MAX_INSTANCES = 50;
const HOST_SESSION_RE = /^[A-Za-z0-9._-]{1,128}$/;
export const DEFAULT_PREFERENCES = Object.freeze({ theme: 'system', contrast: 'standard' });
const THEMES = new Set(['system', 'light', 'dark']);
const CONTRASTS = new Set(['standard', 'more']);
const SESSION_ID_RE = /^[a-z0-9][a-z0-9-]{0,79}$/;
const COPILOT_SESSION_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REFERENCE_RE = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$/;
const HANDLE_RE = /^[0-9A-Za-z][0-9A-Za-z-]{0,23}$/;
/** Most items one inbox entry names, the same limit a send takes. */
export const INBOX_MAX_ITEMS = 50;
/** The states an inbox entry moves through, in order: waiting, claimed by one process, then sending. */
export const INBOX_STATES = Object.freeze(['waiting', 'claimed', 'sending']);

/**
 * Resolves the Copilot home every host shares: a non-empty `COPILOT_HOME`, otherwise
 * `~/.copilot`.
 *
 * @param {NodeJS.ProcessEnv} [env]
 * @param {string} [homedir]
 */
export function resolveCopilotHome(env = process.env, homedir = os.homedir()) {
    const value = env.COPILOT_HOME;
    return typeof value === 'string' && value.length > 0 ? value : path.join(homedir, '.copilot');
}

/**
 * The memory key of an instance: its conversation and instance ID, or the instance ID alone
 * when the conversation is unknown or its ID is not usable in a key.
 *
 * @param {string} instanceId
 * @param {unknown} hostSessionId the Copilot session (conversation) that shows the instance
 */
function instanceKey(instanceId, hostSessionId) {
    return typeof hostSessionId === 'string' && HOST_SESSION_RE.test(hostSessionId) ? `${hostSessionId}/${instanceId}` : instanceId;
}

/** Private data folder for this canvas, outside any repository. */
export function dataRoot(copilotHome = resolveCopilotHome()) {
    return path.join(copilotHome, 'extension-data', CANVAS_ID);
}

/** Store error carrying a stable code. */
export class StoreError extends ModelError {}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const WRITE_ATTEMPTS = 3;

/**
 * Validates stored preferences, returning defaults for missing values.
 *
 * @param {unknown} doc
 */
export function validatePreferences(doc) {
    if (!doc || typeof doc !== 'object' || Array.isArray(doc) || doc.format !== PREFERENCES_FORMAT) {
        throw new StoreError('storage_corrupt', 'Preferences have an unrecognized format.');
    }
    if (doc.version !== PREFERENCES_VERSION) {
        throw new StoreError('storage_unsupported', `Preferences version ${String(doc.version)} is not supported.`);
    }
    return {
        theme: THEMES.has(doc.theme) ? doc.theme : DEFAULT_PREFERENCES.theme,
        contrast: CONTRASTS.has(doc.contrast) ? doc.contrast : DEFAULT_PREFERENCES.contrast,
    };
}

/**
 * Checks a preferences patch from the page or an action.
 *
 * @param {unknown} patch
 */
export function preferencesPatch(patch) {
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) {
        throw new StoreError('invalid_input', 'Preferences must be an object.');
    }
    const result = {};
    for (const key of Object.keys(patch)) {
        if (key === 'theme') {
            if (!THEMES.has(patch.theme)) throw new StoreError('invalid_input', 'theme must be system, light, or dark.');
            result.theme = patch.theme;
        } else if (key === 'contrast') {
            if (!CONTRASTS.has(patch.contrast)) throw new StoreError('invalid_input', 'contrast must be standard or more.');
            result.contrast = patch.contrast;
        } else {
            throw new StoreError('invalid_input', `Unknown preference: ${key}`);
        }
    }
    return result;
}

const isRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const isInstant = (value) => typeof value === 'string' && Number.isFinite(Date.parse(value));
const isProcessId = (value) => Number.isInteger(value) && value > 0;
/** Whether a record has no keys beyond the given ones, so a file cannot carry fields the contract does not name. */
const onlyKeys = (value, keys) => Object.keys(value).every((key) => keys.has(key));
const PROCESS_KEYS = new Set(['pid', 'version', 'updatedAt']);
const ENTRY_KEYS = new Set(['id', 'taskDoc', 'itemIds', 'from', 'createdAt', 'state', 'owner']);
const OUTBOX_ENTRY_KEYS = new Set(['id', 'taskDoc', 'target', 'handle', 'relayAfter', 'createdAt']);
const FROM_KEYS = new Set(['sessionId', 'handle']);
const OWNER_KEYS = new Set(['pid', 'at']);

/**
 * Normalizes a Copilot session ID to the lowercase form that names its presence and inbox files.
 *
 * @param {unknown} value
 * @returns {string}
 */
function copilotSessionId(value) {
    if (typeof value !== 'string' || !COPILOT_SESSION_RE.test(value)) {
        throw new StoreError('invalid_input', 'Copilot session IDs are UUIDs.');
    }
    return value.toLowerCase();
}

/** Owner of a claimed or sending inbox entry: the process that took it and when. */
const isOwner = (value) => isRecord(value) && onlyKeys(value, OWNER_KEYS) && isProcessId(value.pid) && isInstant(value.at);

/** A presence entry: a process that announced itself for a session, with its protocol version and refresh time. */
const isProcess = (value) => isRecord(value) && onlyKeys(value, PROCESS_KEYS) && isProcessId(value.pid) && Number.isInteger(value.version) && value.version > 0 && isInstant(value.updatedAt);

/** An inbox entry names items in a task document by reference; it never carries their text. */
function isInboxEntry(value) {
    return isRecord(value)
        && onlyKeys(value, ENTRY_KEYS)
        && typeof value.id === 'string' && REFERENCE_RE.test(value.id)
        && typeof value.taskDoc === 'string' && SESSION_ID_RE.test(value.taskDoc)
        && Array.isArray(value.itemIds) && value.itemIds.length >= 1 && value.itemIds.length <= INBOX_MAX_ITEMS
        && value.itemIds.every((id) => typeof id === 'string' && REFERENCE_RE.test(id))
        && new Set(value.itemIds).size === value.itemIds.length
        && isRecord(value.from) && onlyKeys(value.from, FROM_KEYS)
        && typeof value.from.sessionId === 'string' && COPILOT_SESSION_RE.test(value.from.sessionId)
        && typeof value.from.handle === 'string' && HANDLE_RE.test(value.from.handle)
        && isInstant(value.createdAt)
        && INBOX_STATES.includes(value.state)
        && (value.state === 'waiting' ? value.owner === undefined || value.owner === null || isOwner(value.owner) : isOwner(value.owner));
}

/** An outbox entry records a handoff this session's canvas made to another session: the task document, the target, and when the items may be relayed. It carries no text. */
function isOutboxEntry(value) {
    return isRecord(value)
        && onlyKeys(value, OUTBOX_ENTRY_KEYS)
        && typeof value.id === 'string' && REFERENCE_RE.test(value.id)
        && typeof value.taskDoc === 'string' && SESSION_ID_RE.test(value.taskDoc)
        && typeof value.target === 'string' && COPILOT_SESSION_RE.test(value.target)
        && typeof value.handle === 'string' && HANDLE_RE.test(value.handle)
        && isInstant(value.relayAfter)
        && isInstant(value.createdAt);
}

/** The presence entries of a session, or none when its file is missing. */
function presenceOf(sessionId, doc) {
    if (doc === undefined) return { sessionId, processes: [] };
    if (!isRecord(doc) || doc.sessionId !== sessionId || !Array.isArray(doc.processes) || !doc.processes.every(isProcess)) {
        throw new StoreError('storage_corrupt', `Presence for ${sessionId} has an unrecognized shape.`);
    }
    return { sessionId, processes: doc.processes };
}

/** The entries of a session's inbox or outbox file, or none when the file is missing. Entry IDs are unique within a file. */
function entriesOf(file, doc, isEntry) {
    const name = path.basename(file);
    if (doc === undefined) return { entries: [] };
    if (!isRecord(doc) || !Array.isArray(doc.entries) || !doc.entries.every(isEntry)) {
        throw new StoreError('storage_corrupt', `${name} has an unrecognized shape.`);
    }
    if (new Set(doc.entries.map((entry) => entry.id)).size !== doc.entries.length) {
        throw new StoreError('storage_corrupt', `${name} has entries with the same ID.`);
    }
    return { entries: doc.entries };
}

/** The inbox entries of a session, or none when its file is missing. */
function inboxOf(file, doc) {
    return entriesOf(file, doc, isInboxEntry);
}

/** The outbox entries of a session, or none when its file is missing. */
function outboxOf(file, doc) {
    return entriesOf(file, doc, isOutboxEntry);
}

/**
 * Durable store for sessions, preferences, presence, inboxes, and outboxes. Writes are atomic (temporary
 * file, then rename), read-modify-write runs under an exclusive lock file so several processes can
 * share a session without lost updates, and changes from other processes are detected by
 * polling file size and time while anyone is subscribed. Each lock hold carries its own
 * token: only the holder releases it, a stale takeover removes only the lock it judged
 * stale, and a session write commits only while the hold still owns the lock and the
 * stored revision is still the one it read.
 *
 * @param {{ root?: string, lockStaleMs?: number, lockWaitMs?: number, pollMs?: number, log?: (message: string) => void }} [options]
 */
export function createStore(options = {}) {
    const root = options.root ?? dataRoot();
    const lockStaleMs = options.lockStaleMs ?? 10000;
    const lockWaitMs = options.lockWaitMs ?? 3000;
    const pollMs = options.pollMs ?? 2000;
    const log = options.log ?? (() => {});
    const events = new EventEmitter();
    events.setMaxListeners(50);
    /** @type {Map<string, Promise<unknown>>} */
    const chains = new Map();
    /** @type {Map<string, { timer: NodeJS.Timeout, size: number, mtimeMs: number, revision: number, count: number }>} */
    const watchers = new Map();

    const sessionsDir = path.join(root, 'sessions');
    const preferencesFile = path.join(root, 'preferences.json');
    const instancesFile = path.join(root, 'instances.json');
    const presenceDir = path.join(root, 'presence');
    const inboxDir = path.join(root, 'inbox');
    const outboxDir = path.join(root, 'outbox');

    function presenceFile(id) {
        return path.join(presenceDir, `${copilotSessionId(id)}.json`);
    }

    function inboxFile(id) {
        return path.join(inboxDir, `${copilotSessionId(id)}.json`);
    }

    function outboxFile(id) {
        return path.join(outboxDir, `${copilotSessionId(id)}.json`);
    }

    function sessionFile(id) {
        if (typeof id !== 'string' || !SESSION_ID_RE.test(id)) {
            throw new StoreError('invalid_input', 'Session IDs use lowercase letters, digits, and dashes.');
        }
        return path.join(sessionsDir, `${id}.json`);
    }

    /** The instance entries of a parsed memory file, or none when it is missing, foreign, or another version. */
    function instancesOf(doc) {
        const instances = doc?.format === INSTANCES_FORMAT && doc.version === INSTANCES_VERSION ? doc.instances : null;
        return instances && typeof instances === 'object' && !Array.isArray(instances) ? instances : {};
    }

    async function writeAtomic(file, value) {
        await fs.mkdir(path.dirname(file), { recursive: true });
        const temp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.${randomBytes(6).toString('hex')}.tmp`);
        try {
            await fs.writeFile(temp, `${JSON.stringify(value, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
            await fs.rename(temp, file);
        } catch (error) {
            await fs.rm(temp, { force: true }).catch(() => {});
            throw new StoreError('storage_failed', `Could not write ${path.basename(file)}: ${error instanceof Error ? error.message : 'error'}`);
        }
    }

    async function readJson(file) {
        let raw;
        try {
            raw = await fs.readFile(file, 'utf8');
        } catch (error) {
            if (error && error.code === 'ENOENT') {
                return undefined;
            }
            throw new StoreError('storage_failed', `Could not read ${path.basename(file)}.`);
        }
        try {
            return JSON.parse(raw);
        } catch {
            throw new StoreError('storage_corrupt', `${file} is not valid JSON; it was left in place.`);
        }
    }

    async function readSession(file) {
        const doc = await readJson(file);
        if (doc === undefined) {
            return undefined;
        }
        try {
            return validateSession(upgradeSession(doc));
        } catch (error) {
            const code = error instanceof ModelError ? error.code : 'storage_corrupt';
            throw new StoreError(code, `${file}: ${error instanceof Error ? error.message : 'invalid data'} It was left in place.`);
        }
    }

    // Reads a lock's content and time through one handle so both describe the same file.
    async function inspectLock(lock) {
        let handle;
        try {
            handle = await fs.open(lock, 'r');
        } catch (error) {
            if (error && error.code === 'ENOENT') {
                return null;
            }
            throw error;
        }
        try {
            const stat = await handle.stat();
            return { content: await handle.readFile('utf8'), mtimeMs: stat.mtimeMs };
        } finally {
            await handle.close();
        }
    }

    // Moves the lock aside and deletes it only when it still holds the expected content, so
    // a takeover or release never deletes a lock another process just created. Anything else
    // is put back unless a newer lock has already taken its place.
    async function removeLockIf(lock, expected) {
        const aside = `${lock}.${randomBytes(6).toString('hex')}.aside`;
        try {
            await fs.rename(lock, aside);
        } catch (error) {
            if (error && error.code === 'ENOENT') {
                return false;
            }
            throw error;
        }
        const content = await fs.readFile(aside, 'utf8').catch(() => null);
        if (content === expected) {
            await fs.rm(aside, { force: true });
            return true;
        }
        await fs.link(aside, lock).catch(() => {});
        await fs.rm(aside, { force: true }).catch(() => {});
        return false;
    }

    /**
     * Runs `run` while holding the file's exclusive lock. The lock content is unique to this
     * hold, and `run` receives `stillHeld`, which reports whether the lock is still this hold's.
     *
     * @template T
     * @param {string} file
     * @param {(stillHeld: () => Promise<boolean>) => Promise<T>} run
     * @returns {Promise<T>}
     */
    async function withLock(file, run) {
        await fs.mkdir(path.dirname(file), { recursive: true });
        const lock = `${file}.lock`;
        const mine = `${process.pid} ${randomBytes(12).toString('hex')} ${new Date().toISOString()}\n`;
        const deadline = Date.now() + lockWaitMs;
        for (;;) {
            let handle;
            try {
                handle = await fs.open(lock, 'wx');
            } catch (error) {
                if (!error || error.code !== 'EEXIST') {
                    throw new StoreError('storage_failed', `Could not lock ${path.basename(file)}.`);
                }
                const seen = await inspectLock(lock).catch(() => null);
                if (seen && Date.now() - seen.mtimeMs > lockStaleMs && (await removeLockIf(lock, seen.content).catch(() => false))) {
                    log(`Removed stale lock ${path.basename(lock)}`);
                    continue;
                }
                if (Date.now() > deadline) {
                    throw new StoreError('storage_busy', `${path.basename(file)} is locked by another process. Try again.`);
                }
                await sleep(25);
                continue;
            }
            try {
                await handle.writeFile(mine);
                await handle.close();
            } catch {
                await handle.close().catch(() => {});
                await fs.rm(lock, { force: true }).catch(() => {});
                throw new StoreError('storage_failed', `Could not lock ${path.basename(file)}.`);
            }
            break;
        }
        const stillHeld = async () => (await inspectLock(lock).catch(() => null))?.content === mine;
        try {
            return await run(stillHeld);
        } finally {
            if (!(await removeLockIf(lock, mine).catch(() => false))) {
                log(`${path.basename(lock)} changed hands while held; it was left as found.`);
            }
        }
    }

    // True when this hold still owns the lock and nobody has written the file since it read
    // `revision` (null when the file was missing or unreadable).
    async function unchangedSince(file, revision, stillHeld) {
        if (!(await stillHeld())) {
            return false;
        }
        const doc = await readJson(file).catch(() => undefined);
        return (doc?.revision ?? null) === revision;
    }

    /**
     * Runs read-change-write attempts under the lock. An attempt returns `{ retry: true }`
     * when the lock changed hands or another writer committed after its read, and the write
     * then starts over on a fresh read, up to WRITE_ATTEMPTS times.
     *
     * @template T
     * @param {string} file
     * @param {(stillHeld: () => Promise<boolean>) => Promise<{ retry: true } | { retry?: false, value: T }>} attempt
     * @returns {Promise<T>}
     */
    async function lockedWrite(file, attempt) {
        for (let tries = 1; tries <= WRITE_ATTEMPTS; tries += 1) {
            const outcome = await withLock(file, attempt);
            if (!outcome.retry) {
                return outcome.value;
            }
            log(`${path.basename(file)} changed during a write (try ${tries} of ${WRITE_ATTEMPTS}); starting over on a fresh read.`);
        }
        throw new StoreError('storage_busy', `${path.basename(file)} kept changing while it was being saved. Try again.`);
    }

    async function keepBackup(file, id) {
        const raw = await fs.readFile(file, 'utf8').catch(() => null);
        if (raw === null) {
            return;
        }
        const backup = path.join(sessionsDir, `${id}.previous.json`);
        const temp = path.join(sessionsDir, `.${id}.previous.json.${randomBytes(6).toString('hex')}.tmp`);
        try {
            await fs.writeFile(temp, raw, { encoding: 'utf8', mode: 0o600 });
            await fs.rename(temp, backup);
        } catch (error) {
            await fs.rm(temp, { force: true }).catch(() => {});
            throw new StoreError('storage_failed', `Could not back up ${id} before replacing it: ${error instanceof Error ? error.message : 'error'}`);
        }
    }

    function serialized(key, run) {
        const previous = chains.get(key) ?? Promise.resolve();
        const next = previous.then(run, run);
        const settled = next.catch(() => {});
        chains.set(key, settled);
        settled.then(() => {
            if (chains.get(key) === settled) {
                chains.delete(key);
            }
        });
        return next;
    }

    function publish(id, session) {
        const watcher = watchers.get(id);
        if (watcher) {
            watcher.revision = session.revision;
        }
        events.emit('change', id, session);
    }

    async function statOf(file) {
        const stat = await fs.stat(file).catch(() => null);
        return stat ? { size: stat.size, mtimeMs: stat.mtimeMs } : { size: -1, mtimeMs: -1 };
    }

    /** A token that changes whenever the file is replaced, or `missing` when there is no file. */
    async function stampOf(file) {
        const stat = await fs.stat(file).catch((error) => {
            if (error && error.code === 'ENOENT') return null;
            throw error;
        });
        return stat ? `${stat.ino}:${stat.size}:${stat.mtimeMs}` : 'missing';
    }

    return {
        root,
        events,

        /** @param {string} id */
        async load(id) {
            return readSession(sessionFile(id));
        },

        /**
         * Writes a new session. Refuses to replace a session the person changed unless
         * `replace` is set. Replacing a session that holds the person's changes, or one that
         * cannot be read, first copies it to `<id>.previous.json`; that copy stays until the
         * next such replace.
         *
         * @param {any} session
         * @param {{ replace?: boolean }} [opts]
         */
        async create(session, opts = {}) {
            const file = sessionFile(session.id);
            validateSession(session);
            return serialized(file, () => lockedWrite(file, async (stillHeld) => {
                let existing;
                let unreadable = false;
                try {
                    existing = await readSession(file);
                } catch (error) {
                    if (!opts.replace) {
                        throw error;
                    }
                    unreadable = true;
                }
                const hasUserChanges = (existing?.scenario?.userChanges ?? 0) > 0;
                if (hasUserChanges && !opts.replace) {
                    throw new StoreError('scenario_exists', `Session ${session.id} has changes you made; pass replace: true to start over.`);
                }
                if (!(await unchangedSince(file, existing?.revision ?? null, stillHeld))) {
                    return { retry: true };
                }
                if (hasUserChanges || unreadable) {
                    await keepBackup(file, session.id);
                }
                const next = { ...session, revision: Math.max(session.revision, (existing?.revision ?? 0) + 1) };
                await writeAtomic(file, next);
                publish(session.id, next);
                return { value: next };
            }));
        },

        /**
         * Applies a pure mutation to the freshest stored session under the lock. The mutation
         * can run more than once: when another writer commits first, it is reapplied to a
         * fresh read.
         *
         * @template T
         * @param {string} id
         * @param {(session: any) => { session: any, result: T }} change
         * @param {{ by?: 'user' | 'agent' }} [opts]
         * @returns {Promise<{ session: any, result: T, changed: boolean }>}
         */
        async update(id, change, opts = {}) {
            const file = sessionFile(id);
            return serialized(file, () => lockedWrite(file, async (stillHeld) => {
                const current = await readSession(file);
                if (!current) {
                    throw new StoreError('not_found', `No session ${id} is stored. Load a scenario first.`);
                }
                const { session: next, result } = change(current);
                if (next === current) {
                    return { value: { session: current, result, changed: false } };
                }
                if (opts.by === 'user') {
                    next.scenario = { ...(next.scenario ?? {}), userChanges: (current.scenario?.userChanges ?? 0) + 1 };
                }
                validateSession(next);
                if (!(await unchangedSince(file, current.revision, stillHeld))) {
                    return { retry: true };
                }
                await writeAtomic(file, next);
                publish(id, next);
                return { value: { session: next, result, changed: true } };
            }));
        },

        /**
         * Reads a session's presence: the canvas processes that announced themselves for it. A
         * missing file reads as none. Reads take the same lock as writes.
         *
         * @param {string} sessionId a Copilot session ID
         * @returns {Promise<{ sessionId: string, processes: { pid: number, version: number, updatedAt: string }[] }>}
         */
        async loadPresence(sessionId) {
            const id = copilotSessionId(sessionId);
            const file = presenceFile(id);
            return withLock(file, async () => presenceOf(id, await readJson(file)));
        },

        /**
         * Changes a session's presence under the lock. `change` receives the current process
         * entries and returns the next list. Presence only says which processes are live, so a
         * presence file that cannot be read is replaced rather than left in place.
         *
         * @param {string} sessionId a Copilot session ID
         * @param {(processes: any[]) => any[]} change
         * @returns {Promise<{ sessionId: string, processes: { pid: number, version: number, updatedAt: string }[] }>} the stored presence
         */
        async updatePresence(sessionId, change) {
            const id = copilotSessionId(sessionId);
            const file = presenceFile(id);
            return serialized(file, () => lockedWrite(file, async (stillHeld) => {
                const current = await readJson(file).then((doc) => presenceOf(id, doc)).catch((error) => {
                    if (error instanceof StoreError && error.code === 'storage_corrupt') {
                        return { sessionId: id, processes: [] };
                    }
                    throw error;
                });
                const next = presenceOf(id, { sessionId: id, processes: change(current.processes) });
                if (!(await stillHeld())) {
                    return { retry: true };
                }
                await writeAtomic(file, next);
                return { value: next };
            }));
        },

        /**
         * Reads a session's inbox entries under the lock. A missing file reads as none; a file that
         * is not valid throws `storage_corrupt` and is left in place.
         *
         * @param {string} sessionId a Copilot session ID
         * @returns {Promise<{ entries: any[] }>}
         */
        async loadInbox(sessionId) {
            const file = inboxFile(sessionId);
            return withLock(file, async () => inboxOf(file, await readJson(file)));
        },

        /**
         * Changes a session's inbox entries under the lock, as one read-change-write. `change`
         * receives the current entries and returns `{ entries, result }`; returning the same array
         * writes nothing. Resolves to the `result` and whether the file was written.
         *
         * @template T
         * @param {string} sessionId a Copilot session ID
         * @param {(entries: any[]) => { entries: any[], result: T }} change
         * @returns {Promise<{ result: T, changed: boolean }>}
         */
        async updateInbox(sessionId, change) {
            const file = inboxFile(sessionId);
            return serialized(file, () => lockedWrite(file, async (stillHeld) => {
                const current = inboxOf(file, await readJson(file));
                const { entries, result } = change(current.entries);
                if (entries === current.entries) {
                    return { value: { result, changed: false } };
                }
                const next = inboxOf(file, { entries }).entries;
                if (!(await stillHeld())) {
                    return { retry: true };
                }
                await writeAtomic(file, { entries: next });
                return { value: { result, changed: true } };
            }));
        },

        /**
         * A token for the state of a session's inbox file. It changes whenever the file is replaced,
         * and reads `missing` when there is no file. Takes no lock, so a check costs one stat.
         *
         * @param {string} sessionId a Copilot session ID
         * @returns {Promise<string>}
         */
        async inboxStamp(sessionId) {
            return stampOf(inboxFile(sessionId));
        },

        /**
         * Reads a session's outbox entries under the lock: the handoffs its canvases made to other
         * sessions and have not settled. A missing file reads as none; a file that is not valid throws
         * `storage_corrupt` and is left in place.
         *
         * @param {string} sessionId a Copilot session ID
         * @returns {Promise<{ entries: any[] }>}
         */
        async loadOutbox(sessionId) {
            const file = outboxFile(sessionId);
            return withLock(file, async () => outboxOf(file, await readJson(file)));
        },

        /**
         * Changes a session's outbox entries under the lock, as one read-change-write. `change`
         * receives the current entries and returns `{ entries, result }`; returning the same array
         * writes nothing. Resolves to the `result` and whether the file was written.
         *
         * @template T
         * @param {string} sessionId a Copilot session ID
         * @param {(entries: any[]) => { entries: any[], result: T }} change
         * @returns {Promise<{ result: T, changed: boolean }>}
         */
        async updateOutbox(sessionId, change) {
            const file = outboxFile(sessionId);
            return serialized(file, () => lockedWrite(file, async (stillHeld) => {
                const current = outboxOf(file, await readJson(file));
                const { entries, result } = change(current.entries);
                if (entries === current.entries) {
                    return { value: { result, changed: false } };
                }
                const next = outboxOf(file, { entries }).entries;
                if (!(await stillHeld())) {
                    return { retry: true };
                }
                await writeAtomic(file, { entries: next });
                return { value: { result, changed: true } };
            }));
        },

        /**
         * A token for the state of a session's outbox file, as `inboxStamp` gives for the inbox. Takes no lock.
         *
         * @param {string} sessionId a Copilot session ID
         * @returns {Promise<string>}
         */
        async outboxStamp(sessionId) {
            return stampOf(outboxFile(sessionId));
        },

        async loadPreferences() {
            const doc = await readJson(preferencesFile);
            return doc === undefined ? { ...DEFAULT_PREFERENCES } : validatePreferences(doc);
        },

        /** @param {Partial<typeof DEFAULT_PREFERENCES>} patch */
        async savePreferences(patch) {
            const clean = preferencesPatch(patch);
            return serialized(preferencesFile, () => withLock(preferencesFile, async () => {
                const doc = await readJson(preferencesFile);
                const current = doc === undefined ? { ...DEFAULT_PREFERENCES } : validatePreferences(doc);
                const next = { ...current, ...clean };
                await writeAtomic(preferencesFile, { format: PREFERENCES_FORMAT, version: PREFERENCES_VERSION, ...next });
                events.emit('preferences', next);
                return next;
            }));
        },

        /**
         * What a canvas instance showed last in a conversation, or null: `{ kind: 'rpi', state,
         * paused }` or `{ kind: 'sample' }`. A missing or unreadable memory reads as nothing
         * remembered.
         *
         * @param {string} instanceId
         * @param {string} [hostSessionId] the Copilot session (conversation) that shows the instance
         */
        async loadInstance(instanceId, hostSessionId) {
            const doc = await readJson(instancesFile).catch(() => undefined);
            const entry = instancesOf(doc)[instanceKey(instanceId, hostSessionId)];
            return entry && typeof entry === 'object' && !Array.isArray(entry) ? entry : null;
        },

        /**
         * Remembers what a canvas instance shows in a conversation, so the instance returns
         * there when the host reopens it. Keeps the most recently updated instances.
         *
         * @param {string} instanceId
         * @param {{ kind: 'rpi', state: string, paused: boolean } | { kind: 'sample' }} shown
         * @param {{ hostSessionId?: string }} [options]
         */
        async rememberInstance(instanceId, shown, options = {}) {
            if (typeof instanceId !== 'string' || !instanceId) return;
            const key = instanceKey(instanceId, options.hostSessionId);
            await serialized(instancesFile, () => withLock(instancesFile, async () => {
                const instances = { ...instancesOf(await readJson(instancesFile).catch(() => undefined)), [key]: { ...shown, updatedAt: new Date().toISOString() } };
                // Newest first; within one millisecond, the later write wins.
                const kept = Object.entries(instances)
                    .map((entry, index) => ({ entry, index, at: String(entry[1]?.updatedAt ?? ''), latest: entry[0] === key }))
                    .sort((a, b) => Number(b.latest) - Number(a.latest) || b.at.localeCompare(a.at) || b.index - a.index)
                    .slice(0, MAX_INSTANCES)
                    .map((item) => item.entry);
                await writeAtomic(instancesFile, { format: INSTANCES_FORMAT, version: INSTANCES_VERSION, instances: Object.fromEntries(kept) });
            }));
        },

        /**
         * Watches a session for changes made by other processes while at least one
         * subscriber is active. Returns an unsubscribe function.
         *
         * @param {string} id
         */
        watch(id) {
            const file = sessionFile(id);
            let watcher = watchers.get(id);
            if (!watcher) {
                watcher = { timer: /** @type {any} */ (null), size: -1, mtimeMs: -1, revision: -1, count: 0 };
                watchers.set(id, watcher);
                const tick = async () => {
                    const stat = await statOf(file);
                    if (stat.size === watcher.size && stat.mtimeMs === watcher.mtimeMs) {
                        return;
                    }
                    const first = watcher.size === -1 && watcher.mtimeMs === -1;
                    watcher.size = stat.size;
                    watcher.mtimeMs = stat.mtimeMs;
                    if (first || stat.size < 0) {
                        return;
                    }
                    const session = await readSession(file).catch(() => undefined);
                    if (session && session.revision !== watcher.revision) {
                        watcher.revision = session.revision;
                        events.emit('change', id, session);
                    }
                };
                tick().catch(() => {});
                watcher.timer = setInterval(() => tick().catch(() => {}), pollMs);
                watcher.timer.unref?.();
            }
            watcher.count += 1;
            let active = true;
            return () => {
                if (!active) {
                    return;
                }
                active = false;
                watcher.count -= 1;
                if (watcher.count <= 0) {
                    clearInterval(watcher.timer);
                    watchers.delete(id);
                }
            };
        },

        /** Stops every watcher. */
        close() {
            for (const watcher of watchers.values()) {
                clearInterval(watcher.timer);
            }
            watchers.clear();
            events.removeAllListeners();
        },
    };
}
