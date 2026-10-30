// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';

/** Crockford base32: digits and capitals without I, L, O, or U, so a handle reads aloud cleanly. */
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const SHORTEST = 4;
const LONGEST = 8;

/**
 * A short handle for a canvas instance, such as `K7QF`, that people and agents can use to
 * tell canvases apart. The same instance ID always yields the same handle. When another
 * open instance holds it, the handle grows by a character, up to eight, and is then
 * numbered.
 *
 * @param {string} instanceId
 * @param {Iterable<string>} [taken] Handles held by other open instances.
 * @returns {string}
 */
export function canvasHandle(instanceId, taken = []) {
    const used = new Set(taken);
    const digest = createHash('sha256').update(String(instanceId)).digest();
    let code = '';
    let value = 0;
    let bits = 0;
    for (const byte of digest) {
        value = (value << 8) | byte;
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            code += ALPHABET[(value >> bits) & 31];
        }
        value &= (1 << bits) - 1;
        if (code.length >= LONGEST) break;
    }
    code = code.slice(0, LONGEST);
    for (let length = SHORTEST; length <= LONGEST; length += 1) {
        const candidate = code.slice(0, length);
        if (!used.has(candidate)) return candidate;
    }
    for (let suffix = 2; ; suffix += 1) {
        const candidate = `${code}-${suffix}`;
        if (!used.has(candidate)) return candidate;
    }
}
