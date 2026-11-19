// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { reasonCoverage } from './views.mjs';

/**
 * The Code Review change map without DOM: the recorded map, or one drawn from the review's areas,
 * as Before, Changes, and After views that share one layout, so a part never moves between views.
 * Label fitting, the layered layout, routing, and edge-label placement are adapted from the RPI
 * Workflow canvas's diagram renderer (rpi-workflow/ui/diagram.mjs). The graph comes from the review
 * record's JSON rather than Mermaid, and each part's box fits its label in every view.
 */

const PLAIN = Object.freeze({ bold: false, italic: false, code: false });
const textOf = (runs) => runs.map((run) => run.text).join('');

/** Splits runs into the tokens a line breaks at: after spaces and slashes, and inside a word wider than `width`. */
/** A word longer than `width` in pieces: after hyphens, underscores, and dots, between camelCase humps, then every `width` characters. */
function splitWord(word, width) {
    const out = [];
    for (const piece of word.split(/(?<=[-_.])|(?<=[a-z0-9])(?=[A-Z])/u)) {
        for (const chunk of piece.length > width ? piece.match(new RegExp(`.{1,${width}}`, 'gu')) : [piece]) {
            if (out.length && out.at(-1).length + chunk.length <= width) out[out.length - 1] += chunk;
            else out.push(chunk);
        }
    }
    return out;
}

/** The longest word in lines of runs, where a word ends at a space or after a slash. */
function longestWord(lines) {
    return Math.max(0, ...lines.flatMap((line) => textOf(line).split(/(?<=[\s/])/).map((word) => word.trimEnd().length)));
}

function tokensOf(runs, width) {
    const out = [];
    for (const run of runs) {
        for (const token of run.text.split(/(?<=[\s/])/)) {
            const word = token.trimEnd();
            if (word.length <= width) {
                out.push({ ...run, text: token });
                continue;
            }
            const pieces = splitWord(word, width);
            pieces[pieces.length - 1] += token.slice(word.length);
            for (const piece of pieces) out.push({ ...run, text: piece });
        }
    }
    return out;
}

/** Joins neighboring runs of one style and drops empty ones. */
function mergeRuns(runs) {
    const out = [];
    for (const run of runs) {
        if (!run.text) continue;
        const last = out.at(-1);
        if (last && last.bold === run.bold && last.italic === run.italic && last.code === run.code) last.text += run.text;
        else out.push({ ...run });
    }
    return out;
}

/** The characters from `start` to `end` of a line of runs, keeping each run's style. */
function sliceRuns(runs, start, end) {
    const out = [];
    let at = 0;
    for (const run of runs) {
        const from = Math.max(start, at);
        const to = Math.min(end, at + run.text.length);
        if (to > from) out.push({ ...run, text: run.text.slice(from - at, to - at) });
        at += run.text.length;
    }
    return mergeRuns(out);
}

function trimRuns(runs) {
    const text = textOf(runs);
    const start = text.length - text.trimStart().length;
    return sliceRuns(runs, start, Math.max(start, text.trimEnd().length));
}

/**
 * Wraps a line of runs at spaces and slashes, so paths such as src/api/file.ts can break too. A
 * word longer than `width` breaks after a hyphen, underscore, or dot, or between camelCase humps,
 * and inside a piece only when that piece alone is too long, so no line is wider than `width`.
 *
 * @param {{ text: string, bold: boolean, italic: boolean, code: boolean }[]} runs
 * @param {number} width characters
 */
export function wrapRuns(runs, width) {
    const lines = [];
    let current = [];
    for (const token of tokensOf(runs, width)) {
        const text = textOf(current);
        if (text && (text + token.text).trimEnd().length > width) {
            lines.push(trimRuns(current));
            current = [{ ...token, text: token.text.trimStart() }];
        } else {
            current.push(token);
        }
    }
    if (textOf(current).trim()) lines.push(trimRuns(current));
    return lines;
}

/** `wrapRuns` for plain text. */
export function wrap(label, width) {
    return wrapRuns([{ text: label, ...PLAIN }], width).map(textOf);
}

/** Node labels: 14 to 22 characters a line, four lines before a box grows taller, at most eight. */
export const NODE_FIT = Object.freeze({ min: 14, max: 22, lines: 4, cap: 8 });
/** Edge labels: 10 to 16 characters a line, two lines before a label grows taller, at most four. */
export const EDGE_FIT = Object.freeze({ min: 10, max: 16, lines: 2, cap: 4 });
/** Box titles: 18 to 34 characters a line, one line before a title grows taller, at most three. */
export const TITLE_FIT = Object.freeze({ min: 18, max: 34, lines: 1, cap: 3 });

/**
 * Fits lines of runs into visual lines without losing words: the narrowest width from `fit.min`
 * to `fit.max` that needs at most `fit.lines` lines, else `fit.max` wide with up to `fit.cap`
 * lines. No width is narrower than the longest word up to `fit.max`, so a name such as
 * `composeDocument()` stays whole. Only a label longer than that is cut: its last line ends with
 * an ellipsis and `cut` is true, so the caller can show the full label on hover.
 *
 * @param {{ text: string, bold: boolean, italic: boolean, code: boolean }[][]} lines
 * @param {{ min: number, max: number, lines: number, cap: number }} fit
 * @returns {{ lines: { text: string, bold: boolean, italic: boolean, code: boolean }[][], cut: boolean, width: number }}
 */
