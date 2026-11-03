// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/** Above this many comparison cells the diff replaces every line instead; correct, if not minimal. */
const MAX_CELLS = 1_000_000;

/**
 * Line operations that turn `before` into `after`: `' '` keeps a line, `'-'` removes it,
 * and `'+'` adds it. Removals come before additions within a change.
 *
 * @param {string} before
 * @param {string} after
 * @returns {{ type: ' ' | '-' | '+', text: string }[]}
 */
export function lineDiff(before, after) {
    const a = String(before).split('\n');
    const b = String(after).split('\n');
    let start = 0;
    while (start < a.length && start < b.length && a[start] === b[start]) start += 1;
    let endA = a.length;
    let endB = b.length;
    while (endA > start && endB > start && a[endA - 1] === b[endB - 1]) {
        endA -= 1;
        endB -= 1;
    }
    const keep = (text) => ({ type: /** @type {' '} */ (' '), text });
    return [
        ...a.slice(0, start).map(keep),
        ...middle(a.slice(start, endA), b.slice(start, endB)),
        ...a.slice(endA).map(keep),
    ];
}

function middle(a, b) {
    const removeAll = a.map((text) => ({ type: '-', text }));
    const addAll = b.map((text) => ({ type: '+', text }));
    if (a.length === 0 || b.length === 0 || a.length * b.length > MAX_CELLS) {
        return [...removeAll, ...addAll];
    }
    const n = a.length;
    const m = b.length;
    const width = m + 1;
    // Longest common subsequence lengths of every suffix pair.
    const table = new Uint32Array((n + 1) * width);
    for (let i = n - 1; i >= 0; i -= 1) {
        for (let j = m - 1; j >= 0; j -= 1) {
            table[i * width + j] = a[i] === b[j]
                ? table[(i + 1) * width + j + 1] + 1
                : Math.max(table[(i + 1) * width + j], table[i * width + j + 1]);
        }
    }
    const ops = [];
    let i = 0;
    let j = 0;
    while (i < n && j < m) {
        if (a[i] === b[j]) {
            ops.push({ type: ' ', text: a[i] });
            i += 1;
            j += 1;
        } else if (table[(i + 1) * width + j] >= table[i * width + j + 1]) {
            ops.push({ type: '-', text: a[i] });
            i += 1;
        } else {
            ops.push({ type: '+', text: b[j] });
            j += 1;
        }
    }
    while (i < n) ops.push({ type: '-', text: a[i++] });
    while (j < m) ops.push({ type: '+', text: b[j++] });
    return ops;
}

/**
 * A unified diff of two texts: `@@ -start,count +start,count @@` hunks with `context`
 * unchanged lines around each change, and the number of lines added and removed. Equal
 * texts give empty text.
 *
 * @param {string} before
 * @param {string} after
 * @param {{ context?: number }} [options]
 * @returns {{ text: string, added: number, removed: number }}
 */
export function unifiedDiff(before, after, options = {}) {
    const context = options.context ?? 2;
    let aLine = 1;
    let bLine = 1;
    let added = 0;
    let removed = 0;
    const ops = lineDiff(before, after).map((op) => {
        const entry = { ...op, a: aLine, b: bLine };
        if (op.type !== '+') aLine += 1;
        if (op.type !== '-') bLine += 1;
        if (op.type === '+') added += 1;
        if (op.type === '-') removed += 1;
        return entry;
    });
    const ranges = [];
    ops.forEach((op, index) => {
        if (op.type === ' ') return;
        const lo = Math.max(0, index - context);
        const hi = Math.min(ops.length - 1, index + context);
        const last = ranges.at(-1);
        if (last && lo <= last.hi + 1) last.hi = Math.max(last.hi, hi);
        else ranges.push({ lo, hi });
    });
    const lines = [];
    for (const { lo, hi } of ranges) {
        const slice = ops.slice(lo, hi + 1);
        const fromA = slice.filter((op) => op.type !== '+');
        const fromB = slice.filter((op) => op.type !== '-');
        const aStart = fromA.length ? fromA[0].a : slice[0].a - 1;
        const bStart = fromB.length ? fromB[0].b : slice[0].b - 1;
        lines.push(`@@ -${aStart},${fromA.length} +${bStart},${fromB.length} @@`);
        for (const op of slice) lines.push(`${op.type}${op.text}`);
    }
    return { text: lines.join('\n'), added, removed };
}
