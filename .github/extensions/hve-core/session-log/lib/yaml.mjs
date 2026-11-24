// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

const KEY_RE = /^([A-Za-z_][A-Za-z0-9_-]*):(?:\s(.*))?$/;

/**
 * Parses the flat, single-level YAML that Copilot writes to `workspace.yaml`.
 *
 * Supports plain and quoted scalars plus `|`, `|-`, `>`, and `>-` block scalars.
 * Nested mappings and sequences are not part of the format and are ignored.
 *
 * @param {string} text YAML text.
 * @returns {Record<string, string | boolean | null>} Parsed keys.
 */
export function parseFlatYaml(text) {
    /** @type {Record<string, string | boolean | null>} */
    const result = {};
    if (typeof text !== 'string' || text.length === 0) {
        return result;
    }
    const lines = text.replace(/\r\n?/g, '\n').split('\n');
    let index = 0;
    while (index < lines.length) {
        const line = lines[index];
        const match = KEY_RE.exec(line);
        index += 1;
        if (!match) {
            continue;
        }
        const key = match[1];
        const raw = (match[2] ?? '').trim();
        const block = /^([|>])([+-]?)$/.exec(raw);
        if (block) {
            const collected = [];
            let indent = -1;
            while (index < lines.length) {
                const next = lines[index];
                if (next.trim().length === 0) {
                    collected.push('');
                    index += 1;
                    continue;
                }
                const leading = next.length - next.trimStart().length;
                if (leading === 0) {
                    break;
                }
                if (indent < 0) {
                    indent = leading;
                }
                collected.push(next.slice(Math.min(indent, leading)));
                index += 1;
            }
            while (block[2] !== '+' && collected.length > 0 && collected[collected.length - 1] === '') {
                collected.pop();
            }
            let value = block[1] === '>' ? collected.join(' ').replace(/ {2,}/g, ' ') : collected.join('\n');
            if (block[2] === '') {
                value += '\n';
            }
            result[key] = value;
            continue;
        }
        result[key] = parseScalar(raw);
    }
    return result;
}

/**
 * @param {string} raw
 * @returns {string | boolean | null}
 */
function parseScalar(raw) {
    if (raw === '' || raw === '~' || raw === 'null') {
        return null;
    }
    if (raw === 'true') {
        return true;
    }
    if (raw === 'false') {
        return false;
    }
    if (raw.length >= 2 && raw.startsWith("'") && raw.endsWith("'")) {
        return raw.slice(1, -1).replace(/''/g, "'");
    }
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
        try {
            return JSON.parse(raw);
        } catch {
            return raw.slice(1, -1);
        }
    }
    return raw;
}
