// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Structure helpers for RPI tracking artifacts: a fence-aware heading tree, labeled
 * fields, pipe tables, rpi markers, fenced blocks, links, list items, and ID lists.
 * Pure and SDK-free; every helper takes Markdown text and returns plain values. Text
 * inside fenced code never counts as structure.
 */

const FENCE_RE = /^\s{0,12}(`{3,}|~{3,})(.*)$/;
const MARKER_RE = /^<!--\s*rpi:([a-z][a-z-]{0,30})\s+id=([A-Za-z0-9._-]{1,80})\s*-->$/;
const BULLET_FIELD_RE = /^[*-]\s+([A-Z][^:\n]{0,80}?):(?:\s+(.*))?$/;
const LINE_FIELD_RE = /^([A-Z][A-Za-z0-9 ,'()/-]{0,80}?):(?:\s+(.*))?$/;
const TABLE_DELIM_RE = /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$/;
const ID_TOKEN = String.raw`(?:P\d{2}-T\d{2}|P\d{2}|[A-Z]{1,3}-\d{3}|[A-Z]{1,3}\d{1,3})`;
const ID_RANGE_RE = new RegExp(String.raw`\b(${ID_TOKEN})(?:\s+(?:to|through)\s+(${ID_TOKEN}))?\b`, 'g');
const MAX_RANGE = 200;

/** Normalizes a label for lookup: lowercase with single spaces. */
export const labelKey = (label) => String(label ?? '').trim().toLowerCase().replace(/\s+/g, ' ');

/**
 * Splits text into lines and marks which ones are fenced code, including the fence lines.
 *
 * @param {string} text
 * @returns {{ lines: string[], fenced: boolean[] }}
 */
export function scanLines(text) {
    const lines = String(text ?? '').replace(/\r\n?/g, '\n').split('\n');
    const fenced = new Array(lines.length).fill(false);
    let open = null;
    for (let i = 0; i < lines.length; i += 1) {
        const match = FENCE_RE.exec(lines[i]);
        if (open) {
            fenced[i] = true;
            if (match && match[1][0] === open[0] && match[1].length >= open.length && match[2].trim() === '') {
                open = null;
            }
        } else if (match) {
            fenced[i] = true;
            open = match[1];
        }
    }
    return { lines, fenced };
}

const isSpace = (ch) => ch !== undefined && /\s/.test(ch);

/**
 * An ATX heading's level and text, or null: up to `maxIndent` leading spaces, one to six `#`,
 * whitespace, then the text without trailing whitespace and closing `#`s. It scans each
 * character a bounded number of times, so long lines cannot stall it.
 *
 * @param {string} line
 * @param {number} [maxIndent]
 * @returns {{ level: number, title: string } | null}
 */
export function atxHeading(line, maxIndent = 0) {
    let at = 0;
    while (at < maxIndent && isSpace(line[at])) at += 1;
    let level = 0;
    while (line[at + level] === '#') level += 1;
    if (level < 1 || level > 6 || !isSpace(line[at + level])) return null;
    let start = at + level;
    while (start < line.length && isSpace(line[start])) start += 1;
    let end = line.length;
    while (end > start && isSpace(line[end - 1])) end -= 1;
    while (end > start && line[end - 1] === '#') end -= 1;
    while (end > start && isSpace(line[end - 1])) end -= 1;
    return { level, title: line.slice(start, end) };
}

/**
 * Parses a document into lines and headings. Each heading records where its section
 * ends, and its `marker` is the rpi marker on the line directly above it, when present.
 *
 * @param {string} text
 */
export function parseDocument(text) {
    const { lines, fenced } = scanLines(text);
    const headings = [];
    for (let i = 0; i < lines.length; i += 1) {
        if (fenced[i]) continue;
        const heading = atxHeading(lines[i]);
        if (!heading) continue;
        const above = i > 0 && !fenced[i - 1] ? MARKER_RE.exec(lines[i - 1].trim()) : null;
        headings.push({ level: heading.level, title: heading.title, line: i, end: lines.length, index: headings.length, marker: above ? { kind: above[1], id: above[2] } : null });
    }
    const open = [];
    for (const heading of headings) {
        while (open.length && open[open.length - 1].level >= heading.level) {
            open.pop().end = heading.line;
        }
        open.push(heading);
    }
    return { lines, fenced, headings };
}

/** The document's first H1 title, or an empty string. */
export function titleOf(doc) {
    return doc.headings.find((heading) => heading.level === 1)?.title ?? '';
}

/**
 * Sections at one level, optionally inside a parent section.
 *
 * @param {ReturnType<typeof parseDocument>} doc
 * @param {number} level
 * @param {{ line: number, end: number } | null} [within]
 */
export function sectionsAt(doc, level, within = null) {
    return doc.headings.filter((heading) => heading.level === level && (!within || (heading.line > within.line && heading.line < within.end)));
}

/**
 * Finds the first section whose title matches, ignoring case. Matches the whole title
 * unless `prefix` is set.
 *
 * @param {ReturnType<typeof parseDocument>} doc
 * @param {string} title
 * @param {{ level?: number, within?: { line: number, end: number } | null, prefix?: boolean }} [options]
 */
export function findSection(doc, title, options = {}) {
    const wanted = labelKey(title);
    return doc.headings.find((heading) => {
        if (options.level !== undefined && heading.level !== options.level) return false;
        if (options.within && !(heading.line > options.within.line && heading.line < options.within.end)) return false;
        const key = labelKey(heading.title);
        return options.prefix ? key.startsWith(wanted) : key === wanted;
    }) ?? null;
}

/**
 * Markdown between a heading and the end of its section. With `own: true` it stops at the
 * first subheading. Leading and trailing blank lines and trailing rpi markers are trimmed.
 *
 * @param {ReturnType<typeof parseDocument>} doc
 * @param {{ line: number, end: number }} section
 * @param {{ own?: boolean }} [options]
 */
export function bodyOf(doc, section, options = {}) {
    let end = section.end;
    if (options.own) {
        const child = doc.headings.find((heading) => heading.line > section.line && heading.line < section.end);
        if (child) end = child.line;
    }
    const slice = doc.lines.slice(section.line + 1, end);
    while (slice.length && (slice[slice.length - 1].trim() === '' || MARKER_RE.test(slice[slice.length - 1].trim()))) slice.pop();
    while (slice.length && slice[0].trim() === '') slice.shift();
    return slice.join('\n');
}

const indentOf = (line) => {
    let count = 0;
    while (count < line.length && line[count] === ' ') count += 1;
    return count;
};

/** Removes up to `amount` leading spaces from every line. */
function dedent(lines, amount) {
    return lines.map((line) => line.slice(Math.min(amount, indentOf(line))));
}

const nextNonBlank = (lines, from) => {
    for (let k = from; k < lines.length; k += 1) {
        if (lines[k].trim() !== '') return lines[k];
    }
    return undefined;
};

/**
 * Reads labeled fields from a block of Markdown. Two forms count: a top-level bullet
 * `* Label: value`, whose continuation and nested lines belong to it, and a top-level
 * line `Label:` (or `Label: value`) followed by its bullets. Returns a map from the
 * normalized label to `{ label, value }`; the first occurrence of a label wins.
 *
 * @param {string} block
 * @returns {Map<string, { label: string, value: string }>}
 */
export function labeledFields(block) {
    const { lines, fenced } = scanLines(block);
    const fields = new Map();
    let i = 0;
    while (i < lines.length) {
        const line = lines[i];
        if (fenced[i] || indentOf(line) > 0 || line.trim() === '') {
            i += 1;
            continue;
        }
        const bullet = BULLET_FIELD_RE.exec(line);
        const standalone = bullet ? null : LINE_FIELD_RE.exec(line);
        if (!bullet && !standalone) {
            i += 1;
            continue;
        }
        const match = bullet ?? standalone;
        const label = match[1].trim();
        const first = (match[2] ?? '').trim();
        const body = [];
        let j = i + 1;
        while (j < lines.length) {
            const next = lines[j];
            if (next.trim() === '') {
                const after = nextNonBlank(lines, j + 1);
                const continues = bullet
                    ? after !== undefined && indentOf(after) > 0
                    : after !== undefined && (indentOf(after) > 0 || /^[*-]\s/.test(after)) && !(indentOf(after) === 0 && BULLET_FIELD_RE.test(after));
                if (!continues) break;
                body.push('');
                j += 1;
                continue;
            }
            if (fenced[j]) {
                body.push(next);
                j += 1;
                continue;
            }
            if (bullet ? indentOf(next) === 0 : indentOf(next) === 0 && !/^[*-]\s/.test(next)) break;
            body.push(next);
            j += 1;
        }
        const rest = (bullet ? dedent(body, 2) : body).join('\n').replace(/\s+$/, '');
        const value = [first, rest].filter(Boolean).join('\n');
        if (!fields.has(labelKey(label))) fields.set(labelKey(label), { label, value });
        i = j;
    }
    return fields;
}

/** The value of a labeled field, or an empty string. */
export function field(fields, label) {
    return fields.get(labelKey(label))?.value ?? '';
}

/**
 * Removes top-level bullet fields with the given labels, including their nested lines, so
 * a body can be shown without repeating values a view renders separately.
 *
 * @param {string} block
 * @param {string[]} labels
 */
export function withoutFields(block, labels) {
    const drop = new Set(labels.map(labelKey));
    const { lines, fenced } = scanLines(block);
    const kept = [];
    let skipping = false;
    for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        const top = !fenced[i] && indentOf(line) === 0 && line.trim() !== '';
        if (top) {
            const match = BULLET_FIELD_RE.exec(line);
            skipping = Boolean(match && drop.has(labelKey(match[1])));
        } else if (skipping && line.trim() === '') {
            const after = nextNonBlank(lines, i + 1);
            if (after === undefined || indentOf(after) === 0) skipping = false;
        }
        if (!skipping) kept.push(line);
    }
    return kept.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

/**
 * Removes pipe tables outside fenced code, for bodies whose tables are shown as
 * structured lists.
 *
 * @param {string} block
 */
export function withoutTables(block) {
    const { lines, fenced } = scanLines(block);
    const kept = [];
    for (let i = 0; i < lines.length; i += 1) {
        const header = !fenced[i] && lines[i].trim().startsWith('|') && i + 1 < lines.length && !fenced[i + 1] && lines[i + 1].includes('-') && TABLE_DELIM_RE.test(lines[i + 1]);
        if (!header) {
            kept.push(lines[i]);
            continue;
        }
        let j = i + 2;
        while (j < lines.length && !fenced[j] && lines[j].trim().startsWith('|')) j += 1;
        i = j - 1;
    }
    return kept.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

/**
 * Splits a table row into trimmed cells. Escaped pipes and pipes inside code spans stay in
 * the cell.
 *
 * @param {string} line
 */
export function splitRow(line) {
    let text = line.trim();
    if (text.startsWith('|')) text = text.slice(1);
    if (text.endsWith('|') && !text.endsWith('\\|')) text = text.slice(0, -1);
    const cells = [];
    let current = '';
    for (let i = 0; i < text.length; i += 1) {
        const char = text[i];
        if (char === '\\' && text[i + 1] === '|') {
            current += '|';
            i += 1;
        } else if (char === '`') {
            let run = 1;
            while (text[i + run] === '`') run += 1;
            const fence = '`'.repeat(run);
            const close = text.indexOf(fence, i + run);
            if (close === -1) {
                current += fence;
                i += run - 1;
            } else {
                current += text.slice(i, close + run).replace(/\\\|/g, '|');
                i = close + run - 1;
            }
        } else if (char === '|') {
            cells.push(current.trim());
            current = '';
        } else {
            current += char;
        }
    }
    cells.push(current.trim());
    return cells;
}

/**
 * Pipe tables outside fenced code. Each row maps normalized header names to cells.
 *
 * @param {string} block
 * @returns {{ headers: string[], rows: Record<string, string>[], cells: string[][] }[]}
 */
export function tables(block) {
    const { lines, fenced } = scanLines(block);
    const found = [];
    for (let i = 0; i + 1 < lines.length; i += 1) {
        if (fenced[i] || fenced[i + 1]) continue;
        if (!lines[i].trim().startsWith('|') || !lines[i + 1].includes('-') || !TABLE_DELIM_RE.test(lines[i + 1])) continue;
        const headers = splitRow(lines[i]);
        const cells = [];
        let j = i + 2;
        while (j < lines.length && !fenced[j] && lines[j].trim().startsWith('|')) {
            cells.push(splitRow(lines[j]));
            j += 1;
        }
        const keys = headers.map(labelKey);
        found.push({ headers, cells, rows: cells.map((row) => Object.fromEntries(keys.map((key, index) => [key, row[index] ?? '']))) });
        i = j - 1;
    }
    return found;
}

/**
 * The first table whose headers include every requested header (normalized).
 *
 * @param {string} block
 * @param {string[]} required
 */
export function tableWith(block, required) {
    const wanted = required.map(labelKey);
    return tables(block).find((table) => {
        const have = table.headers.map(labelKey);
        return wanted.every((header) => have.includes(header));
    }) ?? null;
}

/**
 * Fenced code blocks, optionally filtered by the info string's language.
 *
 * @param {string} block
 * @param {string} [language]
 * @returns {{ language: string, code: string }[]}
 */
export function codeBlocks(block, language) {
    const lines = String(block ?? '').replace(/\r\n?/g, '\n').split('\n');
    const blocks = [];
    for (let i = 0; i < lines.length; i += 1) {
        const open = FENCE_RE.exec(lines[i]);
        if (!open) continue;
        const indent = indentOf(lines[i]);
        const info = open[2].trim().split(/\s+/)[0] ?? '';
        const body = [];
        let j = i + 1;
        while (j < lines.length) {
            const close = FENCE_RE.exec(lines[j]);
            if (close && close[1][0] === open[1][0] && close[1].length >= open[1].length && close[2].trim() === '') break;
            body.push(lines[j]);
            j += 1;
        }
        if (!language || info.toLowerCase() === language.toLowerCase()) {
            blocks.push({ language: info, code: dedent(body, indent).join('\n') });
        }
        i = j;
    }
    return blocks;
}

/**
 * Top-level list items, each with its nested lines, as Markdown without the bullet.
 *
 * @param {string} block
 */
export function listItems(block) {
    const { lines, fenced } = scanLines(block);
    const items = [];
    let current = null;
    for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i];
        if (!fenced[i] && /^[*-]\s+/.test(line)) {
            if (current) items.push(current);
            current = [line.replace(/^[*-]\s+/, '')];
        } else if (current && (line.trim() === '' || indentOf(line) > 0 || fenced[i])) {
            current.push(line);
        } else if (current) {
            items.push(current);
            current = null;
        }
    }
    if (current) items.push(current);
    return items
        .map(([head, ...rest]) => [head, ...dedent(rest, 2)].join('\n').replace(/\s+$/, ''))
        .filter((item) => item !== '');
}