export function fitRuns(lines, fit) {
    const at = (width) => lines.flatMap((line) => wrapRuns(line, width));
    for (let width = Math.max(fit.min, Math.min(longestWord(lines), fit.max)); width < fit.max; width += 1) {
        const out = at(width);
        if (out.length <= fit.lines) return { lines: out, cut: false, width };
    }
    const out = at(fit.max);
    if (out.length <= fit.cap) return { lines: out, cut: false, width: fit.max };
    const kept = out.slice(0, fit.cap);
    const last = kept[fit.cap - 1];
    const shortened = sliceRuns(last, 0, textOf(last).slice(0, fit.max - 1).trimEnd().length);
    if (shortened.length) shortened[shortened.length - 1].text += '…';
    else shortened.push({ text: '…', ...PLAIN });
    kept[fit.cap - 1] = shortened;
    return { lines: kept, cut: true, width: fit.max };
}

/**
 * `fitRuns` for plain text.
 *
 * @param {string} label
 * @param {{ min: number, max: number, lines: number, cap: number }} fit
 * @returns {{ lines: string[], cut: boolean }}
 */
export function fitLabel(label, fit) {
    const { lines, cut } = fitRuns([[{ text: label, ...PLAIN }]], fit);
    return { lines: lines.map(textOf), cut };
}

const labelLines = (text) => fitLabel(text, EDGE_FIT).lines;
const labelWidth = (text) => Math.max(...labelLines(text).map((line) => line.length)) * 6 + 12;
const labelHeight = (text) => labelLines(text).length * 13 + 6;
/** Approximate drawn widths, so bold and code text, which run wider, still fit their boxes. */
const runWidth = (run, plain, bold, code) => run.text.length * (run.code ? code : run.bold ? bold : plain);
const lineWidth = (runs, [plain, bold, code]) => runs.reduce((sum, run) => sum + runWidth(run, plain, bold, code), 0);
const NODE_CHARS = [6.9, 7.3, 7.6];
const TITLE_CHARS = [6.6, 7, 7.1];

const NODE_LINE = 17;
const NODE_PAD = 18;
const GAP_CROSS = 20;
const WAYPOINT = 8;
const BAND_GAP = 16;
const FRAME_PAD = 12;
const TITLE_LINE = 15;
const TITLE_GAP = 6;
const ROOT = '';

/** The visual lines of a label that came from its tag line, which is the label's last line. */
function tagLineCount(item, width) {
    return item.tag ? wrapRuns(item.lines.at(-1), width).length : 0;
}

/**
 * Layered layout: longest-path columns, parts pulled toward their successors so arrows span one
 * column where possible, waypoints in each column a longer arrow crosses, then barycenter sweeps
 * to reduce crossings. Each top-level box is a band across the columns its parts and its arrows'
 * waypoints use, and parts outside any box form one band per run of columns; a band sits just past
 * every earlier band whose columns it shares, so boxes at different steps share space, as layers
 * do, and frames never overlap. A box inside a box stacks as a band inside its band. In a
 * top-to-bottom map the gap above a box's first row makes room for its title, and arrow labels
 * sit above it.
 *
 * @returns {{ positions: Map<string, any>, layerOf: Map<string, number>, width: number, height: number, horizontal: boolean, frames: Map<string, any>, routes: any[] }}
 *   Each frame carries `titleBox`, the rectangle its title draws in; each route carries `label`,
 *   the point its label centers on before labels in one gap are nudged apart.
 */
