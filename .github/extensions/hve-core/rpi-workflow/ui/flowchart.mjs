// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Reads the Mermaid flowchart subset RPI plans use, without DOM, so the page draws it and the
 * source reader can report a diagram it cannot draw: parts with quoted labels, plain or formatted
 * (wrapped in backticks, over one or more lines, with bold, italics, `<code>`, and line breaks);
 * solid (`-->`) and dashed (`-.->`) arrows, each with an optional label; `class` lines on parts
 * and boxes; boxes (`subgraph`) closed by `end`, which may nest; and `accTitle` and `accDescr`.
 * `%%` lines, `classDef` styles, and `direction` lines are ignored, and anything else throws,
 * naming the line. Labels come back as plain text and as styled runs; label markup never becomes
 * markup on the page. A label's last line can be a tag, such as `changed · P01, P03`.
 */

const ID = '[A-Za-z][\\w-]{0,40}';
const NODE_RE = new RegExp(`^(${ID})\\["([^"]{1,240})"\\]$`);
const EDGE_RE = new RegExp(`^(${ID})\\s*(-->|-\\.->)\\s*(?:\\|([^|\\n]{1,120})\\|\\s*)?(${ID})$`);
const CLASS_RE = /^class\s+([\w,-]{1,400})\s+([A-Za-z][\w-]{0,30})$/;
const GROUP_RE = new RegExp(`^subgraph\\s+(${ID})(?:\\s*\\["([^"]{1,120})"\\]|\\s*\\[([^\\]\\n]{1,120})\\])?$`);
const TAG_RE = /^(new|changed|removed)(?:\s+([a-z]+))?\s*·\s*(P\d{2,3}(?:\s*,\s*P\d{2,3})*)$/i;
const MAX_NODES = 120;
const MAX_EDGES = 240;
const MAX_DEPTH = 8;

/**
 * @typedef {{ text: string, bold: boolean, italic: boolean, code: boolean }} LabelRun
 * @typedef {{ kind: 'new' | 'changed' | 'removed', noun: string | null, phases: string[] }} LabelTag
 * @typedef {{ id: string, label: string, lines: LabelRun[][], tag: LabelTag | null, classes: Set<string>, group: string | null }} FlowNode
 * @typedef {{ from: string, to: string, label: string, dashed: boolean }} FlowEdge
 * @typedef {{ id: string, label: string, lines: LabelRun[][], tag: LabelTag | null, members: string[], classes: Set<string>, parent: string | null, depth: number }} FlowGroup
 */

/** Joins a formatted label that opens on one line and closes on a later one into one statement. */
function statements(source) {
    const raw = String(source ?? '').split('\n');
    const out = [];
    for (let i = 0; i < raw.length; i += 1) {
        let line = raw[i].trim();
        if (!line || line.startsWith('%%')) continue;
        const open = line.lastIndexOf('["`');
        if (open !== -1 && !line.slice(open + 3).includes('`"]')) {
            const parts = [line];
            while (i + 1 < raw.length) {
                i += 1;
                const next = raw[i].trim();
                parts.push(next);
                if (next.includes('`"]')) break;
            }
            line = parts.join('\n');
        }
        out.push(line);
    }
    return out;
}

const STYLE_KEYS = ['bold', 'italic', 'code'];
const sameStyle = (a, b) => STYLE_KEYS.every((key) => a[key] === b[key]);

/**
 * Splits one line of label text into styled runs. `<code>` works in any label; `**bold**`,
 * `*italic*`, and `_italic_` only in a formatted one, as in Mermaid. Unknown tags stay text.
 */
function inlineRuns(text, formatted, style = { bold: false, italic: false, code: false }) {
    const runs = [];
    const push = (value, runStyle) => {
        if (!value) return;
        const last = runs.at(-1);
        if (last && sameStyle(last, runStyle)) last.text += value;
        else runs.push({ text: value, ...runStyle });
    };
    let buffer = '';
    let i = 0;
    while (i < text.length) {
        if (text.startsWith('<code>', i)) {
            const close = text.indexOf('</code>', i + 6);
            if (close !== -1) {
                push(buffer, style);
                buffer = '';
                push(text.slice(i + 6, close), { ...style, code: true });
                i = close + 7;
                continue;
            }
        }
        if (formatted && text.startsWith('**', i)) {
            const close = text.indexOf('**', i + 2);
            if (close > i + 2) {
                push(buffer, style);
                buffer = '';
                for (const run of inlineRuns(text.slice(i + 2, close), formatted, { ...style, bold: true })) push(run.text, run);
                i = close + 2;
                continue;
            }
        }
        const mark = text[i];
        if (formatted && (mark === '*' || mark === '_') && text[i + 1] !== mark && text[i + 1] && !/\s/.test(text[i + 1]) && !/\w/.test(text[i - 1] ?? '')) {
            const close = text.indexOf(mark, i + 1);
            if (close > i + 1 && !/\s/.test(text[close - 1]) && !/\w/.test(text[close + 1] ?? '')) {
                push(buffer, style);
                buffer = '';
                for (const run of inlineRuns(text.slice(i + 1, close), formatted, { ...style, italic: true })) push(run.text, run);
                i = close + 1;
                continue;
            }
        }
        buffer += text[i];
        i += 1;
    }
    push(buffer, style);
    return runs;
}

