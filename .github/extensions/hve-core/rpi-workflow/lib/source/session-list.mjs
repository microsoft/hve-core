// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import path from 'node:path';

import { hasLiveProcess } from '../inbox.mjs';
import { lineageStatusOf, phaseKey } from './assemble.mjs';
import { parseArtifact } from './parse.mjs';
import { isCopilotSessionId } from '../model.mjs';
import { parseWorkspaceYaml, readSmall, resolveSessionStateRoot, resolveSessionWorkspace, WORKSPACE_FILE } from './sessions.mjs';
import { loadState, readContained, resolveTask, SourceError } from './workspace.mjs';

/** How many other sessions a listing examines when no limit is given: the most recently updated ones. */
export const DEFAULT_LIMIT = 30;
/** Why a session cannot be listed, for each session error its folder or workspace raises. */
const PROBLEM_BY_CODE = Object.freeze({
    session_not_found: 'not-found',
    session_invalid: 'not-found',
    session_no_workspace: 'no-workspace',
    session_no_tracking: 'no-tracking',
});
/** The artifact kinds that give a task its title, in the order the canvas takes them. */
const TITLE_KINDS = ['plan', 'changes', 'review', 'research'];

/** A trimmed `workspace.yaml` field, or null when it is missing or empty. */
const textOf = (value) => (typeof value === 'string' && value.trim() ? value.trim() : null);

/**
 * @typedef {object} RpiSessionEntry
 * @property {string} sessionId lowercase Copilot session ID
 * @property {string | null} name the session's name in its workspace.yaml
 * @property {string | null} repository
 * @property {string | null} branch
 * @property {boolean} mine the conversation started this session
 * @property {boolean} own the session the conversation runs in
 * @property {boolean} live a canvas process runs for the session
 * @property {{ taskId: string, title: string, phase: string | null, status: string, statePath: string } | null} task the current task, or null when there is none to show
 * @property {'not-found' | 'no-workspace' | 'no-tracking' | 'no-rpi' | null} problem why the session has no RPI work to show
 */

/**
 * The title the canvas shows for a task: the first of its plan, changes, review, and research artifacts
 * that reads as that kind, else the task ID.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {{ taskId: string, artifacts: Record<string, string | null> }} state
 */
async function titleOf(workspace, state) {
    for (const key of TITLE_KINDS) {
        const target = state.artifacts[key];
        if (!target) continue;
        const file = await readContained(workspace, target).catch(() => null);
        const parsed = file ? parseArtifact(file.text) : null;
        if (parsed?.kind === key && parsed.title) return parsed.title;
    }
    return state.taskId;
}

/**
 * The current task of a workspace, read the way the canvas reads it: the running task, or the most
 * recently changed one. A workspace with no readable state file has the `no-rpi` problem.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @returns {Promise<{ task: RpiSessionEntry['task'], problem: RpiSessionEntry['problem'] }>}
 */
async function currentTaskOf(workspace) {
    try {
        const { statePath } = await resolveTask(workspace, 'current');
        const loaded = await loadState(workspace, statePath);
        return {
            task: {
                taskId: loaded.state.taskId,
                title: await titleOf(workspace, loaded.state),
                phase: phaseKey(loaded.state.activePhase),
                status: lineageStatusOf(loaded.state),
                statePath: loaded.path,
            },
            problem: null,
        };
    } catch (error) {
        if (error instanceof SourceError) return { task: null, problem: 'no-rpi' };
        throw error;
    }
}

/**
 * The directories of the session-state root whose names are session IDs, by lowercase ID. Each has its
 * `workspace.yaml` fields (when readable) and its last update: the file's `updated_at`, else the folder's
 * modification time. Links are never listed.
 *
 * @param {Partial<typeof fs>} api
 * @param {string} root
 * @returns {Promise<Map<string, { sessionId: string, meta: Record<string, string | boolean | null> | null, updatedMs: number }>>}
 */
async function sessionFoldersOf(api, root) {
    let entries;
    try {
        entries = await api.readdir(root, { withFileTypes: true });
    } catch (error) {
        if (/** @type {NodeJS.ErrnoException} */ (error).code === 'ENOENT') return new Map();
        throw error;
    }
    const folders = await Promise.all(entries
        .filter((entry) => entry.isDirectory() && isCopilotSessionId(entry.name))
        .map(async (entry) => {
            const folder = path.join(root, entry.name);
            const text = await readSmall(api, path.join(folder, WORKSPACE_FILE));
            const meta = text === null ? null : parseWorkspaceYaml(text);
            const stat = await api.lstat(folder).catch(() => null);
            const parsed = typeof meta?.updated_at === 'string' ? Date.parse(meta.updated_at) : Number.NaN;
            return { sessionId: entry.name.toLowerCase(), meta, updatedMs: Number.isFinite(parsed) ? parsed : (stat?.mtimeMs ?? 0) };
        }));
    return new Map(folders.map((folder) => [folder.sessionId, folder]));
}

