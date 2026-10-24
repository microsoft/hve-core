// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

import { ModelError } from '../model.mjs';
import { assembleSession, lineageStatusOf, mergeImport } from './assemble.mjs';
import { titleOf, parseDocument } from './markdown.mjs';
import { artifactKind, parseArtifact, parseState } from './parse.mjs';

/**
 * Finds and reads RPI sessions in a workspace. Every read stays inside the workspace's
 * `.copilot-tracking` folder: paths come from input and from agent-written state files,
 * so each one is resolved, checked against the real path of that folder, refused when it
 * is a symlink, limited to `.md` and `.json` files, and capped in size.
 */

export class SourceError extends ModelError {}

export const TRACKING_DIR = '.copilot-tracking';
export const MAX_FILE_BYTES = 2 * 1024 * 1024;
const MAX_STATE_FILES = 2000;
const STATE_FILE_RE = /-state\.json$/;
const ARTIFACT_KEYS = ['research', 'plan', 'critique', 'changes', 'review'];

const toPosix = (value) => value.split(path.sep).join('/');
const inside = (base, target) => {
    const relative = path.relative(base, target);
    return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
};

/**
 * Resolves the workspace root: the first candidate that contains a real (not linked)
 * `.copilot-tracking` folder.
 *
 * @param {(string | null | undefined)[]} candidates Usually the open request's working directory, then the process working directory.
 * @returns {Promise<{ root: string, tracking: string }>}
 */
export async function resolveWorkspace(candidates) {
    const tried = [];
    for (const candidate of candidates) {
        if (typeof candidate !== 'string' || !path.isAbsolute(candidate) || tried.includes(candidate)) continue;
        tried.push(candidate);
        const stat = await fs.lstat(path.join(candidate, TRACKING_DIR)).catch(() => null);
        if (stat?.isDirectory()) {
            const root = await fs.realpath(candidate);
            return { root, tracking: await fs.realpath(path.join(root, TRACKING_DIR)) };
        }
    }
    throw new SourceError('source_unavailable', `No ${TRACKING_DIR} folder was found in ${tried.length ? tried.join(' or ') : 'the session working directory'}.`);
}

/**
 * Checks a path and returns its facts without reading it.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} target Workspace-relative or absolute path.
 */
export async function inspectContained(workspace, target) {
    if (typeof target !== 'string' || !target.trim()) {
        throw new SourceError('source_invalid', 'A file path is required.');
    }
    const absolute = path.resolve(workspace.root, target);
    if (!/\.(md|json)$/i.test(absolute)) {
        throw new SourceError('source_invalid', `${target} is not a Markdown or JSON file.`);
    }
    const stat = await fs.lstat(absolute).catch((error) => {
        throw new SourceError(error?.code === 'ENOENT' ? 'source_not_found' : 'source_invalid', `${target} could not be read.`);
    });
    if (stat.isSymbolicLink() || !stat.isFile()) {
        throw new SourceError('source_invalid', `${target} is not a regular file.`);
    }
    const real = await fs.realpath(absolute);
    if (!inside(workspace.tracking, real)) {
        throw new SourceError('source_outside', `${target} is outside ${TRACKING_DIR}.`);
    }
    if (stat.size > MAX_FILE_BYTES) {
        throw new SourceError('source_too_large', `${target} is larger than ${MAX_FILE_BYTES / 1024 / 1024} MB.`);
    }
    return { path: toPosix(path.relative(workspace.root, real)), absolute: real, size: stat.size, mtimeMs: stat.mtimeMs };
}

/**
 * Reads a contained file as text.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} target
 */
export async function readContained(workspace, target) {
    const facts = await inspectContained(workspace, target);
    const text = await fs.readFile(facts.absolute, 'utf8');
    return { ...facts, text };
}

/** Size and modification time as a change key, or `missing`. */
export async function signatureOf(workspace, target) {
    try {
        const facts = await inspectContained(workspace, target);
        return `${facts.size}:${facts.mtimeMs}`;
    } catch {
        return 'missing';
    }
}

async function listDir(dir) {
    return fs.readdir(dir, { withFileTypes: true }).catch(() => []);
}

/**
 * Every state file under `.copilot-tracking/rpi-sessions/<date>/`, newest first. Links
 * and files that are too large are skipped.
 *
 * @param {{ root: string, tracking: string }} workspace
 */
