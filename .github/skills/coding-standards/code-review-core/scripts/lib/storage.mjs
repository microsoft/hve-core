// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { constants } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { check, relativePath, ReviewError, validateState } from './model.mjs';

export const MAX_RECORD_BYTES = 8 * 1024 * 1024;
export const REVIEW_PREFIX = '.copilot-tracking/reviews/code-reviews/';
export const digest = (value) => createHash('sha256').update(value).digest('hex');
const inside = (root, target) => {
    const relative = path.relative(root, target);
    return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
};

/** Resolve every component without accepting a symlink, including for new writes. */
export async function containedPath(root, relative, createParents = false) {
    relativePath(relative);
    const base = await fs.realpath(root);
    let current = base;
    const parts = relative.split('/');
    for (let index = 0; index < parts.length; index++) {
        current = path.join(current, parts[index]);
        let stat;
        try {
            stat = await fs.lstat(current);
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
            if (index === parts.length - 1) return current;
            check(createParents, `Missing parent of ${relative}.`, 'source_missing');
            try {
                await fs.mkdir(current, { mode: 0o700 });
            } catch (mkdirError) {
                if (mkdirError.code !== 'EEXIST') throw mkdirError;
            }
            stat = await fs.lstat(current);
        }
        check(!stat.isSymbolicLink(), `Symlink access refused: ${relative}.`, 'path_outside');
        check(inside(base, await fs.realpath(current)), 'Path escaped its root.', 'path_outside');
        if (index < parts.length - 1) check(stat.isDirectory(), 'A path parent is not a directory.', 'invalid_path');
    }
    return current;
}

export async function reviewRoot(repository, relative, create = false) {
    const root = await fs.realpath(repository);
    check(typeof relative === 'string' && /^\.copilot-tracking\/reviews\/code-reviews\/\d{4}-\d{2}-\d{2}\/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(relative),
        'Use a dated, uniquely identified review directory.', 'invalid_path');
    const absolute = await containedPath(root, `${relative}/review-state.json`, create);
    return { repository: root, relative, root: path.dirname(absolute) };
}

export async function readText(root, relative, limit = MAX_RECORD_BYTES) {
    const file = await containedPath(root, relative);
    const handle = await fs.open(file, constants.O_RDONLY | constants.O_NOFOLLOW);
    try {
        const stat = await handle.stat();
        check(stat.isFile() && stat.nlink === 1, 'Only regular, singly linked files can be read.', 'invalid_path');
        check(stat.size <= limit, `File exceeds the ${limit}-byte read budget: ${relative}.`, 'source_too_large');
        const buffer = Buffer.alloc(limit + 1);
        let used = 0;
        while (used < buffer.length) {
            const { bytesRead } = await handle.read(buffer, used, buffer.length - used, used);
            if (!bytesRead) break;
            used += bytesRead;
        }
        check(used <= limit, 'File grew beyond the read budget.', 'source_too_large');
        try {
            return new TextDecoder('utf-8', { fatal: true }).decode(buffer.subarray(0, used));
        } catch {
            throw new ReviewError('unsupported_text', 'File is not UTF-8 text.');
        }
    } finally {
        await handle.close();
    }
}

export async function readJson(root, relative) {
    const raw = await readText(root, relative);
    try {
        return JSON.parse(raw);
    } catch {
        throw new ReviewError('corrupt_record', `Invalid JSON in ${relative}; the file was left unchanged.`);
    }
}

export async function exists(root, relative) {
    try {
        await fs.lstat(await containedPath(root, relative));
        return true;
    } catch (error) {
        if (error.code === 'ENOENT' || error.code === 'source_missing') return false;
        throw error;
    }
}

export async function writeText(root, relative, value, exclusive = false) {
    check(Buffer.byteLength(value) <= MAX_RECORD_BYTES, 'Output exceeds the record budget.', 'source_too_large');
    const destination = await containedPath(root, relative, true);
    if (exclusive) {
        await fs.writeFile(destination, value, { flag: 'wx', mode: 0o600 });
        return;
    }
    const temporary = `${relative}.${randomUUID()}.tmp`;
    const temp = await containedPath(root, temporary);
    try {
        await fs.writeFile(temp, value, { flag: 'wx', mode: 0o600 });
        await containedPath(root, relative);
        await fs.rename(temp, destination);
    } finally {
        await fs.rm(temp, { force: true });
    }
}

export const writeJson = (root, relative, value, exclusive = false) => writeText(root, relative, `${JSON.stringify(value, null, 2)}\n`, exclusive);

/** A cooperative cross-process lock; abandoned locks require explicit operator recovery. */
export async function withLock(root, file, action) {
    const lock = await containedPath(root, `${file}.lock`, true);
    let handle;
    try {
        handle = await fs.open(lock, 'wx', 0o600);
    } catch (error) {
        if (error.code === 'EEXIST') throw new ReviewError('storage_busy', `${file} is locked. Retry after the writer finishes; do not remove a live writer's lock.`);
        throw error;
    }
    try {
        await handle.writeFile(JSON.stringify({ pid: process.pid, token: randomUUID() }));
        return await action();
    } finally {
        await handle.close();
        await fs.rm(lock);
    }
}

export async function loadReview(location) {
    const state = await readJson(location.root, 'review-state.json');
    relativePath(state.snapshotPath, 'snapshot path');
    const snapshot = await readJson(location.root, state.snapshotPath);
    validateState(state, snapshot);
    check(snapshot.repository === location.repository && state.reviewId === path.basename(location.root), 'Review repository or directory identity does not match.', 'identity_mismatch');
    return { state, snapshot };
}

export async function updateState(location, expectedRevision, action) {
    check(Number.isSafeInteger(expectedRevision) && expectedRevision >= 0, 'An expected state revision is required.', 'invalid_input');
    return withLock(location.root, 'review-state.json', async () => {
        const { state, snapshot } = await loadReview(location);
        check(state.revision === expectedRevision, 'State changed. Reload before applying the decision.', 'revision_conflict');
        const next = await action(structuredClone(state), snapshot);
        validateState(next, snapshot);
        if (JSON.stringify(next) !== JSON.stringify(state)) {
            next.revision = state.revision + 1;
            await writeJson(location.root, 'review-state.json', next);
        }
        return next;
    });
}
