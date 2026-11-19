// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { randomUUID } from 'node:crypto';
import { check, initialState, object, relativePath, stableJson, text, validateSnapshot } from './model.mjs';
import { digest, exists, loadReview, MAX_RECORD_BYTES, readText, reviewRoot, withLock, writeJson } from './storage.mjs';

const execute = promisify(execFile);
export const MAX_FILE_BYTES = 256 * 1024;
const MAX_SNAPSHOT_BYTES = 4 * 1024 * 1024;
const SENSITIVE = /(^|\/)(\.env(?:\..*)?|\.npmrc|\.pypirc|\.gitconfig|\.git-credentials|credentials(?:\.[^/]*)?|secrets?(?:\.[^/]*)?|id_(rsa|ed25519)|[^/]+\.(pem|key|pfx|p12|kdbx))$/i;
const EXCLUDED = /^(?:\.git|\.copilot-tracking)(?:\/|$)/;

export async function gitCommand(repository, args) {
    const pending = execute('git', ['--no-pager', '-c', 'core.fsmonitor=false', '-c', 'core.quotePath=false', ...args], {
        cwd: repository, encoding: 'utf8', maxBuffer: MAX_RECORD_BYTES, timeout: 30000,
        env: { ...process.env, GIT_PAGER: 'cat', GIT_LITERAL_PATHSPECS: '1', GIT_OPTIONAL_LOCKS: '0' },
    });
    pending.child.stdin.end();
    const { stdout } = await pending;
    return stdout;
}

async function commit(repository, revision, git) {
    text(revision, 'revision');
    check(!revision.startsWith('-'), 'A revision cannot be an option.', 'invalid_input');
    return (await git(repository, ['rev-parse', '--verify', '--end-of-options', `${revision}^{commit}`])).trim();
}

export function parsePatch(patch, fileId) {
    const hunks = [];
    const lines = [];
    let current;
    let oldLine = 0;
    let newLine = 0;
    for (const raw of patch.split('\n')) {
        const match = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/.exec(raw);
        if (match) {
            current = {
                id: `${fileId}-h${hunks.length + 1}`, oldStart: Number(match[1]), oldCount: Number(match[2] ?? 1),
                newStart: Number(match[3]), newCount: Number(match[4] ?? 1), oldLines: [], newLines: [],
            };
            oldLine = current.oldStart;
            newLine = current.newStart;
            hunks.push(current);
            continue;
        }
        if (!current || ![' ', '-', '+'].includes(raw[0])) continue;
        const kind = raw[0] === '+' ? 'add' : raw[0] === '-' ? 'delete' : 'context';
        const before = kind === 'add' ? null : oldLine++;
        const after = kind === 'delete' ? null : newLine++;
        if (kind === 'add') current.newLines.push(after);
        if (kind === 'delete') current.oldLines.push(before);
        lines.push({ hunkId: current.id, kind, oldLine: before, newLine: after, text: raw.slice(1) });
    }
    for (const hunk of hunks) {
        const captured = lines.filter((line) => line.hunkId === hunk.id);
        check(captured.filter((line) => line.oldLine !== null).length === hunk.oldCount &&
            captured.filter((line) => line.newLine !== null).length === hunk.newCount, 'Truncated or malformed diff hunk.', 'invalid_diff');
    }
    return { hunks, lines };
}

function rawFiles(raw) {
    const entries = raw.split('\0');
    const result = [];
    for (let at = 0; at < entries.length - 1;) {
        const header = /^:(\d{6}) (\d{6}) ([a-f0-9]+) ([a-f0-9]+) ([A-Z])\d*$/.exec(entries[at++]);
        check(header, 'Unsupported Git inventory record.', 'invalid_diff');
        const first = entries[at++];
        const second = ['R', 'C'].includes(header[5]) ? entries[at++] : first;
        relativePath(first);
        relativePath(second);
        if (EXCLUDED.test(first) || EXCLUDED.test(second)) continue;
        result.push({
            status: header[5], oldPath: header[5] === 'A' ? null : first, newPath: header[5] === 'D' ? null : second,
            oldOid: /^0+$/.test(header[3]) ? null : header[3], newOid: /^0+$/.test(header[4]) ? null : header[4],
            oldMode: header[1], newMode: header[2],
        });
    }
    return result;
}