export function layout(graph) {
    const horizontal = graph.direction === 'LR';
    const ids = [...graph.nodes.keys()];
    const order = new Map(ids.map((id, index) => [id, index]));
    const incoming = new Map(ids.map((id) => [id, []]));
    const outgoing = new Map(ids.map((id) => [id, []]));
    for (const edge of graph.edges) {
        incoming.get(edge.to).push(edge.from);
        outgoing.get(edge.from).push(edge.to);
    }
    const layer = new Map();
    const visiting = new Set();
    const depthOf = (id) => {
        if (layer.has(id)) return layer.get(id);
        if (visiting.has(id)) return 0;
        visiting.add(id);
        const value = incoming.get(id).reduce((max, from) => Math.max(max, depthOf(from) + 1), 0);
        visiting.delete(id);
        layer.set(id, value);
        return value;
    };
    ids.forEach(depthOf);
    // A part outside any box moves toward its successors so its arrows span one column. A part in a
    // box keeps its column, so a box's parts stay in the layers they share, as Mermaid keeps them.
    for (const id of [...ids].sort((a, b) => layer.get(b) - layer.get(a))) {
        if (graph.nodes.get(id).group) continue;
        const next = outgoing.get(id).map((to) => layer.get(to));
        if (next.length && next.every((value) => value > layer.get(id))) {
            layer.set(id, Math.min(...next) - 1);
        }
    }
    // Pulling parts toward their successors can empty a column, such as in a cycle; renumber so none is.
    const used = [...new Set(layer.values())].sort((a, b) => a - b);
    const dense = new Map(used.map((value, index) => [value, index]));
    for (const id of ids) layer.set(id, dense.get(layer.get(id)));

    // Bands: one per box one or two levels deep that holds a part; a deeper box folds into its second-level box.
    const groups = new Map(graph.groups.map((group) => [group.id, group]));
    const keptOf = (id) => {
        let group = groups.get(id) ?? null;
        while (group && group.depth > 2) group = groups.get(group.parent) ?? null;
        return group;
    };
    const bands = new Map([[ROOT, { key: ROOT, group: null, loose: [], children: [], first: Infinity }]]);
    for (const group of graph.groups) {
        if (group.depth <= 2) bands.set(group.id, { key: group.id, group, loose: [], children: [], first: Infinity });
    }
    const rowOf = new Map();
    for (const id of ids) {
        const key = keptOf(graph.nodes.get(id).group)?.id ?? ROOT;
        bands.get(key).loose.push(id);
        rowOf.set(id, key);
    }
    for (const group of graph.groups) {
        if (group.depth <= 2) bands.get(group.depth === 1 ? ROOT : group.parent).children.push(group.id);
    }
    const firstOf = (key) => {
        const band = bands.get(key);
        if (band.first === Infinity) band.first = Math.min(band.loose.length ? order.get(band.loose[0]) : Infinity, ...band.children.map(firstOf));
        return band.first;
    };
    firstOf(ROOT);
    const contentOf = (key) => {
        const band = bands.get(key);
        const items = band.children.filter((child) => firstOf(child) !== Infinity).map((child) => ({ kind: 'band', key: child, first: firstOf(child) }));
        if (band.loose.length) items.push({ kind: 'row', key, first: order.get(band.loose[0]) });
        return items.sort((a, b) => a.first - b.first);
    };
    const rowRank = new Map();
    const rank = (key) => {
        for (const item of contentOf(key)) {
            if (item.kind === 'row') rowRank.set(key, rowRank.size);
            else rank(item.key);
        }
    };
    rank(ROOT);

    // Waypoints: an arrow that spans columns gets one in each column between its ends, in its source's band.
    const chains = graph.edges.map((edge, index) => {
        const chain = [edge.from];
        for (let at = layer.get(edge.from) + 1; at < layer.get(edge.to); at += 1) {
            const id = `\u0000${index}:${at}`;
            layer.set(id, at);
            rowOf.set(id, rowOf.get(edge.from));
            chain.push(id);
        }
        chain.push(edge.to);
        return chain;
    });
    const waypoints = [...layer.keys()].filter((id) => !graph.nodes.has(id));
    const all = [...ids, ...waypoints];
    const above = new Map(all.map((id) => [id, []]));
    const below = new Map(all.map((id) => [id, []]));
    const spans = [];
    for (const chain of chains) {
        for (let i = 1; i < chain.length; i += 1) {
            const [from, to] = [chain[i - 1], chain[i]];
            above.get(to).push(from);
            below.get(from).push(to);
            spans.push({ from, to });
        }
    }
    const layers = [];
    for (const id of all) (layers[layer.get(id)] ??= []).push(id);
    layers.forEach((group = [], index) => {
        layers[index] = group.sort((a, b) => rowRank.get(rowOf.get(a)) - rowRank.get(rowOf.get(b)));
    });
    const position = new Map();
    layers.forEach((group = []) => group.forEach((id, index) => position.set(id, index)));
    // Within each column, parts move only among the parts of their own band.
    const sweep = (neighbors, from, to, step) => {
        for (let i = from; i !== to; i += step) {
            const group = layers[i];
            if (!group) continue;
            const next = [];
            for (let start = 0; start < group.length;) {
                let end = start;
                while (end < group.length && rowOf.get(group[end]) === rowOf.get(group[start])) end += 1;
                const segment = group.slice(start, end);
                const movable = [];
                const fixed = new Map();
                segment.forEach((id, index) => {
                    const linked = neighbors.get(id).filter((other) => layer.get(other) === i - step);
                    if (linked.length) movable.push([id, linked.reduce((sum, other) => sum + position.get(other), 0) / linked.length]);
                    else fixed.set(index, id);
                });
                movable.sort((a, b) => a[1] - b[1]);
                let moved = 0;
                next.push(...segment.map((_id, index) => (fixed.has(index) ? fixed.get(index) : movable[moved++][0])));
                start = end;
            }
            layers[i] = next;
            layers[i].forEach((id, index) => position.set(id, index));
        }
    };
    const adjacent = spans.filter((span) => layer.get(span.to) === layer.get(span.from) + 1);
    const crossings = () => {
        let total = 0;
        for (const a of adjacent) {
            for (const b of adjacent) {
                if (layer.get(a.from) === layer.get(b.from) && position.get(a.from) < position.get(b.from) && position.get(a.to) > position.get(b.to)) total += 1;
            }
        }
        return total;
    };
    let best = { count: crossings(), layers: layers.map((group) => (group ? [...group] : group)) };
    for (let pass = 0; pass < 4 && best.count > 0; pass += 1) {
        sweep(above, 1, layers.length, 1);
        sweep(below, layers.length - 2, -1, -1);
        const count = crossings();
        if (count < best.count) best = { count, layers: layers.map((group) => (group ? [...group] : group)) };
    }
    best.layers.forEach((group, index) => {
        layers[index] = group;
        (group ?? []).forEach((id, slot) => position.set(id, slot));
    });

    const boxes = new Map();
    for (const id of ids) {
        const node = graph.nodes.get(id);
        // Every view's label fits one box, so a part keeps its size and its place in every view.
        const fits = Object.entries(node.variants).map(([view, lines]) => {
            const fit = fitRuns(lines, NODE_FIT);
            const tag = node.tag && !fit.cut ? wrapRuns(lines.at(-1), fit.width).length : 0;
            return [view, { lines: fit.lines, cut: fit.cut, tagFrom: fit.lines.length - tag }];
        });
        const widest = Math.max(...fits.flatMap(([, fit]) => fit.lines.map((line) => lineWidth(line, NODE_CHARS))));
        const tallest = Math.max(...fits.map(([, fit]) => fit.lines.length));
        boxes.set(id, { variants: Object.fromEntries(fits), width: Math.min(184, Math.max(88, widest + 24)), height: tallest * NODE_LINE + NODE_PAD });
    }
    for (const id of waypoints) boxes.set(id, { width: horizontal ? 0 : WAYPOINT, height: horizontal ? WAYPOINT : 0 });
    const mainOf = (id) => (horizontal ? boxes.get(id).width : boxes.get(id).height);
    const crossOf = (id) => (horizontal ? boxes.get(id).height : boxes.get(id).width);

    // Box titles, measured before the columns so a top-to-bottom map can make room for them.
    const titles = new Map();
    for (const [key, band] of bands) {
        if (!band.group) continue;
        const fit = fitRuns(band.group.lines, TITLE_FIT);
        titles.set(key, { lines: fit.lines, tagFrom: fit.lines.length - (fit.cut ? 0 : tagLineCount(band.group, fit.width)), width: Math.max(...fit.lines.map((line) => lineWidth(line, TITLE_CHARS)), 0), size: fit.lines.length * TITLE_LINE });
    }
    // The parts a box holds, inner boxes included, and the column its first row sits in.
    const partsOf = (key) => {
        const band = bands.get(key);
        return [...band.loose, ...band.children.flatMap(partsOf)];
    };
    const firstLayer = (key) => Math.min(...partsOf(key).map((id) => layer.get(id)));
    // Top to bottom, how far a box's frame reaches above its first row: padding and its title,
    // plus the reach of an inner box that starts in the same row.
    const reach = (key) => {
        const band = bands.get(key);
        if (!band.group || !partsOf(key).length) return 0;
        const inner = band.children.filter((child) => partsOf(child).length && firstLayer(child) === firstLayer(key)).map((child) => reach(child) - FRAME_PAD);
        return FRAME_PAD + titles.get(key).size + TITLE_GAP + Math.max(0, ...inner);
    };
    const reserve = layers.map(() => 0);
    if (!horizontal) {
        for (const [key, band] of bands) {
            if (band.group && partsOf(key).length) reserve[firstLayer(key)] = Math.max(reserve[firstLayer(key)], reach(key));
        }
    }
    const gaps = layers.map((_group, index) => {
        const labels = graph.edges.filter((edge) => edge.label && layer.get(edge.from) === index).map((edge) => (horizontal ? labelWidth(edge.label) : labelHeight(edge.label)));
        return Math.min(150, Math.max(56, Math.max(0, ...labels) + 28)) + (reserve[index + 1] ?? 0);
    });
    const columnStart = [];
    const columnSize = [];
    let main = 0;
    layers.forEach((group = [], index) => {
        columnStart[index] = main;
        columnSize[index] = Math.max(...group.map(mainOf), 0);
        main += columnSize[index] + (index < layers.length - 1 ? gaps[index] : 0);
    });

    // Cross positions: each band's rows and inner bands in source order, each framed band with room for its title.
    const cross = new Map();
    const frames = new Map();
    const placeRow = (key, start, only = null) => {
        const cells = layers.map((group = [], index) => (only && !only.has(index) ? [] : group.filter((id) => rowOf.get(id) === key)));
        const sizes = cells.map((cell) => cell.reduce((sum, id) => sum + crossOf(id), 0) + GAP_CROSS * Math.max(0, cell.length - 1));
        const size = Math.max(...sizes, 0);
        cells.forEach((cell, index) => {
            let at = start + (size - sizes[index]) / 2;
            for (const id of cell) {
                cross.set(id, at);
                at += crossOf(id) + GAP_CROSS;
            }
        });
        return start + size;
    };
    const placeBand = (key, start) => {
        const band = bands.get(key);
        const title = titles.get(key);
        let cursor = start + (band.group ? FRAME_PAD + (horizontal ? title.size + TITLE_GAP : 0) : 0);
        const items = contentOf(key);
        items.forEach((item, index) => {
            cursor = item.kind === 'row' ? placeRow(key, cursor) : placeBand(item.key, cursor);
            if (index < items.length - 1) cursor += BAND_GAP;
        });
        if (!band.group) return cursor;
        let end = cursor + FRAME_PAD;
        const members = [...band.loose];
        const inner = [];
        const collect = (child) => {
            const nested = bands.get(child);
            if (frames.has(child)) inner.push(frames.get(child));
            members.push(...nested.loose);
            nested.children.forEach(collect);
        };
        band.children.forEach(collect);
        if (!members.length) return start;
        const mains = members.map((id) => [columnStart[layer.get(id)], columnStart[layer.get(id)] + mainOf(id)]);
        let mainStart = Math.min(...mains.map(([from]) => from), ...inner.map((frame) => frame.main[0] + FRAME_PAD)) - FRAME_PAD;
        let mainEnd = Math.max(...mains.map(([, to]) => to), ...inner.map((frame) => frame.main[1] - FRAME_PAD)) + FRAME_PAD;
        if (horizontal) {
            mainEnd = Math.max(mainEnd, mainStart + title.width + FRAME_PAD * 2);
        } else {
            mainStart -= title.size + TITLE_GAP;
            end = Math.max(end, start + title.width + FRAME_PAD * 2);
        }
        frames.set(key, { id: key, group: band.group, depth: band.group.depth, main: [mainStart, mainEnd], cross: [start, end], title });
        return end;
    };
    // Along the flow, a band uses the columns of its frame and of the waypoints of arrows leaving
    // it. Each top-level band, and each run of columns holding parts outside any box, sits just
    // past every earlier one whose columns it shares, so boxes at different steps share space.
    const mainSpan = (members) => [Math.min(...members.map((id) => columnStart[layer.get(id)])), Math.max(...members.map((id) => columnStart[layer.get(id)] + (graph.nodes.has(id) ? mainOf(id) : columnSize[layer.get(id)])))];
    const heldBy = (key) => {
        const keys = new Set([key]);
        const add = (band) => band.children.forEach((child) => {
            keys.add(child);
            add(bands.get(child));
        });
        add(bands.get(key));
        return all.filter((id) => keys.has(rowOf.get(id)));
    };
    const items = [];
    for (const item of contentOf(ROOT)) {
        if (item.kind === 'band') {
            const held = heldBy(item.key);
            if (!held.length) continue;
            const [from, to] = mainSpan(held);
            const title = titles.get(item.key);
            // The frame reaches past its parts: padding, and its title above the first row top to bottom or along the top left to right.
            const span = horizontal
                ? [from - FRAME_PAD, Math.max(to + FRAME_PAD, from - FRAME_PAD + title.width + FRAME_PAD * 2)]
                : [Math.min(from, columnStart[firstLayer(item.key)] - reach(item.key)), to + FRAME_PAD];
            items.push({ span, place: (start) => placeBand(item.key, start) });
            continue;
        }
        const used = [...new Set(all.filter((id) => rowOf.get(id) === ROOT).map((id) => layer.get(id)))].sort((x, y) => x - y);
        for (let i = 0; i < used.length;) {
            let j = i;
            while (j + 1 < used.length && used[j + 1] === used[j] + 1) j += 1;
            const run = new Set(used.slice(i, j + 1));
            items.push({ span: mainSpan(all.filter((id) => rowOf.get(id) === ROOT && run.has(layer.get(id)))), place: (start) => placeRow(ROOT, start, run) });
            i = j + 1;
        }
    }
    const placed = [];
    for (const item of items) {
        const start = Math.max(0, ...placed.filter((other) => other.span[0] < item.span[1] && item.span[0] < other.span[1]).map((other) => other.end + BAND_GAP));
        placed.push({ span: item.span, end: item.place(start) });
    }
    const crossTotal = Math.max(0, ...placed.map((item) => item.end));

    // Normalize: titles above a column in a top-to-bottom map can start above the first row.
    const mainMin = Math.min(0, ...[...frames.values()].map((frame) => frame.main[0]));
    const toBox = (mainAt, crossAt, mainSize, crossSize) => (horizontal
        ? { x: mainAt - mainMin, y: crossAt, width: mainSize, height: crossSize }
        : { x: crossAt, y: mainAt - mainMin, width: crossSize, height: mainSize });
    const positions = new Map();
    for (const id of ids) {
        const place = toBox(columnStart[layer.get(id)], cross.get(id), mainOf(id), crossOf(id));
        positions.set(id, { ...boxes.get(id), ...place });
    }
    const waypointAt = new Map(waypoints.map((id) => [id, toBox(columnStart[layer.get(id)], cross.get(id), columnSize[layer.get(id)], crossOf(id))]));
    const framed = new Map([...frames].map(([key, frame]) => {
        const box = toBox(frame.main[0], frame.cross[0], frame.main[1] - frame.main[0], frame.cross[1] - frame.cross[0]);
        return [key, { ...frame, ...box, titleBox: { x: box.x + FRAME_PAD, y: box.y + FRAME_PAD, width: frame.title.width, height: frame.title.size } }];
    }));

    // Routes: out of the source to the end of its column, through each waypoint's column, into the target.
    const columnEnd = (id) => columnStart[layer.get(id)] + columnSize[layer.get(id)] - mainMin;
    // A label centers between the end of its source's column and where the arrow next arrives; top
    // to bottom, it stays above the room the next row keeps for box titles.
    const withLabel = (route, edge, forward) => {
        const to = route.via[0]?.in ?? route.end;
        const room = !horizontal && forward ? reserve[layer.get(edge.from) + 1] ?? 0 : 0;
        return { ...route, label: { x: (route.lead.x + to.x) / 2, y: (route.lead.y + to.y - room) / 2 } };
    };
    const routes = graph.edges.map((edge, index) => {
        const a = positions.get(edge.from);
        const b = positions.get(edge.to);
        const via = chains[index].slice(1, -1).map((id) => waypointAt.get(id));
        if (horizontal) {
            const start = { x: a.x + a.width, y: a.y + a.height / 2 };
            const forward = b.x > start.x;
            return withLabel({ start, lead: forward ? { x: Math.max(start.x, columnEnd(edge.from)), y: start.y } : start, via: via.map((w) => ({ in: { x: w.x, y: w.y + w.height / 2 }, out: { x: w.x + w.width, y: w.y + w.height / 2 } })), end: { x: b.x, y: b.y + b.height / 2 } }, edge, forward);
        }
        const start = { x: a.x + a.width / 2, y: a.y + a.height };
        const forward = b.y > start.y;
        return withLabel({ start, lead: forward ? { x: start.x, y: Math.max(start.y, columnEnd(edge.from)) } : start, via: via.map((w) => ({ in: { x: w.x + w.width / 2, y: w.y }, out: { x: w.x + w.width / 2, y: w.y + w.height } })), end: { x: b.x + b.width / 2, y: b.y } }, edge, forward);
    });

    const width = Math.max(horizontal ? main - mainMin : crossTotal, ...[...framed.values()].map((frame) => frame.x + frame.width), 1);
    const height = Math.max(horizontal ? crossTotal : main - mainMin, ...[...framed.values()].map((frame) => frame.y + frame.height), 1);
    return { positions, layerOf: new Map(ids.map((id) => [id, layer.get(id)])), width, height, horizontal, frames: framed, routes };
}

