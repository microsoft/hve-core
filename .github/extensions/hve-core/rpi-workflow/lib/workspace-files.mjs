// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import path from 'node:path';

import { atxHeading } from './source/markdown.mjs';

/**
 * Read-only access to workspace files for the source view and the editor route. A path must
 * be workspace-relative and resolve to a regular file inside the workspace. The canvas never
 * reads `.git` or credential folders, secret-looking files, symbolic links, binaries, or
 * files over 1 MB.
 */

export const MAX_SOURCE_BYTES = 1024 * 1024;
export const MAX_SOURCE_LINES = 5000;
const MAX_PATH_LENGTH = 1024;
const MAX_ANCHOR_LENGTH = 200;
const BINARY_PROBE_BYTES = 8192;
const BLOCKED_FOLDERS = new Set(['.git', '.ssh', '.aws', '.azure', '.gnupg']);
const SECRET_NAMES = [/^\.env(?:\..*)?$/i, /\.(?:pem|key|p12|pfx|jks|keystore)$/i, /^id_(?:rsa|ed25519)/i, /^\.(?:npmrc|pypirc|netrc|git-credentials)$/i];

/** A refusal with a stable code and a message written for the reader. */
export class FileError extends Error {
    /**
     * @param {'source_invalid' | 'source_outside' | 'source_blocked' | 'source_not_found' | 'source_too_large' | 'source_binary'} code
     * @param {string} message
     */
    constructor(code, message) {
        super(message);
        this.code = code;
    }
}

const toPosix = (value) => value.split(path.sep).join('/');
const isInside = (base, target) => {
    const relative = path.relative(base, target);
    return relative !== '' && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
};
const blockedFolder = (segments) => segments.some((segment) => BLOCKED_FOLDERS.has(segment.toLowerCase()));
const secretName = (name) => SECRET_NAMES.some((pattern) => pattern.test(name));

/**
 * Checks a workspace-relative path without touching the disk, returning its segments.
 *
 * @param {unknown} target
 */
export function checkWorkspacePath(target) {
    if (typeof target !== 'string' || !target.trim() || target.length > MAX_PATH_LENGTH || target.includes('\0')) {
        throw new FileError('source_invalid', 'A workspace-relative file path is required.');
    }
    const normalized = target.trim().replace(/\\/g, '/');
    if (normalized.startsWith('/') || /^[A-Za-z]:/.test(normalized)) {
        throw new FileError('source_invalid', `${target} is not a workspace-relative path.`);
    }
    const segments = normalized.split('/').filter((part) => part && part !== '.');
    if (!segments.length) throw new FileError('source_invalid', 'A workspace-relative file path is required.');
    if (segments.includes('..')) throw new FileError('source_outside', `${target} reaches outside the workspace.`);
    // A colon names a drive or a Windows alternate data stream, never a workspace file.
    if (segments.some((segment) => segment.includes(':'))) throw new FileError('source_invalid', `${target} is not a workspace-relative path.`);
    if (blockedFolder(segments)) throw new FileError('source_blocked', `${target} is in a folder the canvas never reads.`);
    if (secretName(segments.at(-1))) {
        throw new FileError('source_blocked', `${target} looks like it holds secrets, so the canvas does not show it.`);
    }
    return segments;
}

/**
 * Resolves a workspace-relative path to a regular file inside the workspace.
 *
 * @param {string} root workspace root
 * @param {unknown} target
 * @returns {Promise<{ path: string, absolute: string, size: number }>}
 */
export async function resolveWorkspaceFile(root, target) {
    const segments = checkWorkspacePath(target);
    const absolute = path.resolve(root, ...segments);
    const stat = await fs.lstat(absolute).catch(() => {
        throw new FileError('source_not_found', `${target} is not a file in this workspace.`);
    });
    if (stat.isSymbolicLink()) throw new FileError('source_blocked', `${target} is a symbolic link, which the canvas does not follow.`);
    if (!stat.isFile()) throw new FileError('source_invalid', `${target} is not a file.`);
    const realRoot = await fs.realpath(root);
    const real = await fs.realpath(absolute);
    // A linked parent folder could lead outside the workspace or into a blocked folder.
    if (!isInside(realRoot, real)) throw new FileError('source_outside', `${target} is outside the workspace.`);
    const relative = toPosix(path.relative(realRoot, real));
    // The real path can differ from the one given, as with Windows short names or trailing dots.
    if (blockedFolder(relative.split('/'))) throw new FileError('source_blocked', `${target} is in a folder the canvas never reads.`);
    if (secretName(path.basename(real))) throw new FileError('source_blocked', `${target} looks like it holds secrets, so the canvas does not show it.`);
    if (stat.size > MAX_SOURCE_BYTES) throw new FileError('source_too_large', `${target} is larger than 1 MB, so the canvas does not show it.`);
    return { path: relative, absolute: real, size: stat.size };
}