const diffOptions = ['--no-ext-diff', '--no-textconv', '--no-color', '--find-renames', '--submodule=short'];

async function inventory(repository, target, git) {
    const revisions = target.kind !== 'local' ? [target.mergeBase ?? target.base, target.head] :
        target.localMode === 'staged' ? ['--cached', target.head] : target.localMode === 'combined' ? [target.head] : [];
    const raw = await git(repository, ['diff', ...diffOptions, '--raw', '-z', '--no-abbrev', ...revisions, '--']);
    const files = rawFiles(raw);
    if (target.kind === 'local' && target.localMode !== 'staged') {
        const untracked = (await git(repository, ['ls-files', '--others', '--exclude-standard', '-z'])).split('\0').filter(Boolean);
        for (const name of untracked) {
            relativePath(name);
            if (!EXCLUDED.test(name)) files.push({ status: 'A', oldPath: null, newPath: name, oldOid: null, newOid: null, oldMode: '000000', newMode: '100644', untracked: true });
        }
    }
    return { revisions, files };
}

async function localFingerprint(repository, target, listing, git) {
    const pieces = [target.head, await git(repository, ['ls-files', '--stage', '-z']), stableJson(listing.files)];
    for (const file of listing.files) {
        const name = file.newPath;
        if (!name || target.localMode === 'staged') continue;
        let stat;
        try {
            stat = await fs.lstat(path.join(repository, name), { bigint: true });
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
            pieces.push(`${name}:missing`);
            continue;
        }
        pieces.push(`${name}:${stat.size}:${stat.mtimeNs}:${stat.ctimeNs}:${stat.ino}`);
    }
    return digest(pieces.join('\0'));
}

function addedEvidence(content, fileId, start = 1) {
    const values = content.split('\n');
    if (values.at(-1) === '') values.pop();
    if (!values.length) return { hunks: [], lines: [] };
    const hunk = { id: `${fileId}-h1`, oldStart: 0, oldCount: 0, newStart: start, newCount: values.length, oldLines: [], newLines: values.map((_, index) => start + index) };
    return { hunks: [hunk], lines: values.map((value, index) => ({ hunkId: hunk.id, kind: 'add', oldLine: null, newLine: start + index, text: value })) };
}

async function resolveTarget(repository, request, git) {
    const target = { kind: request.kind, base: null, head: null, mergeBase: null, fingerprint: null, provider: request.provider ?? null, selection: null, localMode: null };
    if (request.kind === 'selected') {
        check(Array.isArray(request.selection) && request.selection.length > 0, 'Selected-code capture requires explicit selections.', 'invalid_input');
        target.selection = request.selection.map(({ path: name, startLine, endLine }) => ({ path: name, startLine, endLine }));
        return target;
    }
    if (request.kind === 'local') {
        check(['staged', 'unstaged', 'combined'].includes(request.localMode), 'Choose staged, unstaged, or combined local changes.', 'invalid_input');
        target.localMode = request.localMode;
        target.head = await commit(repository, 'HEAD', git);
        return target;
    }
    check(['branch', 'pr', 'commit'].includes(request.kind), 'Choose an explicit review target kind.', 'invalid_input');
    target.head = await commit(repository, request.head, git);
    if (request.kind === 'commit' && request.base === undefined) {
        const parents = (await git(repository, ['rev-list', '--parents', '-n', '1', target.head])).trim().split(' ').slice(1);
        check(parents.length <= 1, 'Merge commits require an explicit base.', 'ambiguous_target');
        target.base = parents[0] ?? (await git(repository, ['hash-object', '-t', 'tree', '--stdin'])).trim();
    } else {
        target.base = await commit(repository, request.base, git);
    }
    if (['branch', 'pr'].includes(request.kind) && request.comparison !== 'direct') target.mergeBase = (await git(repository, ['merge-base', target.base, target.head])).trim();
    if (request.kind === 'pr') check(request.provider, 'PR/MR capture requires provider metadata.', 'invalid_input');
    return target;
}

