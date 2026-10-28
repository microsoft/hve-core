// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

import { ModelError } from '../model.mjs';
import { assembleSession, lineageStatusOf, mergeImport } from './assemble.mjs';
import { titleOf, parseDocument } from './markdown.mjs';
import { artifactKind, parseArtifact, parseState } from './parse.mjs';
import { buildTree, humanizeSlug } from './tree.mjs';
import { checkWorkspacePath, FileError, resolveWorkspaceFile } from '../workspace-files.mjs';

/**
 * Finds and reads RPI sessions in a workspace. Every read stays inside the workspace's
 * `.copilot-tracking` folder: paths come from input and from agent-written state files,
 * so each one is resolved, checked against the real path of that folder, refused when it
 * is a symlink, limited to `.md` and `.json` files, and capped in size. State files must
 * also sit in a session folder: `.copilot-tracking/rpi-sessions/<date>/<session>/`.
 */

export class SourceError extends ModelError {}

export const TRACKING_DIR = '.copilot-tracking';
export const SESSIONS_DIR = 'rpi-sessions';
export const MAX_FILE_BYTES = 2 * 1024 * 1024;
const MAX_STATE_FILES = 2000;
const STATE_FILE_RE = /-state\.json$/;
const ARTIFACT_KEYS = ['research', 'plan', 'critique', 'changes', 'review'];
const SKIPPED_SHOWN = 5;