/** Newest first; ties keep the ID order, so a listing is stable. */
const newestFirst = (a, b) => b.updatedMs - a.updatedMs || a.sessionId.localeCompare(b.sessionId);

/**
 * Lists the local Copilot sessions whose RPI work a canvas can show. The listing has the sessions the
 * conversation started (`mine`, in the order given), then the most recently updated other sessions, up to
 * `limit`. A workspace shared by several sessions is listed once, under its most recently updated session,
 * and never under a session that the conversation started. Mine sessions are always listed, with their
 * problem; other sessions with a problem are left out and counted in `skipped`. Only `workspace.yaml`
 * and each workspace's tracking folder are read, and a symbolic link is never followed.
 *
 * @param {{
 *   root?: string,
 *   mine?: string[],
 *   own?: string | null,
 *   limit?: number,
 *   loadPresence?: (sessionId: string) => Promise<{ processes: { version: number, updatedAt: string }[] }>,
 *   now?: () => number | string,
 *   fs?: Partial<typeof fs>,
 * }} [options] `root` is the session-state folder, by default the one `resolveSessionStateRoot` finds; `own` is the conversation's own session.
 * @returns {Promise<{ sessions: RpiSessionEntry[], skipped: number }>}
 */
export async function listRpiSessions(options = {}) {
    const api = { ...fs, ...options.fs };
    const root = options.root ?? resolveSessionStateRoot().root;
    const limit = Number.isInteger(options.limit) && options.limit >= 0 ? options.limit : DEFAULT_LIMIT;
    const own = typeof options.own === 'string' ? options.own.toLowerCase() : null;
    const mine = [...new Set((options.mine ?? []).map((id) => String(id).toLowerCase()))];
    const clock = () => {
        const at = options.now?.() ?? Date.now();
        return typeof at === 'number' ? at : Date.parse(at);
    };
    const folders = await sessionFoldersOf(api, root);
    const others = [...folders.values()].filter((folder) => !mine.includes(folder.sessionId)).sort(newestFirst).slice(0, limit);

    // A workspace is read once per listing, however many sessions use it.
    const tasks = new Map();
    const resolveEntry = async (sessionId) => {
        if (!folders.has(sessionId)) return { sessionId, root: null, task: null, problem: 'not-found' };
        let workspace;
        try {
            workspace = await resolveSessionWorkspace(sessionId, { root, fs: api });
        } catch (error) {
            const problem = PROBLEM_BY_CODE[/** @type {any} */ (error)?.code];
            if (!problem) throw error;
            return { sessionId, root: null, task: null, problem };
        }
        if (!tasks.has(workspace.root)) tasks.set(workspace.root, currentTaskOf(workspace));
        const current = await tasks.get(workspace.root);
        return { sessionId, root: workspace.root, task: current?.task ?? null, problem: current?.problem ?? null };
    };

    const mineResolved = await Promise.all(mine.map((sessionId) => resolveEntry(sessionId)));
    const othersResolved = await Promise.all(others.map((folder) => resolveEntry(folder.sessionId)));
    const claimed = new Set(mineResolved.map((item) => item.root).filter(Boolean));
    const kept = [];
    for (const item of othersResolved) {
        if (item.root) {
            if (claimed.has(item.root)) continue;
            claimed.add(item.root);
        }
        kept.push(item);
    }
    const skipped = kept.filter((item) => item.problem).length;

    const liveOf = async (sessionId) => {
        if (!options.loadPresence) return false;
        try {
            return hasLiveProcess(await options.loadPresence(sessionId), clock());
        } catch {
            return false;
        }
    };
    const sessions = await Promise.all([...mineResolved, ...kept.filter((item) => !item.problem)].map(async (item) => {
        const meta = folders.get(item.sessionId)?.meta ?? null;
        return {
            sessionId: item.sessionId,
            name: textOf(meta?.name),
            repository: textOf(meta?.repository),
            branch: textOf(meta?.branch),
            mine: mine.includes(item.sessionId),
            own: item.sessionId === own,
            live: await liveOf(item.sessionId),
            task: item.task ? { ...item.task } : null,
            problem: item.problem,
        };
    }));
    return { sessions, skipped };
}
