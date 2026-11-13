// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import { isCopilotSessionId } from '../model.mjs';
import { SourceError, TRACKING_DIR } from './workspace.mjs';

const SESSION_STATE_DIR = 'session-state';
export const WORKSPACE_FILE = 'workspace.yaml';
const MAX_WORKSPACE_BYTES = 64 * 1024;
const KEY_RE = /^([A-Za-z_][A-Za-z0-9_-]*):(?:\s(.*))?$/;

/** A session that cannot be resolved. `detail` names the session, file, or folder the reason is about. */
class SessionError extends SourceError {
    /**
     * @param {string} code
     * @param {string} message
     * @param {string | null} [detail]
     */
    constructor(code, message, detail = null) {
        super(code, message);
        this.detail = detail;
    }
}

/**
 * Resolves the folder that holds one subfolder per local session. The order matches the
 * Session Log canvas: the parent of the joined session's workspace folder when it is a
 * session-state folder, then `COPILOT_HOME`, then `~/.copilot`.
 *
 * @param {object} [options]
 * @param {string} [options.workspacePath] The joined session's workspace folder, when known.
 * @param {Record<string, string | undefined>} [options.env] Environment to read `COPILOT_HOME` from.
 * @param {string} [options.homedir] Home directory used for the default location.
 * @returns {{ root: string, source: 'workspace' | 'COPILOT_HOME' | 'home' }}
 */
export function resolveSessionStateRoot(options = {}) {
    const env = options.env ?? process.env;
    const workspacePath = options.workspacePath;
    if (typeof workspacePath === 'string' && workspacePath.length > 0) {
        const normalized = path.resolve(workspacePath);
        const parent = path.dirname(normalized);
        if (path.basename(parent) === SESSION_STATE_DIR && isCopilotSessionId(path.basename(normalized))) {
            return { root: parent, source: 'workspace' };
        }
    }
    if (typeof env.COPILOT_HOME === 'string' && env.COPILOT_HOME.length > 0) {
        return { root: path.join(env.COPILOT_HOME, SESSION_STATE_DIR), source: 'COPILOT_HOME' };
    }
    return { root: path.join(options.homedir ?? os.homedir(), '.copilot', SESSION_STATE_DIR), source: 'home' };
}

/**
 * Reads the flat `key: value` lines of a `workspace.yaml`. Nested and block content is indented,
 * so only top-level keys are read; quoted scalars are unquoted and other values are kept as written.
 *
 * @param {string} text
 * @returns {Record<string, string | boolean | null>}
 */
export function parseWorkspaceYaml(text) {
    /** @type {Record<string, string | boolean | null>} */
    const values = {};
    for (const line of text.replace(/\r\n?/g, '\n').split('\n')) {
        const match = KEY_RE.exec(line);
        if (match) values[match[1]] = scalarOf((match[2] ?? '').trim());
    }
    return values;
}

/** One YAML scalar: empty and null become null, quoted text is unquoted, and the rest is kept. */
function scalarOf(raw) {
    if (raw === '' || raw === '~' || raw === 'null') return null;
    if (raw === 'true') return true;
    if (raw === 'false') return false;
    if (raw.length >= 2 && raw.startsWith("'") && raw.endsWith("'")) return raw.slice(1, -1).replace(/''/g, "'");
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
        try {
            return JSON.parse(raw);
        } catch {
            return raw.slice(1, -1);
        }
    }
    return raw;
}

/** True when `target` is strictly inside `base`. */
function inside(base, target) {
    const relative = path.relative(base, target);
    return relative !== '' && relative.split(path.sep)[0] !== '..' && !path.isAbsolute(relative);
}

/**
 * A small regular file's text, or null when it is missing, linked, too large, or unreadable.
 *
 * @param {Partial<typeof fs>} api
 * @param {string} file
 */
async function readSmall(api, file) {
    const stat = await api.lstat(file).catch(() => null);
    if (!stat?.isFile() || stat.size > MAX_WORKSPACE_BYTES) return null;
    return api.readFile(file, 'utf8').catch(() => null);
}