/**
 * Markdown links `[text](href)` outside code spans and fences.
 *
 * @param {string} block
 * @returns {{ text: string, href: string }[]}
 */
export function linksIn(block) {
    const { lines, fenced } = scanLines(block);
    const links = [];
    for (let i = 0; i < lines.length; i += 1) {
        if (fenced[i]) continue;
        const masked = lines[i].replace(/`[^`]*`/g, (span) => ' '.repeat(span.length));
        const re = /\[([^\]\n]{1,400})\]\(([^)\s]{1,800})\)/g;
        for (let match = re.exec(masked); match; match = re.exec(masked)) {
            links.push({ text: lines[i].slice(match.index + 1, match.index + 1 + match[1].length), href: match[2] });
        }
    }
    return links;
}

function splitId(id) {
    const match = /^(.*?)(\d+)$/.exec(id);
    return match ? { prefix: match[1], number: Number(match[2]), width: match[2].length } : null;
}

/**
 * IDs mentioned in text, in order and without duplicates. "A to B" and "A through B"
 * expand when both ends share a prefix and the span is at most 200; any other pair stays
 * as written. `filter`, when given, keeps only matching IDs.
 *
 * @param {string} text
 * @param {RegExp} [filter]
 */
export function idsIn(text, filter) {
    const seen = new Set();
    const out = [];
    const add = (id) => {
        if (!seen.has(id) && (!filter || filter.test(id))) {
            seen.add(id);
            out.push(id);
        }
    };
    const source = String(text ?? '');
    ID_RANGE_RE.lastIndex = 0;
    for (let match = ID_RANGE_RE.exec(source); match; match = ID_RANGE_RE.exec(source)) {
        const [, from, to] = match;
        const a = to ? splitId(from) : null;
        const b = to ? splitId(to) : null;
        if (a && b && a.prefix === b.prefix && b.number >= a.number && b.number - a.number <= MAX_RANGE) {
            for (let n = a.number; n <= b.number; n += 1) add(`${a.prefix}${String(n).padStart(a.width, '0')}`);
        } else {
            add(from);
            if (to) add(to);
        }
    }
    return out;
}

/**
 * Reads a checkbox heading such as `[x] P01-T02: Title`.
 *
 * @param {string} title
 * @returns {{ checked: boolean, id: string, title: string } | null}
 */
export function checkboxHeading(title) {
    const match = /^\[( |x|X)\]\s+(P\d{2}(?:-T\d{2})?):\s*(.*)$/.exec(String(title ?? '').trim());
    return match ? { checked: match[1] !== ' ', id: match[2], title: match[3].trim() } : null;
}

/**
 * Reads a severity heading such as `RV-001 [High]: Title`.
 *
 * @param {string} title
 * @returns {{ id: string, severity: string, title: string } | null}
 */
export function severityHeading(title) {
    const match = /^([A-Z]{2,3}-\d{3})\s+\[(Critical|High|Medium|Low)\]:\s*(.*)$/i.exec(String(title ?? '').trim());
    return match ? { id: match[1], severity: match[2].toLowerCase(), title: match[3].trim() } : null;
}

/**
 * Plain text for titles and labels: link text instead of links, and no code or emphasis
 * markers.
 *
 * @param {string} markdown
 */
export function plainText(markdown) {
    return String(markdown ?? '')
        .replace(/\[([^\]\n]*)\]\([^)\n]*\)/g, '$1')
        .replace(/`([^`\n]*)`/g, '$1')
        .replace(/(\*\*|__)(.+?)\1/g, '$2')
        .replace(/(^|[\s(])[*_]([^*_\n]+)[*_](?=[\s).,;:!?]|$)/g, '$1$2')
        .replace(/\s+/g, ' ')
        .trim();
}

/**
 * Inline Markdown for text the canvas renders, such as table cells: the file's code spans,
 * links, and emphasis kept, with whitespace collapsed to single spaces.
 *
 * @param {string} markdown
 */
export function inlineMarkdown(markdown) {
    return String(markdown ?? '').replace(/\s+/g, ' ').trim();
}