const toPosix = (value) => value.split(path.sep).join('/');
const normalizeLink = (value) => (value ? toPosix(path.normalize(value)).replace(/^\.\//, '') : value);
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
 * The session a state path belongs to: `<date>/<session>` and its parts, or null when the
 * path is not in a session folder.
 *
 * @param {string} statePath Workspace-relative path.
 */
export function sessionOf(statePath) {
    const parts = String(statePath).split('/');
    const at = parts.lastIndexOf(SESSIONS_DIR);
    if (at < 0 || parts.length - at !== 4) return null;
    const [date, folder] = parts.slice(at + 1, at + 3);
    return { key: `${date}/${folder}`, date, folder };
}

/**
 * Checks a state path: a contained `*-state.json` regular file in a session folder.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} target Workspace-relative or absolute path.
 */
export async function inspectState(workspace, target) {
    if (typeof target === 'string' && target.trim() && !STATE_FILE_RE.test(target.trim())) {
        throw new SourceError('source_invalid', `${target} is not an RPI state file; state files end in -state.json.`);
    }
    const facts = await inspectContained(workspace, target);
    const segments = path.relative(path.join(workspace.tracking, SESSIONS_DIR), facts.absolute).split(path.sep);
    if (segments[0] === '..' || path.isAbsolute(segments.join(path.sep))) {
        throw new SourceError('source_outside', `${target} is outside ${TRACKING_DIR}/${SESSIONS_DIR}.`);
    }
    if (segments.length !== 3) {
        throw new SourceError('source_outside', `${target} is not in a session folder, ${TRACKING_DIR}/${SESSIONS_DIR}/<date>/<session>/.`);
    }
    return facts;
}

/**
 * Every state file in a session folder, newest first, and the state files the canvas
 * skips because they sit directly in a date folder (the layout before session folders).
 * Links and files that are too large are left out.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @returns {Promise<{ states: { path: string, mtimeMs: number, size: number, session: string }[], skipped: string[] }>}
 */
export async function scanStates(workspace) {
    const base = path.join(workspace.tracking, SESSIONS_DIR);
    const states = [];
    const skipped = [];
    for (const day of await listDir(base)) {
        if (!day.isDirectory()) continue;
        for (const entry of await listDir(path.join(base, day.name))) {
            const absolute = path.join(base, day.name, entry.name);
            if (entry.isFile() && STATE_FILE_RE.test(entry.name)) {
                skipped.push(toPosix(path.relative(workspace.root, absolute)));
                continue;
            }
            if (!entry.isDirectory()) continue;
            for (const file of await listDir(absolute)) {
                if (!file.isFile() || !STATE_FILE_RE.test(file.name) || states.length >= MAX_STATE_FILES) continue;
                const target = path.join(absolute, file.name);
                const stat = await fs.lstat(target).catch(() => null);
                if (stat?.isFile() && stat.size <= MAX_FILE_BYTES) {
                    states.push({ path: toPosix(path.relative(workspace.root, target)), mtimeMs: stat.mtimeMs, size: stat.size, session: `${day.name}/${entry.name}` });
                }
            }
        }
    }
    states.sort((a, b) => b.mtimeMs - a.mtimeMs || a.path.localeCompare(b.path));
    return { states, skipped: skipped.sort() };
}

/**
 * Every state file in a session folder, newest first.
 *
 * @param {{ root: string, tracking: string }} workspace
 */
export async function listStates(workspace) {
    return (await scanStates(workspace)).states;
}

/**
 * Reads and normalizes a state file, which must sit in a session folder. Link paths come
 * back normalized to workspace-relative POSIX form.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} statePath
 */
export async function loadState(workspace, statePath) {
    const facts = await inspectState(workspace, statePath);
    const text = await fs.readFile(facts.absolute, 'utf8');
    let raw;
    try {
        raw = JSON.parse(text);
    } catch {
        throw new SourceError('source_invalid', `${facts.path} is not valid JSON.`);
    }
    const state = parseState(raw);
    if (state.parent) state.parent = { ...state.parent, statePath: normalizeLink(state.parent.statePath) };
    state.children = state.children.map((link) => ({ ...link, statePath: normalizeLink(link.statePath) }));
    return { path: facts.path, mtimeMs: facts.mtimeMs, size: facts.size, state };
}

/** Readable states for scan entries, newest first; unreadable ones are skipped. */
async function loadAll(workspace, entries) {
    const loaded = [];
    for (const entry of entries) {
        const state = await loadState(workspace, entry.path).catch(() => null);
        if (state?.state.taskId) loaded.push(state);
    }
    return loaded;
}

/**
 * Resolves a task reference to its state file. `current` is the most recently changed
 * task whose session is running, or the most recently changed task when no session runs;
 * a task ID is the newest state file for that task.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} ref
 */
export async function resolveTask(workspace, ref) {
    const states = await loadAll(workspace, await listStates(workspace));
    const warnings = [];
    if (ref === 'current') {
        const pick = states.find((entry) => entry.state.sessionStatus?.toLowerCase() === 'running') ?? states[0];
        if (!pick) throw new SourceError('source_not_found', `No RPI session state was found in ${TRACKING_DIR}/${SESSIONS_DIR}.`);
        return { statePath: pick.path, taskId: pick.state.taskId, warnings };
    }
    const matches = states.filter((entry) => entry.state.taskId === ref);
    if (!matches.length) throw new SourceError('source_not_found', `No RPI session state for task ${ref} was found.`);
    if (matches.length > 1) warnings.push(`Task ${ref} has ${matches.length} state files; showing the newest, ${matches[0].path}.`);
    return { statePath: matches[0].path, taskId: ref, warnings };
}

/**
 * Resolves a state path given as input.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} statePath
 */
export async function resolveState(workspace, statePath) {
    const loaded = await loadState(workspace, statePath);
    if (!loaded.state.taskId) throw new SourceError('source_invalid', `${loaded.path} has no task_id.`);
    return { statePath: loaded.path, taskId: loaded.state.taskId, warnings: [] };
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

/** A readable name for a session: its first task's title, unless that is just the task ID. */
async function nameFromTask(workspace, loaded, folder) {
    if (!loaded) return humanizeSlug(folder);
    const title = await titleFor(workspace, loaded.state);
    return title && title !== loaded.state.taskId ? title : humanizeSlug(folder);
}

/**
 * Every session folder in the workspace, most recently changed first, and the state files
 * skipped because they are not in a session folder.
 *
 * @param {{ root: string, tracking: string }} workspace
 */
export async function listSessions(workspace) {
    const { states, skipped } = await scanStates(workspace);
    const groups = new Map();
    for (const entry of states) {
        if (!groups.has(entry.session)) groups.set(entry.session, []);
        groups.get(entry.session).push(entry);
    }
    const sessions = [];
    for (const [key, entries] of groups) {
        const [date, folder] = key.split('/');
        const loaded = await loadAll(workspace, entries);
        const named = loaded.find((entry) => entry.state.sessionName);
        const running = loaded.find((entry) => lineageStatusOf(entry.state) === 'running') ?? null;
        const first = loaded.filter((entry) => !entry.state.parent).at(-1) ?? loaded.at(-1) ?? null;
        sessions.push({
            key,
            date,
            folder,
            name: named?.state.sessionName ?? await nameFromTask(workspace, first, folder),
            tasks: entries.length,
            running: running ? { taskId: running.state.taskId, title: await titleFor(workspace, running.state), statePath: running.path } : null,
            changedAt: new Date(Math.max(...entries.map((entry) => entry.mtimeMs))).toISOString(),
        });
    }
    return { sessions: sessions.sort((a, b) => b.changedAt.localeCompare(a.changedAt) || a.key.localeCompare(b.key)), skipped };
}

/**
 * The session the task belongs to: its folder, name, and every task in it as a tree, with
 * a warning for each link that could not be followed.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {Awaited<ReturnType<typeof loadState>>} self
 * @param {Awaited<ReturnType<typeof scanStates>>} [scan]
 */
export async function sessionTreeOf(workspace, self, scan) {
    const where = /** @type {{ key: string, date: string, folder: string }} */ (sessionOf(self.path));
    const { states } = scan ?? await scanStates(workspace);
    const warnings = [];
    const members = [];
    for (const entry of states.filter((item) => item.session === where.key)) {
        let loaded = entry.path === self.path ? self : null;
        if (!loaded) {
            try {
                loaded = await loadState(workspace, entry.path);
            } catch (error) {
                warnings.push(error instanceof Error ? error.message : `${entry.path} could not be read.`);
                continue;
            }
        }
        members.push({ path: loaded.path, mtimeMs: loaded.mtimeMs, state: loaded.state, title: await titleFor(workspace, loaded.state) ?? loaded.path, status: lineageStatusOf(loaded.state) });
    }
    if (!members.some((member) => member.path === self.path)) {
        members.push({ path: self.path, mtimeMs: self.mtimeMs, state: self.state, title: await titleFor(workspace, self.state) ?? self.path, status: lineageStatusOf(self.state) });
    }
    const outside = new Map();
    for (const member of members) {
        const target = member.state.parent?.statePath;
        if (!target || outside.has(target) || members.some((item) => item.path === target)) continue;
        try {
            const parent = await loadState(workspace, target);
            outside.set(target, { id: parent.state.taskId ?? parent.path, title: await titleFor(workspace, parent.state) ?? parent.path, statePath: parent.path, session: sessionOf(parent.path)?.key ?? '', status: lineageStatusOf(parent.state) });
        } catch (error) {
            outside.set(target, { error: error instanceof Error ? error.message : 'unreadable' });
        }
    }
    const tree = buildTree({ members, shownPath: self.path, outside });
    const named = [...members].sort((a, b) => b.mtimeMs - a.mtimeMs).find((member) => member.state.sessionName);
    const first = tree.tasks.find((task) => task.depth === 0);
    const firstMember = first ? members.find((member) => member.path === first.statePath) : null;
    const name = self.state.sessionName ?? named?.state.sessionName ?? (firstMember && firstMember.title !== firstMember.state.taskId ? firstMember.title : humanizeSlug(where.folder));
    return { key: where.key, date: where.date, folder: where.folder, name, tasks: tree.tasks, warnings: [...warnings, ...tree.warnings] };
}

/** One warning naming state files the canvas skips, or none. */
export function skippedWarning(skipped) {
    if (!skipped.length) return [];
    const shown = skipped.slice(0, SKIPPED_SHOWN).join(', ');
    const more = skipped.length > SKIPPED_SHOWN ? `, and ${skipped.length - SKIPPED_SHOWN} more` : '';
    return [`${skipped.length === 1 ? 'A state file is' : `${skipped.length} state files are`} not in a session folder, so the canvas skips ${skipped.length === 1 ? 'it' : 'them'}: ${shown}${more}. Move each into ${TRACKING_DIR}/${SESSIONS_DIR}/<date>/<session>/.`];
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

const MAX_SOURCE_CHECKS = 200;

/** Whether a cited location is a readable file, a folder, missing, outside the workspace, or hidden. */
async function locationStatus(root, target) {
    try {
        checkWorkspacePath(target);
    } catch (error) {
        return error instanceof FileError && error.code === 'source_blocked' ? 'hidden' : error instanceof FileError && error.code === 'source_outside' ? 'outside' : 'missing';
    }
    try {
        await resolveWorkspaceFile(root, target);
        return 'file';
    } catch (error) {
        const code = error instanceof FileError ? error.code : 'source_not_found';
        if (code === 'source_too_large' || code === 'source_binary') return 'file';
        if (code === 'source_blocked') return 'hidden';
        if (code === 'source_outside') return 'outside';
        if (code === 'source_invalid') return await fs.stat(path.resolve(root, target)).then((stat) => (stat.isDirectory() ? 'folder' : 'missing'), () => 'missing');
        return 'missing';
    }
}

/**
 * Marks each code evidence location with its status and returns one problem per evidence ID
 * that cites a path missing from the workspace, checking at most 200 locations.
 *
 * @param {{ root: string }} workspace
 * @param {any} session assembled canvas document
 */
export async function checkSourceLocations(workspace, session) {
    const problems = [];
    let checks = 0;
    for (const item of session.research?.evidence ?? []) {
        const missing = [];
        for (const location of item.locations ?? []) {
            if (checks >= MAX_SOURCE_CHECKS) return problems;
            checks += 1;
            location.status = await locationStatus(workspace.root, location.path);
            if (location.status === 'missing' || location.status === 'outside') missing.push(location.path);
        }
        if (missing.length) {
            const named = missing.length > 2 ? `${missing.slice(0, -1).join(', ')}, and ${missing.at(-1)}` : missing.join(' and ');
            problems.push(`Research: ${item.id} cites ${named}, which ${missing.length === 1 ? 'is not a file' : 'are not files'} in this workspace; code evidence cites workspace-relative paths.`);
        }
    }
    return problems;
}

/** Kinds whose earlier documents the canvas reads and offers to switch to. */
const EARLIER_KINDS = ['research', 'plan'];

/** The files a task's view reads: its state, the current work's document of each kind, and every listed research document and plan. */
function watchedFiles(statePath, state) {
    return [...new Set([statePath, ...ARTIFACT_KEYS.map((key) => state.artifacts[key]), ...EARLIER_KINDS.flatMap((key) => state.documents[key])].filter(Boolean))];
}

/**
 * Reads the research documents and plans the state lists other than the current work's, each
 * numbered by its place in the list. A document that cannot be read or is another kind becomes
 * a warning.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {ReturnType<typeof parseState>} state
 * @param {string[]} warnings
 */
async function readEarlier(workspace, state, warnings) {
    const earlier = { research: [], plan: [] };
    for (const key of EARLIER_KINDS) {
        for (const [index, target] of state.documents[key].entries()) {
            if (target === state.artifacts[key]) continue;
            let file;
            try {
                file = await readContained(workspace, target);
            } catch (error) {
                const message = error instanceof Error ? error.message : 'could not be read.';
                warnings.push(message.includes(target) ? message : `${target}: ${message}`);
                continue;
            }
            const parsed = parseArtifact(file.text);
            if (parsed?.kind === key) earlier[key].push({ n: index + 1, path: file.path, mtimeMs: file.mtimeMs, parsed });
            else warnings.push(`${file.path} is listed in documents.${key} but is not a ${key} artifact.`);
        }
    }
    return earlier;
}

/** The suffix each kind's file name ends with, before `.md`. */
const NAME_SUFFIX = Object.freeze({ research: '-research', plan: '-plan' });

/**
 * A document's name: its file name without the folder, `.md`, and its kind's suffix, so
 * `task-board-polish-research.md` is `task-board-polish`. A trailing number stays in the name.
 *
 * @param {string} target workspace-relative path
 * @param {'research' | 'plan'} key
 */
export function documentName(target, key) {
    const base = target.split('/').pop().replace(/\.md$/i, '');
    const suffix = NAME_SUFFIX[key];
    return base.endsWith(suffix) && base.length > suffix.length ? base.slice(0, -suffix.length) : base;
}

/** IDs a research document or plan holds, from the session or an earlier document's snapshot. */
const DOCUMENT_IDS = Object.freeze({
    research: (part) => [...(part.research?.questions ?? []), ...(part.research?.findings ?? []), ...(part.research?.evidence ?? []), ...part.decisions].map((item) => item.id),
    plan: (part) => [...(part.plan?.phases ?? []).flatMap((phase) => [phase.id, ...phase.tasks.map((task) => task.id)]), ...(part.plan?.requirements ?? []).map((item) => item.id), ...part.decisions.map((item) => item.id)],
});

/** Says which IDs appear in more than one document of a kind, naming the documents; links go to the current, else the newer. */
function repeatedIdWarnings(session) {
    const warnings = [];
    for (const key of EARLIER_KINDS) {
        const where = new Map();
        for (const entry of session.documents[key]) {
            const part = entry.current ? { [key]: session[key], decisions: session.decisions.filter((decision) => decision.phase === key) } : entry.snapshot;
            if (!part) continue;
            for (const id of new Set(DOCUMENT_IDS[key](part))) where.set(id, [...(where.get(id) ?? []), entry.name]);
        }
        const repeated = [...where].filter(([, names]) => names.length > 1);
        if (!repeated.length) continue;
        const shown = repeated.slice(0, 8).map(([id, names]) => `${id} (${names.join(' and ')})`);
        const more = repeated.length > 8 ? `, and ${repeated.length - 8} more` : '';
        const noun = key === 'research' ? 'research document' : 'plan';
        warnings.push(`${key === 'research' ? 'Research' : 'Plan'}: ${repeated.length === 1 ? 'an ID appears' : `${repeated.length} IDs appear`} in more than one ${noun}: ${shown.join('; ')}${more}. Links go to the current ${noun} when it holds the ID, else to the newer one.`);
    }
    return warnings;
}

/**
 * Reads a task's state, the current work's artifacts, and its other research documents and
 * plans, and assembles its canvas document: the current work's document of each kind, with each
 * other one as a snapshot in `documents`. Artifact read problems become warnings; a state file that cannot
 * be read throws.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string} statePath
 * @param {string} now ISO timestamp
 */
export async function loadTask(workspace, statePath, now) {
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
    const earlier = await readEarlier(workspace, self.state, warnings);
    // Findings number on across the listed research documents, the current work's included.
    const findingCounts = self.state.documents.research.map((target, index) => (target === self.state.artifacts.research
        ? artifacts.research?.findings.length ?? 0
        : earlier.research.find((entry) => entry.n === index + 1)?.parsed.findings.length ?? 0));
    const findingsBefore = (n) => findingCounts.slice(0, n - 1).reduce((sum, count) => sum + count, 0);
    const currentAt = self.state.documents.research.indexOf(self.state.artifacts.research);
    const findingOffset = currentAt > 0 ? findingsBefore(currentAt + 1) : 0;
    if (earlier.research.length < self.state.documents.research.filter((target) => target !== self.state.artifacts.research).length) {
        warnings.push('An earlier research document could not be read, so finding numbers after it may not match the files.');
    }
    const scan = await scanStates(workspace);
    const tree = await sessionTreeOf(workspace, self, scan);
    const input = {
        id: storeIdFor(self.state.taskId),
        state: self.state,
        artifacts,
        mismatched,
        statePath: self.path,
        files,
        tree,
        git: await readGit(workspace.root),
        root: workspace.root,
        now,
    };
    const assembled = assembleSession({ ...input, findingOffset });
    // Another document renders as the session would if it were the current work's of its kind.
    const snapshotOf = (key, entry) => {
        const alt = assembleSession({ ...input, artifacts: { ...artifacts, [key]: entry.parsed }, files: { ...files, [key]: { path: entry.path, mtimeMs: entry.mtimeMs } }, findingOffset: key === 'research' ? findingsBefore(entry.n) : findingOffset }).session;
        return {
            [key]: alt[key],
            sections: Object.fromEntries(Object.entries(alt.sections).filter(([, section]) => section.doc === key)),
            decisions: alt.decisions.filter((decision) => decision.phase === key),
            record: alt.phases[key],
        };
    };
    const iso = (ms) => (Number.isFinite(ms) ? new Date(ms).toISOString() : null);
    assembled.session.documents = Object.fromEntries(EARLIER_KINDS.map((key) => {
        const listed = self.state.documents[key];
        return [key, listed.map((target, index) => {
            const n = index + 1;
            const name = documentName(target, key);
            if (target === self.state.artifacts[key]) return { n, path: files[key]?.path ?? target, name, title: artifacts[key]?.title || null, updatedAt: iso(files[key]?.mtimeMs), current: true };
            const entry = earlier[key].find((item) => item.n === n);
            return entry
                ? { n, path: entry.path, name, title: entry.parsed.title || null, updatedAt: iso(entry.mtimeMs), current: false, snapshot: snapshotOf(key, entry) }
                : { n, path: target, name, title: null, updatedAt: null, current: false, missing: true };
        })];
    }));
    const sourceProblems = await checkSourceLocations(workspace, assembled.session);
    assembled.session.source.warnings = [...warnings, ...assembled.session.source.warnings, ...repeatedIdWarnings(assembled.session), ...sourceProblems, ...tree.warnings, ...skippedWarning(scan.skipped)];
    const watched = watchedFiles(self.path, self.state);
    return { session: assembled.session, warnings: assembled.session.source.warnings, watched, statePath: self.path, taskId: self.state.taskId, tree };
}

/**
 * One string that changes whenever a watched file, a state file in the session, or the
 * set of skipped state files changes.
 *
 * @param {{ root: string, tracking: string }} workspace
 * @param {string[]} watched
 * @param {string | null} [sessionKey] `<date>/<session>`; every session when omitted.
 */
export async function sourceSignature(workspace, watched, sessionKey) {
    const parts = [];
    for (const target of watched) parts.push(`${target}=${await signatureOf(workspace, target)}`);
    const { states, skipped } = await scanStates(workspace);
    for (const entry of states) if (!sessionKey || entry.session === sessionKey) parts.push(`${entry.path}@${entry.size}:${entry.mtimeMs}`);
    for (const entry of skipped) parts.push(`skipped:${entry}`);
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
 * Follows one task's files and the state files of its session. `importNow` reads and
 * imports immediately (on open or a task switch). While started, each tick compares the
 * files' signature with the one last imported; a new signature is imported only once it
 * repeats on the next tick, so a file the agent is still writing is not read half-written.
 * A failed import keeps the stored document and records a warning on it; the next
 * successful import clears the warning. `onImport` runs after every successful import.
 *
 * @param {{
 *   store: ReturnType<typeof import('../store.mjs').createStore>,
 *   workspace: { root: string, tracking: string },
 *   statePath: string,
 *   intervalMs?: number,
 *   now?: () => string,
 *   log?: (message: string) => void,
 *   onImport?: (loaded: Awaited<ReturnType<typeof loadTask>>) => void | Promise<void>,
 * }} options
 */
export function createFollower(options) {
    const { store, workspace, statePath } = options;
    const intervalMs = options.intervalMs ?? 1500;
    const now = options.now ?? (() => new Date().toISOString());
    const log = options.log ?? (() => {});
    const sessionKey = sessionOf(statePath)?.key ?? null;
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
        try {
            await options.onImport?.(loaded);
        } catch (error) {
            log(`Following the session failed: ${error instanceof Error ? error.message : 'error'}`);
        }
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
        const signature = await sourceSignature(workspace, watched, sessionKey);
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
                watched = watchedFiles(self.path, self.state);
                return load(await sourceSignature(workspace, watched, sessionKey));
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