const escapeRegExp = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
/** A heading's text without list-marker boxes, backticks, or emphasis, for matching. */
const headingText = (line) => {
    const heading = atxHeading(line, 3);
    return heading ? heading.title.replace(/^\[[ xX]\]\s*/, '').replace(/[`*_]/g, '').trim() : null;
};
/** GitHub-style heading slug, as Markdown link fragments use. */
const slugOf = (text) => text.toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').trim().replace(/\s/g, '-');

/**
 * The line a cited anchor points at: a `#fragment`, a heading, a definition, or the first
 * mention. Returns a 1-based line and how it was found.
 *
 * @param {string[]} lines
 * @param {unknown} anchor
 * @returns {{ line: number | null, match: 'fragment' | 'heading' | 'definition' | 'text' | 'none' | 'not-found' }}
 */
export function findLine(lines, anchor) {
    const raw = typeof anchor === 'string' ? anchor.trim() : '';
    if (!raw) return { line: null, match: 'none' };
    const headings = lines.map(headingText);
    if (raw.startsWith('#')) {
        let wanted;
        try {
            wanted = decodeURIComponent(raw.slice(1)).toLowerCase();
        } catch {
            wanted = raw.slice(1).toLowerCase();
        }
        const index = headings.findIndex((text) => text !== null && slugOf(text) === wanted);
        if (index !== -1) return { line: index + 1, match: 'fragment' };
    }
    // A fragment that names no heading, such as an element ID, is looked up as text.
    const text = raw.replace(/^`+|`+$/g, '').replace(/^#/, '').trim();
    if (!text) return { line: null, match: 'not-found' };
    const lower = text.toLowerCase();
    const exact = headings.findIndex((heading) => heading !== null && heading.toLowerCase() === lower);
    if (exact !== -1) return { line: exact + 1, match: 'heading' };
    const within = headings.findIndex((heading) => heading !== null && heading.toLowerCase().includes(lower));
    if (within !== -1) return { line: within + 1, match: 'heading' };
    // "Flow step 3" points into the Flow section.
    let prefix = -1;
    headings.forEach((heading, index) => {
        if (heading && heading.length >= 3 && lower.startsWith(heading.toLowerCase()) && (prefix === -1 || heading.length > headings[prefix].length)) prefix = index;
    });
    if (prefix !== -1) return { line: prefix + 1, match: 'heading' };
    if (/^[\w$.-]+$/.test(text)) {
        const name = escapeRegExp(text.split('.').at(-1));
        const definitions = [
            new RegExp(`^\\s*(?:export\\s+)?(?:default\\s+)?(?:async\\s+)?(?:function\\*?|const|let|var|class|def|interface|type|enum|struct|fn|func)\\s+${name}\\b`),
            new RegExp(`^\\s*(?:async\\s+)?${name}\\s*\\([^)]*\\)\\s*\\{`),
            new RegExp(`(?:^|[\\s{,])['"]?${name}['"]?\\s*(?:=(?!=)|:)`),
        ];
        for (const pattern of definitions) {
            const index = lines.findIndex((line) => pattern.test(line));
            if (index !== -1) return { line: index + 1, match: 'definition' };
        }
        const word = new RegExp(`(?:^|[^\\w$])${escapeRegExp(text)}(?![\\w$])`);
        const mention = lines.findIndex((line) => word.test(line));
        if (mention !== -1) return { line: mention + 1, match: 'text' };
    }
    const loose = lines.findIndex((line) => line.toLowerCase().includes(lower));
    return loose === -1 ? { line: null, match: 'not-found' } : { line: loose + 1, match: 'text' };
}

/**
 * Reads a workspace file around a cited anchor: at most 5,000 lines centered on the line the
 * anchor finds, or the top of the file when it finds none.
 *
 * @param {string} root workspace root
 * @param {unknown} target workspace-relative path
 * @param {unknown} [anchor] heading, symbol, or `#fragment`
 */
export async function readWorkspaceFile(root, target, anchor) {
    if (anchor !== undefined && anchor !== null && (typeof anchor !== 'string' || anchor.length > MAX_ANCHOR_LENGTH)) {
        throw new FileError('source_invalid', `An anchor is a heading, symbol, or #fragment of at most ${MAX_ANCHOR_LENGTH} characters.`);
    }
    const file = await resolveWorkspaceFile(root, target);
    const buffer = await fs.readFile(file.absolute);
    if (buffer.length > MAX_SOURCE_BYTES) throw new FileError('source_too_large', `${file.path} is larger than 1 MB, so the canvas does not show it.`);
    if (buffer.subarray(0, BINARY_PROBE_BYTES).includes(0)) throw new FileError('source_binary', `${file.path} is not a text file.`);
    const lines = buffer.toString('utf8').split(/\r\n|\r|\n/);
    if (lines.length > 1 && lines.at(-1) === '') lines.pop();
    const found = findLine(lines, anchor);
    const line = found.line ?? 1;
    const start = Math.max(1, Math.min(line - Math.floor(MAX_SOURCE_LINES / 2), lines.length - MAX_SOURCE_LINES + 1));
    const end = Math.min(lines.length, start + MAX_SOURCE_LINES - 1);
    return { path: file.path, absolute: file.absolute, total: lines.length, start, lines: lines.slice(start - 1, end), line, match: found.match, anchor: typeof anchor === 'string' && anchor.trim() ? anchor.trim() : null };
}