export async function listStates(workspace) {
    const base = path.join(workspace.tracking, 'rpi-sessions');
    const found = [];
    for (const day of await listDir(base)) {
        if (!day.isDirectory()) continue;
        for (const entry of await listDir(path.join(base, day.name))) {
            if (!entry.isFile() || !STATE_FILE_RE.test(entry.name) || found.length >= MAX_STATE_FILES) continue;
            const absolute = path.join(base, day.name, entry.name);
            const stat = await fs.lstat(absolute).catch(() => null);
            if (stat?.isFile() && stat.size <= MAX_FILE_BYTES) {
                found.push({ path: toPosix(path.relative(workspace.root, absolute)), mtimeMs: stat.mtimeMs, size: stat.size });
            }
        }
    }
    return found.sort((a, b) => b.mtimeMs - a.mtimeMs || a.path.localeCompare(b.path));
}

/**
 * Reads and normalizes a state file.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} statePath
 */
export async function loadState(workspace, statePath) {
    const file = await readContained(workspace, statePath);
    let raw;
    try {
        raw = JSON.parse(file.text);
    } catch {
        throw new SourceError('source_invalid', `${file.path} is not valid JSON.`);
    }
    return { path: file.path, mtimeMs: file.mtimeMs, size: file.size, state: parseState(raw) };
}

/** Every readable state, newest first; unreadable ones are skipped. */
async function allStates(workspace) {
    const loaded = [];
    for (const entry of await listStates(workspace)) {
        const state = await loadState(workspace, entry.path).catch(() => null);
        if (state?.state.taskId) loaded.push(state);
    }
    return loaded;
}

/**
 * Resolves a task reference to its state file. `current` is the root of the most
 * recently changed running session (or of the most recently changed session); a task ID
 * is the newest state file for that task.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} ref
 */
export async function resolveTask(workspace, ref) {
    const states = await allStates(workspace);
    const warnings = [];
    if (ref === 'current') {
        let pick = states.find((entry) => entry.state.sessionStatus === 'running') ?? states[0];
        if (!pick) throw new SourceError('source_not_found', `No RPI session state was found in ${TRACKING_DIR}/rpi-sessions.`);
        const seen = new Set([pick.state.taskId]);
        while (pick.state.parent?.taskId && !seen.has(pick.state.parent.taskId)) {
            const parent = states.find((entry) => entry.state.taskId === pick.state.parent.taskId);
            if (!parent) break;
            seen.add(parent.state.taskId);
            pick = parent;
        }
        return { statePath: pick.path, taskId: pick.state.taskId, warnings };
    }
    const matches = states.filter((entry) => entry.state.taskId === ref);
    if (!matches.length) throw new SourceError('source_not_found', `No RPI session state for task ${ref} was found.`);
    if (matches.length > 1) warnings.push(`Task ${ref} has ${matches.length} state files; showing the newest, ${matches[0].path}.`);
    return { statePath: matches[0].path, taskId: ref, warnings };
}

async function titleFor(workspace, state) {
    for (const key of ['plan', 'research']) {
        const target = state.artifacts[key];
        if (!target) continue;
        const file = await readContained(workspace, target).catch(() => null);
        const title = file ? titleOf(parseDocument(file.text.slice(0, 4096))).replace(/^[^:]*:\s*/, '').trim() : '';
        if (title && artifactKind(file.text.slice(0, 4096)) === key) return title;
    }
    return state.taskId;
}

/**
 * The task's lineage: its ancestors (root first), the task, then its child loops.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {{ path: string, state: ReturnType<typeof parseState> }} self
 * @param {Awaited<ReturnType<typeof loadState>>[]} [states]
 */
export async function lineageOf(workspace, self, states) {
    const known = states ?? await allStates(workspace);
    const byTask = new Map();
    for (const entry of known) if (!byTask.has(entry.state.taskId)) byTask.set(entry.state.taskId, entry);
    const ancestors = [];
    const seen = new Set([self.state.taskId]);
    let cursor = self.state.parent?.taskId ? byTask.get(self.state.parent.taskId) : null;
    while (cursor && !seen.has(cursor.state.taskId)) {
        seen.add(cursor.state.taskId);
        ancestors.unshift(cursor);
        cursor = cursor.state.parent?.taskId ? byTask.get(cursor.state.parent.taskId) : null;
    }
    const children = known.filter((entry) => entry.state.parent?.taskId === self.state.taskId && !seen.has(entry.state.taskId)).reverse();
    const describe = async (entry, relation) => ({ taskId: entry.state.taskId, title: await titleFor(workspace, entry.state), relation, status: lineageStatusOf(entry.state), statePath: entry.path });
    return [
        ...await Promise.all(ancestors.map((entry) => describe(entry, 'parent'))),
        await describe(self, 'this'),
        ...await Promise.all(children.map((entry) => describe(entry, 'child'))),
    ];
}