/** The SVG path of a route: a straight lead out of the source's column, curves between columns, straight runs through waypoints. */
export function routePath(route, horizontal) {
    const parts = [`M${route.start.x} ${route.start.y}`];
    if (route.lead.x !== route.start.x || route.lead.y !== route.start.y) parts.push(`L${route.lead.x} ${route.lead.y}`);
    let from = route.lead;
    const targets = [...route.via.map((point) => point.in), route.end];
    targets.forEach((to, index) => {
        const last = index === targets.length - 1;
        const end = last ? (horizontal ? { x: to.x - 2, y: to.y } : { x: to.x, y: to.y - 2 }) : to;
        const bend = horizontal ? Math.max(24, (end.x - from.x) / 2) : Math.max(24, (end.y - from.y) / 2);
        parts.push(horizontal
            ? `C${from.x + bend} ${from.y} ${end.x - bend} ${end.y} ${end.x} ${end.y}`
            : `C${from.x} ${from.y + bend} ${end.x} ${end.y - bend} ${end.x} ${end.y}`);
        if (!last) {
            parts.push(`L${route.via[index].out.x} ${route.via[index].out.y}`);
            from = route.via[index].out;
        }
    });
    return parts.join('');
}

/** Points along a route, for checking that it stays clear of parts. */
export function sampleRoute(route, horizontal, steps = 12) {
    const points = [route.start, route.lead];
    let from = route.lead;
    const targets = [...route.via.map((point) => point.in), route.end];
    targets.forEach((to, index) => {
        const bend = horizontal ? Math.max(24, (to.x - from.x) / 2) : Math.max(24, (to.y - from.y) / 2);
        const [c1, c2] = horizontal ? [{ x: from.x + bend, y: from.y }, { x: to.x - bend, y: to.y }] : [{ x: from.x, y: from.y + bend }, { x: to.x, y: to.y - bend }];
        for (let step = 1; step < steps; step += 1) {
            const t = step / steps;
            const u = 1 - t;
            points.push({ x: u ** 3 * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t ** 3 * to.x, y: u ** 3 * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t ** 3 * to.y });
        }
        if (index < route.via.length) {
            points.push(route.via[index].in, route.via[index].out);
            from = route.via[index].out;
        }
    });
    points.push(route.end);
    return points;
}

