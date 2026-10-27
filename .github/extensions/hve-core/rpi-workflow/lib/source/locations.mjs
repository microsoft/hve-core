// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import path from 'node:path';

/**
 * Reads where a code evidence row points: each location is a workspace-relative path and an
 * optional anchor, a heading or symbol. Research writes one location as a path followed by
 * its heading or symbol in backticks, with several locations separated by semicolons.
 */

const MAX_ANCHOR = 80;
/** A Source cell is read up to this length; real cells are a few hundred characters. */
const MAX_CELL = 4000;
const KNOWN_EXTENSIONS = new Set(['md', 'mdx', 'mjs', 'cjs', 'js', 'jsx', 'ts', 'tsx', 'mts', 'cts', 'json', 'jsonc', 'yml', 'yaml', 'toml', 'ps1', 'psm1', 'psd1', 'py', 'sh', 'cs', 'csproj', 'rs', 'go', 'java', 'kt', 'rb', 'php', 'html', 'css', 'scss', 'txt', 'xml', 'bicep', 'bicepparam', 'tf', 'tfvars', 'sql', 'ipynb', 'lock', 'cfg', 'ini', 'svg']);
// Bounded lengths keep a long run of brackets from stalling the scan.
const LINK_RE = /\[([^\]\n]{0,500})\]\(([^)\s]{1,1000})\)/;
const CODE_RE = /`([^`\n]+)`/g;

/** Removes `leading` characters from the start and `trailing` ones from the end with a scan, not a backtracking pattern. */
function trimChars(text, leading, trailing) {
    let start = 0;
    let end = text.length;
    while (start < end && leading.includes(text[start])) start += 1;
    while (end > start && trailing.includes(text[end - 1])) end -= 1;
    return text.slice(start, end);
}

const trimToken = (token) => trimChars(token, '(`\'"', ')`\'",.:;');

/**
 * True when a token reads as a file path rather than a word, a phrase such as read/write, or
 * a version number: a quoted token with a slash or an extension, or a bare one ending in a
 * file name with an extension. A glob such as `schemas/*.json` names a set of files, not one.
 */
function pathLike(token, quoted) {
    if (!token || token.includes('://') || /[\s*?[\]{}]/.test(token) || !/[\w-]/.test(token)) return false;
    const name = trimChars(token, '', '/').split('/').at(-1);
    const extension = /\.([A-Za-z][A-Za-z0-9]{0,9})$/.exec(name)?.[1]?.toLowerCase();
    if (token.includes('/')) return quoted || Boolean(extension);
    return Boolean(extension) && /^[\w.@~+-]+$/.test(token) && (quoted || KNOWN_EXTENSIONS.has(extension));
}

const normalize = (value) => {
    const normal = path.posix.normalize(value.replace(/\\/g, '/')).replace(/^\.\//, '');
    const trimmed = trimChars(normal, '', '/');
    return trimmed || normal;
};

/**
 * @param {unknown} raw the Source or location cell
 * @param {string} [baseDir] workspace-relative folder of the artifact, for relative links
 * @returns {{ path: string, anchor: string | null }[]}
 */
export function sourceLocations(raw, baseDir = '') {
    const locations = [];
    for (const part of String(raw ?? '').slice(0, MAX_CELL).split(';')) {
        const piece = part.trim();
        if (!piece) continue;
        let found = null;
        let rest = piece;
        let fragment = null;
        const link = LINK_RE.exec(piece);
        if (link && !/^[a-z][\w+.-]*:/i.test(link[2])) {
            const [target, hash] = link[2].split('#');
            if (target) {
                let decoded = target;
                try {
                    decoded = decodeURI(target);
                } catch {
                    decoded = target;
                }
                found = normalize(path.posix.join(baseDir, decoded));
                fragment = hash ? `#${hash}` : null;
                rest = `${piece.slice(0, link.index)} ${piece.slice(link.index + link[0].length)}`;
            }
        }
        if (!found) {
            const quoted = new Set([...piece.matchAll(CODE_RE)].map((match) => match[1].trim()));
            const token = piece.split(/\s+/).map((word) => ({ word, value: trimToken(word) })).find(({ value }) => pathLike(value, quoted.has(value)));
            if (!token) continue;
            found = normalize(token.value);
            rest = piece.replace(token.word, ' ');
        }
        const code = [...rest.matchAll(CODE_RE)].map((match) => match[1].trim()).find((value) => value && value !== found);
        const words = rest.replace(CODE_RE, ' ').replace(/[()]/g, ' ').replace(/\s+/g, ' ').trim().replace(/^[:,\-–—]\s*/, '');
        const anchor = code ?? fragment ?? (words ? words.slice(0, MAX_ANCHOR) : null);
        locations.push({ path: found, anchor: anchor || null });
    }
    return locations;
}