const plainOf = (runs) => runs.map((run) => run.text).join('').trim();

/**
 * Reads a label as lines of runs, its plain text without the tag, and its tag. A formatted
 * label is wrapped in backticks; `<br>` breaks a line in either kind.
 *
 * @param {string} raw the text between the quotes or brackets
 * @returns {{ label: string, lines: LabelRun[][], tag: LabelTag | null }}
 */
export function readLabel(raw) {
    const text = String(raw ?? '').trim();
    const formatted = text.length >= 2 && text.startsWith('`') && text.endsWith('`');
    const body = formatted ? text.slice(1, -1) : text;
    const lines = body.split(/\n|<br\s*\/?>/i).map((line) => line.trim()).filter(Boolean).map((line) => inlineRuns(line, formatted));
    const last = lines.length > 1 || formatted ? TAG_RE.exec(plainOf(lines.at(-1) ?? [])) : null;
    const tag = last && lines.length > 1 ? { kind: /** @type {LabelTag['kind']} */ (last[1].toLowerCase()), noun: last[2]?.toLowerCase() ?? null, phases: last[3].split(',').map((id) => id.trim().toUpperCase()) } : null;
    const named = tag ? lines.slice(0, -1) : lines;
    return { label: named.map(plainOf).filter(Boolean).join(', ') || plainOf(lines.flat()), lines, tag };
}

/**
 * Parses a flowchart; throws an Error naming the first line it cannot read.
 *
 * @param {string} source
 * @returns {{ direction: 'LR' | 'TD', nodes: Map<string, FlowNode>, edges: FlowEdge[], groups: FlowGroup[], title: string | null, description: string | null }} `groups` lists each box with the parts it introduced, in source order
 */
export function parseFlowchart(source) {
    const lines = statements(source);
    const header = lines.shift() ?? '';
    const direction = /^flowchart\s+(LR|TD|TB)$/.exec(header)?.[1];
    if (!direction) {
        throw new Error('Only flowchart LR and TD diagrams are supported.');
    }
    const nodes = new Map();
    const edges = [];
    const groups = [];
    const open = [];
    let title = null;
    let description = null;
    let describing = null;
    const ensure = (id) => {
        if (!nodes.has(id)) {
            const group = open.at(-1) ?? null;
            nodes.set(id, { id, label: id, lines: [[{ text: id, bold: false, italic: false, code: false }]], tag: null, classes: new Set(), group: group?.id ?? null });
            group?.members.push(id);
        }
        return nodes.get(id);
    };
    for (const line of lines) {
        if (describing) {
            if (line === '}') {
                description = describing.join(' ').trim() || null;
                describing = null;
            } else {
                describing.push(line);
            }
            continue;
        }
        if (line.startsWith('classDef ') || /^direction\s+(LR|RL|TB|TD|BT)$/.test(line)) continue;
        let match = /^accTitle\s*:\s*(.*)$/.exec(line);
        if (match) {
            title = match[1].trim() || null;
            continue;
        }
        match = /^accDescr\s*:\s*(.*)$/.exec(line);
        if (match) {
            description = match[1].trim() || null;
            continue;
        }
        if (/^accDescr\s*\{$/.test(line)) {
            describing = [];
            continue;
        }
        match = NODE_RE.exec(line);
        if (match) {
            Object.assign(ensure(match[1]), readLabel(match[2]));
            continue;
        }
        match = EDGE_RE.exec(line);
        if (match) {
            ensure(match[1]);
            ensure(match[4]);
            edges.push({ from: match[1], to: match[4], label: match[3]?.trim() ?? '', dashed: match[2] === '-.->' });
            continue;
        }
        match = CLASS_RE.exec(line);
        if (match) {
            for (const id of match[1].split(',')) {
                if (nodes.has(id)) nodes.get(id).classes.add(match[2]);
                else groups.find((group) => group.id === id)?.classes.add(match[2]);
            }
            continue;
        }
        match = GROUP_RE.exec(line);
        if (match && open.length < MAX_DEPTH) {
            const text = match[2] ?? match[3];
            const group = { id: match[1], ...(text ? readLabel(text) : readLabel(match[1])), members: [], classes: new Set(), parent: open.at(-1)?.id ?? null, depth: open.length + 1 };
            groups.push(group);
            open.push(group);
            continue;
        }
        if (line === 'end' && open.length) {
            open.pop();
            continue;
        }
        throw new Error(`Unsupported diagram line: ${line.split('\n')[0].slice(0, 60)}`);
    }
    if (describing) {
        throw new Error('The accDescr block has no closing brace.');
    }
    if (open.length) {
        throw new Error(`The subgraph ${open.at(-1).id} has no end line.`);
    }
    if (nodes.size > MAX_NODES || edges.length > MAX_EDGES) {
        throw new Error(`Diagrams are limited to ${MAX_NODES} parts and ${MAX_EDGES} relationships.`);
    }
    return { direction: direction === 'LR' ? 'LR' : 'TD', nodes, edges, groups, title, description };
}