/**
 * The drawn edge labels of a laid-out graph: each centered on its route's label point, moved past
 * a box title it would cover, then nudged apart from the other labels in its gap.
 *
 * @param {ReturnType<typeof mapGraph>} graph
 * @param {{ routes: any[], layerOf: Map<string, number>, horizontal: boolean, frames: Map<string, any> }} laid
 * @returns {{ text: string, x: number, y: number, width: number, height: number, gap: number }[]}
 */
export function edgeLabels(graph, laid) {
    const titles = [...laid.frames.values()].map((frame) => frame.titleBox).filter((box) => box && box.width > 0);
    const labels = [];
    graph.edges.forEach((edge, index) => {
        if (!edge.label) return;
        const label = { text: edge.label, ...laid.routes[index].label, width: labelWidth(edge.label), height: labelHeight(edge.label), gap: laid.layerOf.get(edge.from) };
        for (const box of titles) {
            const covers = label.x - label.width / 2 < box.x + box.width && box.x < label.x + label.width / 2 && label.y - label.height / 2 < box.y + box.height && box.y < label.y + label.height / 2;
            if (covers) label.y = box.y + box.height + label.height / 2 + 2;
        }
        labels.push(label);
    });
    return placeLabels(labels, laid.horizontal);
}

/** Keeps edge labels in the same gap from overlapping by nudging them apart along the cross axis. */
export function placeLabels(labels, horizontal) {
    const groups = new Map();
    for (const label of labels) {
        (groups.get(label.gap) ?? groups.set(label.gap, []).get(label.gap)).push(label);
    }
    for (const group of groups.values()) {
        const axis = horizontal ? 'y' : 'x';
        group.sort((a, b) => a[axis] - b[axis]);
        for (let i = 1; i < group.length; i += 1) {
            const need = horizontal ? (group[i - 1].height + group[i].height) / 2 + 4 : (group[i - 1].width + group[i].width) / 2 + 8;
            if (group[i][axis] < group[i - 1][axis] + need) {
                group[i][axis] = group[i - 1][axis] + need;
            }
        }
    }
    return labels;
}