/**
 * Branch and `owner/repo` from `.git/HEAD` and the `origin` remote, when they are small
 * regular files under the root; null otherwise.
 *
 * @param {string} root
 */
export async function readGit(root) {
    const small = async (name, limit) => {
        const target = path.join(root, '.git', name);
        const stat = await fs.lstat(target).catch(() => null);
        return stat?.isFile() && stat.size <= limit ? fs.readFile(target, 'utf8').catch(() => null) : null;
    };
    const head = await small('HEAD', 4096);
    if (head === null) return null;
    const ref = /^ref:\s*refs\/heads\/(.+)$/m.exec(head)?.[1]?.trim();
    const branch = ref ?? (/^[0-9a-f]{40}/.exec(head.trim())?.[0].slice(0, 12) ?? null);
    const config = await small('config', 65536);
    const remote = config ? /\[remote "origin"\][^[]*?\burl\s*=\s*(\S+)/.exec(config)?.[1] : null;
    const repository = remote ? /(?:github\.com|dev\.azure\.com|gitlab\.com)[:/](.+?)(?:\.git)?\/?$/.exec(remote)?.[1] ?? null : null;
    return { repository, branch };
}

/**
 * Store ID for a task's document: `rpi-` plus the task ID, kept to the store's ID pattern
 * and length, with a short hash when the task ID had to be shortened or cleaned.
 *
 * @param {string} taskId
 */
export function storeIdFor(taskId) {
    const clean = String(taskId).toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    const id = `rpi-${clean}`;
    if (id.length <= 80 && clean === taskId) return id;
    return `${id.slice(0, 70).replace(/-+$/, '')}-${createHash('sha256').update(String(taskId)).digest('hex').slice(0, 8)}`;
}

/**
 * Reads a task's state and artifacts and assembles its canvas document. Artifact read
 * problems become warnings; a state file that cannot be read throws.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} statePath
 * @param {string} now ISO timestamp
 */
export async function loadTask(workspace, statePath, now) {
    const states = await allStates(workspace);
    const self = await loadState(workspace, statePath);
    const files = { state: { path: self.path, mtimeMs: self.mtimeMs } };
    const artifacts = {};
    const mismatched = [];
    const warnings = [];
    for (const key of ARTIFACT_KEYS) {
        const target = self.state.artifacts[key];
        if (!target) continue;
        let file;
        try {
            file = await readContained(workspace, target);
        } catch (error) {
            const message = error instanceof Error ? error.message : 'could not be read.';
            warnings.push(message.includes(target) ? message : `${target}: ${message}`);
            continue;
        }
        const parsed = parseArtifact(file.text);
        if (parsed?.kind === key) {
            artifacts[key] = parsed;
            files[key] = { path: file.path, mtimeMs: file.mtimeMs };
        } else {
            mismatched.push({ key, path: file.path, kind: parsed?.kind ?? null });
            if (!(key === 'research' && parsed?.kind)) warnings.push(`${file.path} is not a ${key} artifact.`);
        }
    }
    const lineage = await lineageOf(workspace, self, states);
    const assembled = assembleSession({
        id: storeIdFor(self.state.taskId),
        state: self.state,
        artifacts,
        mismatched,
        statePath: self.path,
        files,
        lineage,
        git: await readGit(workspace.root),
        root: workspace.root,
        now,
    });
    assembled.session.source.warnings = [...warnings, ...assembled.session.source.warnings];
    const watched = [self.path, ...ARTIFACT_KEYS.map((key) => self.state.artifacts[key]).filter(Boolean)];
    return { session: assembled.session, warnings: assembled.session.source.warnings, watched, statePath: self.path, taskId: self.state.taskId, lineage };
}

/**
 * One string that changes whenever a watched file, or the set of state files, changes.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string[]} watched
 */
export async function sourceSignature(workspace, watched) {
    const parts = [];
    for (const target of watched) parts.push(`${target}=${await signatureOf(workspace, target)}`);
    for (const entry of await listStates(workspace)) parts.push(`${entry.path}@${entry.size}:${entry.mtimeMs}`);
    return createHash('sha256').update(parts.join('\n')).digest('hex');
}

/**
 * Writes a loaded task into the store: creates the document on first import, otherwise
 * merges, attributed to the source so the user's change count does not move.
 *
 * @param {ReturnType<typeof import('../store.mjs').createStore>} store
 * @param {{ session: any }} loaded
 * @param {string} now
 */
export async function importIntoStore(store, loaded, now) {
    const existing = await store.load(loaded.session.id).catch(() => undefined);
    if (!existing) {
        try {
            return { session: await store.create(loaded.session), changed: true };
        } catch (error) {
            if (!(error instanceof ModelError) || error.code !== 'scenario_exists') throw error;
        }
    }
    const result = await store.update(loaded.session.id, (current) => ({ session: mergeImport(current, loaded.session, now), result: null }), { by: 'source' });
    return { session: result.session, changed: result.changed };
}

/**
 * Follows one task's files. `importNow` reads and imports immediately (on open or a task
 * switch). While started, each tick compares the files' signature with the one last
 * imported; a new signature is imported only once it repeats on the next tick, so a file
 * the agent is still writing is not read half-written. A failed import keeps the stored
 * document and records a warning on it; the next successful import clears the warning.
 *
 * @param {{
 *   store: ReturnType<typeof import('../store.mjs').createStore>,
 *   workspace: { root: string, tracking: string },
 *   statePath: string,
 *   intervalMs?: number,
 *   now?: () => string,
 *   log?: (message: string) => void,
 * }} options
 */
export function createFollower(options) {
    const { store, workspace, statePath } = options;
    const intervalMs = options.intervalMs ?? 1500;
    const now = options.now ?? (() => new Date().toISOString());
    const log = options.log ?? (() => {});
    let watched = [statePath];
    let documentId = null;
    let imported = null;
    let pending = null;
    let timer = null;
    let busy = null;

    async function load(signature) {
        const loaded = await loadTask(workspace, statePath, now());
        watched = loaded.watched;
        documentId = loaded.session.id;
        const result = await importIntoStore(store, loaded, now());
        imported = signature;
        return { ...result, loaded };
    }

    async function recordFailure(error) {
        imported = pending ?? imported;
        const message = `The session files could not be read; showing the last good version. ${error instanceof Error ? error.message : ''}`.trim();
        log(message);
        if (!documentId) return;
        await store.update(documentId, (current) => (current.source?.warnings?.[0] === message
            ? { session: current, result: null }
            : { session: { ...current, revision: current.revision + 1, updatedAt: now(), source: { ...current.source, warnings: [message, ...(current.source?.warnings ?? [])] } }, result: null }), { by: 'source' }).catch(() => {});
    }

    async function tick() {
        const signature = await sourceSignature(workspace, watched);
        if (signature === imported) {
            pending = null;
            return false;
        }
        if (signature !== pending) {
            pending = signature;
            return false;
        }
        try {
            await load(signature);
            return true;
        } catch (error) {
            await recordFailure(error);
            return false;
        } finally {
            pending = null;
        }
    }

    const serial = (run) => {
        const next = (busy ?? Promise.resolve()).then(run, run);
        busy = next.catch(() => {});
        return next;
    };

    return {
        get documentId() {
            return documentId;
        },

        /** Reads and imports now; throws when the task cannot be loaded. */
        importNow() {
            return serial(async () => {
                const self = await loadState(workspace, statePath);
                watched = [self.path, ...ARTIFACT_KEYS.map((key) => self.state.artifacts[key]).filter(Boolean)];
                return load(await sourceSignature(workspace, watched));
            });
        },

        /** One polling step; resolves true when it imported. */
        tick() {
            return serial(tick);
        },

        start() {
            if (timer) return;
            timer = setInterval(() => {
                this.tick().catch((error) => log(`Following the session failed: ${error instanceof Error ? error.message : 'error'}`));
            }, intervalMs);
            timer.unref?.();
        },

        stop() {
            clearInterval(timer);
            timer = null;
        },

        get running() {
            return timer !== null;
        },
    };
}