/** Capture from fixed revisions or fail when the local surface changes during the read. */
export async function captureSnapshot(repository, reviewId, request, git = gitCommand) {
    object(request, ['kind'], 'capture request', ['base', 'head', 'provider', 'localMode', 'comparison', 'selection', 'discussion', 'metadata', 'supplied']);
    const target = await resolveTarget(repository, request, git);
    const snapshotId = `snapshot-${randomUUID()}`;
    let listing;
    let before;
    if (target.kind === 'selected') {
        const names = request.selection.map((entry) => relativePath(entry.path));
        check(new Set(names).size === names.length, 'Use one selection per file.', 'invalid_input');
        listing = { files: request.selection.map((entry) => ({ status: 'M', oldPath: entry.path, newPath: entry.path, oldOid: null, newOid: null, selection: entry })) };
    } else if (request.supplied) {
        check(['branch', 'pr', 'commit'].includes(target.kind), 'Supplied diffs require immutable revisions.', 'invalid_input');
        object(request.supplied, ['base', 'head', 'files'], 'supplied diff');
        check(request.supplied.base === (target.mergeBase ?? target.base) && request.supplied.head === target.head, 'Supplied diff identity does not match the target.', 'identity_mismatch');
        check(Array.isArray(request.supplied.files), 'Supplied files must be an array.');
        listing = { files: request.supplied.files.map((file) => {
            object(file, ['status', 'oldPath', 'newPath', 'patch'], 'supplied file');
            text(file.patch, 'supplied patch', true);
            return { ...file, oldOid: null, newOid: null };
        }) };
    } else {
        listing = await inventory(repository, target, git);
        if (target.kind === 'local') before = await localFingerprint(repository, target, listing, git);
    }
    check(listing.files.length > 0, 'No reviewable content was found.', 'empty_target');
    const files = [];
    const evidence = new Map();
    const selectedReads = [];
    let total = 0;
    for (const [index, source] of listing.files.entries()) {
        check(source.status !== 'U', 'Resolve unmerged paths before capturing a review.', 'ambiguous_target');
        const fileId = `file-${index + 1}`;
        for (const name of [source.oldPath, source.newPath]) if (name !== null) relativePath(name);
        const file = {
            id: fileId, status: source.status, oldPath: source.oldPath, newPath: source.newPath, oldOid: source.oldOid, newOid: source.newOid,
            evidencePath: null, omission: null, hunks: [],
        };
        const names = [source.oldPath, source.newPath].filter(Boolean);
        if (names.some((name) => SENSITIVE.test(name) || EXCLUDED.test(name))) file.omission = 'Sensitive/configuration-private path; contents not captured.';
        else if (['120000', '160000'].some((mode) => source.oldMode === mode || source.newMode === mode)) file.omission = 'Symbolic link or submodule; inventory only.';
        else if (total >= MAX_SNAPSHOT_BYTES) file.omission = 'Snapshot text budget reached.';
        else {
            let parsed;
            try {
                if (source.selection) {
                    object(source.selection, ['path', 'startLine', 'endLine'], 'selection', ['text']);
                    check(Number.isSafeInteger(source.selection.startLine) && source.selection.startLine > 0 &&
                        Number.isSafeInteger(source.selection.endLine) && source.selection.endLine >= source.selection.startLine, 'Invalid selected line range.');
                    let content;
                    if (source.selection.text !== undefined) {
                        content = text(source.selection.text, 'selected text');
                    } else {
                        const raw = await readText(repository, source.newPath, MAX_FILE_BYTES);
                        selectedReads.push({ path: source.newPath, digest: digest(raw) });
                        const all = raw.split('\n');
                        if (all.at(-1) === '') all.pop();
                        check(source.selection.endLine <= all.length, 'Selection extends beyond the source.');
                        content = all.slice(source.selection.startLine - 1, source.selection.endLine).join('\n');
                    }
                    parsed = addedEvidence(content, fileId, source.selection.startLine);
                    check(parsed.lines.length === source.selection.endLine - source.selection.startLine + 1, 'Selected text does not match its declared line range.');
                } else if (source.untracked) {
                    const content = await readText(repository, source.newPath, MAX_FILE_BYTES);
                    check(!content.includes('\0'), 'Binary source has no text preview.', 'unsupported_text');
                    parsed = addedEvidence(content, fileId);
                } else {
                    const patch = source.patch ?? await git(repository, ['diff', ...diffOptions, '--unified=3', ...listing.revisions, '--', ...new Set(names)]);
                    check(Buffer.byteLength(patch) <= MAX_FILE_BYTES, 'File diff exceeds the preview budget.', 'source_too_large');
                    check(!/^Binary files |^GIT binary patch/m.test(patch) && !patch.includes('\0'), 'Binary change has no text preview.', 'unsupported_text');
                    parsed = parsePatch(patch, fileId);
                    check(parsed.hunks.length > 0 || /^(old mode|new mode|new file mode|deleted file mode|rename from|copy from|similarity index|index) /m.test(patch),
                        'Diff contains neither text hunks nor file-change metadata.', 'invalid_diff');
                }
                const bytes = Buffer.byteLength(JSON.stringify(parsed));
                if (total + bytes > MAX_SNAPSHOT_BYTES) file.omission = 'Snapshot text budget reached.';
                else {
                    total += bytes;
                    file.hunks = parsed.hunks;
                    file.evidencePath = `snapshots/${snapshotId}/files/${fileId}.json`;
                    evidence.set(file.evidencePath, { schemaVersion: 1, snapshotId, fileId, lines: parsed.lines });
                }
            } catch (error) {
                if (!['source_too_large', 'unsupported_text', 'path_outside', 'invalid_path', 'ELOOP'].includes(error.code)) throw error;
                file.omission = `Preview unavailable (${error.code}).`;
            }
        }
        files.push(file);
    }
    if (target.kind === 'local') {
        const afterListing = await inventory(repository, target, git);
        const after = await localFingerprint(repository, target, afterListing, git);
        check(before === after && target.head === await commit(repository, 'HEAD', git), 'Worktree or index changed during capture; retry on a stable surface.', 'source_changed');
        target.fingerprint = digest(stableJson({ files: listing.files, lines: [...evidence.values()].map((entry) => entry.lines) }));
    } else if (target.kind === 'selected') {
        for (const entry of selectedReads) check(digest(await readText(repository, entry.path, MAX_FILE_BYTES)) === entry.digest, 'Selected source changed during capture.', 'source_changed');
        target.fingerprint = digest(stableJson({ selection: target.selection, lines: [...evidence.values()].map((entry) => entry.lines) }));
    }
    const snapshot = {
        schemaVersion: 1, reviewId, snapshotId, capturedAt: new Date().toISOString(), repository, target, files,
        discussion: request.discussion ?? { status: target.kind === 'pr' ? 'unavailable' : 'not_applicable', items: [], limitations: target.kind === 'pr' ? ['Provider discussion was not supplied.'] : [] },
        metadata: request.metadata ?? { status: target.kind === 'pr' ? 'unavailable' : 'not_applicable', fields: [] },
        omissions: files.filter((file) => file.omission).map((file) => `${file.newPath ?? file.oldPath}: ${file.omission}`),
    };
    validateSnapshot(snapshot);
    return { snapshot, evidence };
}