/** The map's views, in the order the canvas offers them. */
export const MAP_VIEWS = Object.freeze(['changes', 'before', 'after']);

const SHOWN = Object.freeze({
    changes: Object.freeze({ parts: ['unchanged', 'changed', 'removed', 'new'], links: ['unchanged', 'removed', 'new'] }),
    before: Object.freeze({ parts: ['unchanged', 'changed', 'removed'], links: ['unchanged', 'removed'] }),
    after: Object.freeze({ parts: ['unchanged', 'changed', 'new'], links: ['unchanged', 'new'] }),
});

/**
 * Whether a part or link shows in a view: Before leaves out what the change adds, After leaves out
 * what it removes, and Changes shows everything.
 *
 * @param {'changes' | 'before' | 'after'} view
 * @param {{ change: string }} item
 * @param {'parts' | 'links'} [kind]
 */
export function shownIn(view, item, kind = 'parts') {
    return SHOWN[view][kind].includes(item.change);
}

/** A part's tag line: "changed · R1, R2", the change alone without reasons, or nothing when unchanged. */
export function tagWords(part) {
    if (part.change === 'unchanged') return '';
    return part.reasonIds.length ? `${part.change} · ${part.reasonIds.join(', ')}` : part.change;
}

/**
 * A part's one-line clause in a view. Before says what changed and removed parts did; Changes and
 * After say what new and changed parts do, and Changes also says what a removed part did.
 */
