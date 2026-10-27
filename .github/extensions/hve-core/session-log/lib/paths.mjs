// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import os from 'node:os';
import path from 'node:path';

/** Session folders are lowercase UUIDs; pending drafts and lock files never match. */
export const SESSION_ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Subagent identifiers recorded as `agentId` share the UUID shape; `root` names the main agent. */
export const AGENT_KEY_RE = /^(root|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

export const SESSION_STATE_DIR = 'session-state';

/**
 * Resolves the folder that holds one subfolder per session.
 *
 * Order: the parent of the joined session's workspace folder when it is named
 * `session-state`, then `COPILOT_HOME`, then the user's home `.copilot` folder.
 *
 * @param {object} [options]
 * @param {string} [options.workspacePath] Joined session workspace folder, when known.
 * @param {Record<string, string | undefined>} [options.env] Environment to read `COPILOT_HOME` from.
 * @param {string} [options.homedir] Home directory used for the default location.
 * @param {typeof path} [options.pathApi] Path implementation, injectable for cross-platform tests.
 * @returns {{ root: string, source: 'workspace' | 'COPILOT_HOME' | 'home' }}
 */
export function resolveSessionStateRoot(options = {}) {
    const pathApi = options.pathApi ?? path;
    const env = options.env ?? process.env;
    const workspacePath = options.workspacePath;
    if (typeof workspacePath === 'string' && workspacePath.length > 0) {
        const normalized = pathApi.resolve(workspacePath);
        const parent = pathApi.dirname(normalized);
        if (pathApi.basename(parent) === SESSION_STATE_DIR && SESSION_ID_RE.test(pathApi.basename(normalized))) {
            return { root: parent, source: 'workspace' };
        }
    }
    const copilotHome = env.COPILOT_HOME;
    if (typeof copilotHome === 'string' && copilotHome.length > 0) {
        return { root: pathApi.join(copilotHome, SESSION_STATE_DIR), source: 'COPILOT_HOME' };
    }
    const home = options.homedir ?? os.homedir();
    return { root: pathApi.join(home, '.copilot', SESSION_STATE_DIR), source: 'home' };
}

/**
 * Returns true when the value is a syntactically valid session identifier.
 *
 * @param {unknown} value
 * @returns {value is string}
 */
export function isSessionId(value) {
    return typeof value === 'string' && SESSION_ID_RE.test(value);
}

/**
 * Builds the folder path for a session, rejecting anything that is not a session ID.
 *
 * @param {string} root Session-state root.
 * @param {string} sessionId Candidate session identifier.
 * @returns {string} Absolute session folder path inside `root`.
 */
export function sessionFolder(root, sessionId) {
    if (!isSessionId(sessionId)) {
        throw new RangeError('Invalid session ID');
    }
    const folder = path.join(root, sessionId.toLowerCase());
    const relative = path.relative(root, folder);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
        throw new RangeError('Session folder escapes the session-state root');
    }
    return folder;
}