export async function captureReview(repository, request, relative, expectedRevision, git = gitCommand) {
    const root = await fs.realpath(repository);
    const reviewId = relative ? path.posix.basename(relative) : `review-${randomUUID()}`;
    const destination = relative ?? `.copilot-tracking/reviews/code-reviews/${new Date().toISOString().slice(0, 10)}/${reviewId}`;
    const location = await reviewRoot(root, destination, true);
    return withLock(location.root, 'review-state.json', async () => {
        let previous;
        if (await exists(location.root, 'review-state.json')) {
            previous = await loadReview(location);
            check(previous.state.revision === expectedRevision, 'Reload the current revision before taking a new snapshot.', 'revision_conflict');
        }
        const captured = await captureSnapshot(root, reviewId, request, git);
        for (const [name, value] of captured.evidence) await writeJson(location.root, name, value, true);
        await writeJson(location.root, `snapshots/${captured.snapshot.snapshotId}/snapshot.json`, captured.snapshot, true);
        if (previous) await writeJson(location.root, `snapshots/${previous.snapshot.snapshotId}/state-${previous.state.revision}.json`, previous.state, true);
        const state = initialState(captured.snapshot);
        state.revision = previous ? previous.state.revision + 1 : 0;
        await writeJson(location.root, 'review-state.json', state);
        return { ...location, state, snapshot: captured.snapshot };
    });
}