export function clauseIn(view, part) {
    if (view === 'before') return ['changed', 'removed'].includes(part.change) ? part.before : null;
    if (part.change === 'removed') return view === 'changes' ? part.before : null;
    return ['new', 'changed'].includes(part.change) ? part.after : null;
}

/** The first sentence of an area's prose, for a part's one-line clause. */
function firstSentence(text) {
    const value = String(text ?? '').trim();
    const end = value.search(/(?<=[.!?])\s/);
    return end > 0 ? value.slice(0, end) : value;
}

/** The change of an area's files: all added is new, all deleted is removed, anything else is changed. */
function areaChange(files) {
    if (files.length && files.every((file) => file.status === 'A')) return 'new';
    if (files.length && files.every((file) => file.status === 'D')) return 'removed';
    return 'changed';
}

/**
 * The map to draw: the recorded change map, or, when the agent recorded none, one drawn from the
 * areas, with one part per area and the impact links the areas record. An impact end that names no
 * area becomes an unchanged context part. Null when there is nothing to draw.
 *
 * @param {any} view the page's review view
 * @returns {{ source: 'recorded' | 'areas', title: string, description: string, boxes: any[], parts: any[], links: any[] } | null}
 */
export function mapModel(view) {
    if (view.changeMap) return { source: 'recorded', ...JSON.parse(JSON.stringify(view.changeMap)) };
    if (!view.areas?.length) return null;
    const files = new Map(view.files.map((file) => [file.id, file]));
    const coverage = reasonCoverage(view);
    const order = (view.reasons ?? []).map((reason) => reason.id);
    const reasonsOf = (area) => [...new Set(area.fileIds.flatMap((fileId) => (coverage.byFile[fileId] ?? []).map((segment) => segment.reasonId)).filter(Boolean))]
        .sort((left, right) => order.indexOf(left) - order.indexOf(right));
    const parts = view.areas.map((area) => {
        const change = areaChange(area.fileIds.map((fileId) => files.get(fileId)).filter(Boolean));
        return {
            id: `area:${area.id}`, label: area.title, box: null, change,
            before: change === 'new' ? null : firstSentence(area.before) || 'Not described yet',
            after: change === 'removed' ? null : firstSentence(area.after) || 'Not described yet',
            fileIds: [...area.fileIds], reasonIds: reasonsOf(area),
        };
    });
    const named = new Map();
    for (const area of view.areas) {
        named.set(area.id, `area:${area.id}`);
        if (!named.has(area.title)) named.set(area.title, `area:${area.id}`);
    }
    const context = new Map();
    const partFor = (name) => {
        if (named.has(name)) return named.get(name);
        if (!context.has(name)) context.set(name, `context:${context.size + 1}`);
        return context.get(name);
    };
    const links = [];
    const seen = new Set();
    for (const area of view.areas) {
        for (const edge of area.impact ?? []) {
            const from = partFor(edge.from);
            const to = partFor(edge.to);
            if (from === to || seen.has(`${from}>${to}`)) continue;
            seen.add(`${from}>${to}`);
            links.push({ from, to, label: 'affects', change: 'unchanged', kind: 'uses', anchor: edge.anchor ?? null, uncertainty: edge.uncertainty ?? null, description: edge.description ?? null });
        }
    }
    for (const [name, id] of context) parts.push({ id, label: name, box: null, change: 'unchanged', before: null, after: null, fileIds: [], reasonIds: [] });
    return { source: 'areas', title: 'Drawn from the review areas', description: 'Each part is one review area; arrows are the impact links the areas record.', boxes: [], parts, links };
}