/**
 * Reads local session folders under one session-state root, resolving the root's real path once
 * for all the reads. `read` checks the ID, resolves the session's folder, which must lie strictly
 * inside the real root, and reads and parses its `workspace.yaml`, which must be a small regular
 * file. Nothing is cached between readers, because a session's metadata can change.
 * `options.fs` overrides any of the file functions used.
 *
 * @param {{ root?: string, fs?: Partial<typeof fs> }} [options] `root` is the session-state folder, by default the one `resolveSessionStateRoot` finds.
 */
export function sessionFolderReader(options = {}) {
    const api = { ...fs, ...options.fs };
    const stateRoot = options.root ?? resolveSessionStateRoot().root;
    /** @type {Promise<string | null> | undefined} */
    let realRoot;
    return {
        /**
         * @param {string} sessionId A Copilot session ID; upper-case letters are accepted.
         * @returns {Promise<{ id: string, yamlPath: string, meta: Record<string, string | boolean | null> }>}
         */
        async read(sessionId) {
            if (!isCopilotSessionId(sessionId)) {
                throw new SessionError('session_invalid', 'session must be a Copilot session ID (a UUID), as in the name of its folder under session-state.');
            }
            const id = sessionId.toLowerCase();
            realRoot ??= api.realpath(stateRoot).catch(() => null);
            const root = await realRoot;
            const folder = root ? await api.realpath(path.join(stateRoot, id)).catch(() => null) : null;
            if (!folder) {
                throw new SessionError('session_not_found', `No Copilot session ${id} was found in ${stateRoot}.`, id);
            }
            if (!inside(root, folder)) {
                throw new SessionError('session_invalid', `Copilot session ${id} is outside ${stateRoot}.`, id);
            }
            const yamlPath = path.join(folder, WORKSPACE_FILE);
            const text = await readSmall(api, yamlPath);
            if (text === null) {
                throw new SessionError('session_no_workspace', `Copilot session ${id} has no readable ${WORKSPACE_FILE} in ${folder}.`, yamlPath);
            }
            return { id, yamlPath, meta: parseWorkspaceYaml(text) };
        },
    };
}

/**
 * The workspace a session's `workspace.yaml` names: the first absolute path among `git_root` and
 * `cwd` that directly contains a real `.copilot-tracking` folder, the same rule `resolveWorkspace`
 * applies to candidates.
 *
 * @param {{ id: string, yamlPath: string, meta: Record<string, string | boolean | null> }} session what a `sessionFolderReader` read
 * @param {{ fs?: Partial<typeof fs> }} [options]
 * @returns {Promise<{ root: string, tracking: string }>}
 */
export async function workspaceOfSession(session, options = {}) {
    const api = { ...fs, ...options.fs };
    const { id, yamlPath, meta } = session;
    const candidates = [...new Set([meta.git_root, meta.cwd].filter((value) => typeof value === 'string' && path.isAbsolute(value)))];
    if (candidates.length === 0) {
        throw new SessionError('session_no_workspace', `Copilot session ${id} records no workspace folder in ${yamlPath}.`, yamlPath);
    }
    for (const candidate of candidates) {
        const tracking = path.join(candidate, TRACKING_DIR);
        const stat = await api.lstat(tracking).catch(() => null);
        if (stat?.isDirectory()) {
            return { root: await api.realpath(candidate), tracking: await api.realpath(tracking) };
        }
    }
    const named = candidates.map((candidate) => path.join(candidate, TRACKING_DIR));
    throw new SessionError('session_no_tracking', `Copilot session ${id} has no real ${TRACKING_DIR} folder in ${named.join(' or ')}.`, named[0]);
}

/**
 * Finds the workspace root of one local Copilot session: reads its folder with a
 * `sessionFolderReader`, then resolves the workspace its `workspace.yaml` names with
 * `workspaceOfSession`.
 *
 * @param {string} sessionId A Copilot session ID; upper-case letters are accepted.
 * @param {{ root?: string, fs?: Partial<typeof fs> }} [options] `root` is the session-state folder, by default the one `resolveSessionStateRoot` finds.
 * @returns {Promise<{ root: string, tracking: string }>}
 */
export async function resolveSessionWorkspace(sessionId, options = {}) {
    return workspaceOfSession(await sessionFolderReader(options).read(sessionId), options);
}