const run = (text, style = {}) => ({ text, bold: false, italic: false, code: false, ...style });
const LINK_MARK = Object.freeze({ new: '+ ', removed: '\u2212 ', unchanged: '' });

/**
 * The graph the layout reads: parts with a label for each view (name, clause, tag line), boxes as
 * titled frames one or two levels deep, and links whose labels carry their change mark and, when the
 * agent recorded doubt, "(unsure)".
 */
export function mapGraph(model) {
    const nodes = new Map();
    for (const part of model.parts) {
        const tag = tagWords(part);
        const variants = Object.fromEntries(MAP_VIEWS.map((view) => {
            const clause = clauseIn(view, part);
            return [view, [[run(part.label, { bold: part.change !== 'unchanged' })], ...(clause ? [[run(clause)]] : []), ...(tag ? [[run(tag)]] : [])]];
        }));
        const longest = Object.values(variants).reduce((widest, lines) => (lines.length > widest.length ? lines : widest));
        nodes.set(part.id, { id: part.id, label: part.label, lines: longest, variants, tag: Boolean(tag), classes: new Set([part.change]), group: part.box });
    }
    const groups = model.boxes.map((box) => ({
        id: box.id, label: box.label, lines: [[run(box.label, { code: true })]], tag: null,
        members: model.parts.filter((part) => part.box === box.id).map((part) => part.id), classes: new Set(), parent: box.parent, depth: box.parent ? 2 : 1,
    }));
    const edges = model.links.map((link) => ({ from: link.from, to: link.to, label: `${LINK_MARK[link.change] ?? ''}${link.label}${link.uncertainty ? ' (unsure)' : ''}`, dashed: link.kind === 'checks', change: link.change }));
    return { direction: 'LR', nodes, edges, groups, title: model.title, description: model.description };
}

/** The graph and its one layout, shared by every view. */
export function layoutMap(model) {
    const graph = mapGraph(model);
    return { graph, laid: layout(graph) };
}

/** A part in words for the text version, with its change, reasons, and before and after lines. */
export function partWords(part) {
    if (part.change === 'unchanged') return part.label;
    const lines = part.change === 'changed' ? `before, ${part.before}; after, ${part.after}` : part.change === 'new' ? part.after : `was ${part.before}`;
    return `${part.label} (${tagWords(part)}): ${lines}`;
}

/**
 * The text version of a view: its parts by box and its links in words, in the order the map lists them.
 * Each link keeps its description and evidence anchor, so the reader can check why it exists.
 *
 * @returns {{ boxes: { label: string, parts: string[] }[], parts: string[],
 *   links: { from: string, to: string, words: string, description: string | null, anchor: any }[] }}
 */
export function mapText(model, view) {
    const shown = model.parts.filter((part) => shownIn(view, part));
    const ids = new Set(shown.map((part) => part.id));
    const label = new Map(model.parts.map((part) => [part.id, part.label]));
    const boxes = model.boxes.map((box) => ({ label: box.label, parts: shown.filter((part) => part.box === box.id).map(partWords) })).filter((box) => box.parts.length);
    const links = model.links.filter((link) => shownIn(view, link, 'links') && ids.has(link.from) && ids.has(link.to))
        .map((link) => ({
            from: link.from, to: link.to, description: link.description ?? null, anchor: link.anchor ?? null,
            words: `${label.get(link.from)} ${link.label} ${label.get(link.to)}${link.change === 'unchanged' ? '' : ` (${link.change})`}${link.kind === 'checks' ? ' (test or doc)' : ''}${link.uncertainty ? ` (unsure: ${link.uncertainty})` : ''}`,
        }));
    return { boxes, parts: shown.filter((part) => !part.box).map(partWords), links };
}
