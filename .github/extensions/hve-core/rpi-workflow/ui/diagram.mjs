// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h } from './dom.mjs';
import { parseFlowchart } from './flowchart.mjs';

export { parseFlowchart };

/**
 * Draws the Mermaid flowchart subset RPI plans use (see `./flowchart.mjs`) as native SVG with a
 * text alternative. Boxes draw as titled frames that hold their parts and never overlap, an arrow
 * that spans columns bends around the parts between its ends, labels keep their bold, italic,
 * and code runs and every word (see `fitRuns`), and new, changed, and removed parts and boxes
 * carry dashed, thick, and dotted borders. A diagram it cannot read falls back to its source,
 * with the reason in the caption.
 */

const SVG_NS = 'http://www.w3.org/2000/svg';
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
 * to reduce crossings. Boxes stack as bands across the columns, a box inside a box as a band
 * inside its band, so each box's parts stay together and frames never overlap.
 *
 * @returns {{ positions: Map<string, any>, layerOf: Map<string, number>, width: number, height: number, horizontal: boolean, frames: Map<string, any>, routes: any[] }}
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
    for (const id of [...ids].sort((a, b) => layer.get(b) - layer.get(a))) {
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
        const fit = fitRuns(node.lines, NODE_FIT);
        const width = Math.min(184, Math.max(88, Math.max(...fit.lines.map((line) => lineWidth(line, NODE_CHARS))) + 24));
        boxes.set(id, { lines: fit.lines, cut: fit.cut, tagFrom: fit.lines.length - (fit.cut ? 0 : tagLineCount(node, fit.width)), width, height: fit.lines.length * NODE_LINE + NODE_PAD });
    }
    for (const id of waypoints) boxes.set(id, { width: horizontal ? 0 : WAYPOINT, height: horizontal ? WAYPOINT : 0 });
    const mainOf = (id) => (horizontal ? boxes.get(id).width : boxes.get(id).height);
    const crossOf = (id) => (horizontal ? boxes.get(id).height : boxes.get(id).width);

    const gaps = layers.map((_group, index) => {
        const labels = graph.edges.filter((edge) => edge.label && layer.get(edge.from) === index).map((edge) => (horizontal ? labelWidth(edge.label) : labelHeight(edge.label)));
        return Math.min(150, Math.max(56, Math.max(0, ...labels) + 28));
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
    const titles = new Map();
    for (const [key, band] of bands) {
        if (!band.group) continue;
        const fit = fitRuns(band.group.lines, TITLE_FIT);
        titles.set(key, { lines: fit.lines, tagFrom: fit.lines.length - (fit.cut ? 0 : tagLineCount(band.group, fit.width)), width: Math.max(...fit.lines.map((line) => lineWidth(line, TITLE_CHARS)), 0), size: fit.lines.length * TITLE_LINE });
    }
    const cross = new Map();
    const frames = new Map();
    const placeRow = (key, start) => {
        const cells = layers.map((group = []) => group.filter((id) => rowOf.get(id) === key));
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
    const crossTotal = placeBand(ROOT, 0);

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
    const framed = new Map([...frames].map(([key, frame]) => [key, { ...frame, ...toBox(frame.main[0], frame.cross[0], frame.main[1] - frame.main[0], frame.cross[1] - frame.cross[0]) }]));

    // Routes: out of the source to the end of its column, through each waypoint's column, into the target.
    const columnEnd = (id) => columnStart[layer.get(id)] + columnSize[layer.get(id)] - mainMin;
    const routes = graph.edges.map((edge, index) => {
        const a = positions.get(edge.from);
        const b = positions.get(edge.to);
        const via = chains[index].slice(1, -1).map((id) => waypointAt.get(id));
        if (horizontal) {
            const start = { x: a.x + a.width, y: a.y + a.height / 2 };
            const forward = b.x > start.x;
            return { start, lead: forward ? { x: Math.max(start.x, columnEnd(edge.from)), y: start.y } : start, via: via.map((w) => ({ in: { x: w.x, y: w.y + w.height / 2 }, out: { x: w.x + w.width, y: w.y + w.height / 2 } })), end: { x: b.x, y: b.y + b.height / 2 } };
        }
        const start = { x: a.x + a.width / 2, y: a.y + a.height };
        const forward = b.y > start.y;
        return { start, lead: forward ? { x: start.x, y: Math.max(start.y, columnEnd(edge.from)) } : start, via: via.map((w) => ({ in: { x: w.x + w.width / 2, y: w.y }, out: { x: w.x + w.width / 2, y: w.y + w.height } })), end: { x: b.x + b.width / 2, y: b.y } };
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

const svg = (tag, attrs = {}) => {
    const element = document.createElementNS(SVG_NS, tag);
    for (const [key, value] of Object.entries(attrs)) element.setAttribute(key, String(value));
    return element;
};

/** A hover title holding a label the drawing had to cut. */
const fullLabel = (text) => {
    const title = svg('title');
    title.textContent = text;
    return title;
};

/** One drawn line of runs. A line of plain text is the text itself; styled runs become `tspan` elements. */
function textLine(runs, attrs) {
    const text = svg('text', attrs);
    if (runs.length === 1 && !runs[0].bold && !runs[0].italic && !runs[0].code) {
        text.textContent = runs[0].text;
        return text;
    }
    for (const run of runs) {
        const span = svg('tspan', { class: ['diagram-run', run.bold ? 'is-bold' : '', run.italic ? 'is-italic' : '', run.code ? 'is-code' : ''].filter(Boolean).join(' ') });
        span.textContent = run.text;
        text.append(span);
    }
    return text;
}

const MARKS = ['new', 'changed', 'removed'];
const markClasses = (classes) => MARKS.filter((mark) => classes.has(mark)).map((mark) => `is-${mark}`);
const phaseList = (phases) => (phases.length > 1 ? `${phases.slice(0, -1).join(', ')} and ${phases.at(-1)}` : phases[0]);

/** How a part or box changes, in words: "(changed in P24 and P27)", or "(new)" in an older plan. */
export function changeWords(item) {
    if (item.tag) return ` (${item.tag.noun ? `${item.tag.kind} ${item.tag.noun}` : item.tag.kind} in ${phaseList(item.tag.phases)})`;
    const mark = MARKS.find((name) => item.classes.has(name));
    return mark ? ` (${mark})` : '';
}

/** The marks a diagram draws: `new`, `changed`, and `removed` on parts or boxes, for its legend. */
export function diagramMarks(source) {
    try {
        const graph = parseFlowchart(source);
        return new Set([...graph.nodes.values(), ...graph.groups].flatMap((item) => MARKS.filter((mark) => item.classes.has(mark))));
    } catch {
        return new Set();
    }
}

const MARK_WORDS = { new: 'Dashed border: new.', changed: 'Thick border: changed.', removed: 'Dotted border: removed.' };

/** Legend entries for the change marks a diagram draws, each a swatch and its words. */
export function markLegend(source) {
    const marks = diagramMarks(source);
    return MARKS.filter((mark) => marks.has(mark)).flatMap((mark) => [h('span', { class: `legend-swatch is-${mark}` }), ` ${MARK_WORDS[mark]} `]);
}

const PROGRESS_WORDS = { done: 'done', active: 'in progress' };

/**
 * @param {string} source
 * @param {{ caption?: string, defaultCaption?: string, captionSuffix?: string, highlight?: Iterable<string>, progress?: Map<string, 'done' | 'active'>, idPrefix: string, textOpen?: boolean, onTextToggle?: (open: boolean) => void }} options
 *   `caption` replaces the diagram's own title; otherwise the caption is its `accTitle`, else
 *   `defaultCaption`, followed by `captionSuffix`. `progress` marks parts done or in progress,
 *   with a corner mark so color is not the only cue.
 * @returns {HTMLElement}
 */
export function renderDiagram(source, options) {
    let graph;
    try {
        graph = parseFlowchart(source);
    } catch (error) {
        return h('figure', { class: 'diagram is-fallback' },
            h('figcaption', null, options.caption ?? options.defaultCaption ?? 'Diagram', h('span', { class: 'meta', text: ` (shown as source: ${error instanceof Error ? error.message : 'unsupported'})` })),
            h('pre', { class: 'md-code', tabindex: '0' }, h('code', { text: source })));
    }
    const caption = options.caption ?? `${graph.title ?? options.defaultCaption ?? 'Diagram'}${options.captionSuffix ?? ''}`;
    const highlight = new Set(options.highlight ?? []);
    const progress = options.progress ?? new Map();
    const { positions, layerOf, width, height, horizontal, frames, routes } = layout(graph);
    const pad = 12;
    const titleId = `${options.idPrefix}-title`;
    const descId = `${options.idPrefix}-desc`;
    const root = svg('svg', { viewBox: `${-pad} ${-pad} ${width + pad * 2} ${height + pad * 2}`, width: width + pad * 2, height: height + pad * 2, role: 'img', 'aria-labelledby': titleId, class: options.progress ? 'diagram-svg has-progress' : 'diagram-svg' });
    const title = svg('title', { id: titleId });
    title.textContent = `${caption}: ${graph.nodes.size} parts and ${graph.edges.length} relationships. A text version follows.`;
    root.append(title);
    if (graph.description) {
        const desc = svg('desc', { id: descId });
        desc.textContent = graph.description;
        root.append(desc);
        root.setAttribute('aria-describedby', descId);
    }
    const defs = svg('defs');
    const marker = svg('marker', { id: `${options.idPrefix}-arrow`, viewBox: '0 0 10 10', refX: '9', refY: '5', markerWidth: '7', markerHeight: '7', orient: 'auto-start-reverse' });
    marker.append(svg('path', { d: 'M0 0L10 5L0 10z', class: 'diagram-arrow' }));
    defs.append(marker);
    root.append(defs);
    for (const frame of [...frames.values()].sort((a, b) => a.depth - b.depth)) {
        const group = svg('g', { class: ['diagram-box', `is-depth-${frame.depth}`, ...markClasses(frame.group.classes)].join(' ') });
        group.append(svg('rect', { x: frame.x, y: frame.y, width: frame.width, height: frame.height, rx: 8 }));
        frame.title.lines.forEach((line, index) => {
            group.append(textLine(line, { x: frame.x + FRAME_PAD, y: frame.y + FRAME_PAD + 11 + index * TITLE_LINE, class: index >= frame.title.tagFrom ? 'diagram-box-title diagram-tag' : 'diagram-box-title' }));
        });
        root.append(group);
    }
    const labels = [];
    graph.edges.forEach((edge, index) => {
        const route = routes[index];
        root.append(svg('path', { d: routePath(route, horizontal), class: edge.dashed ? 'diagram-edge is-dashed' : 'diagram-edge', 'marker-end': `url(#${options.idPrefix}-arrow)` }));
        if (edge.label) {
            const to = route.via[0]?.in ?? route.end;
            labels.push({ text: edge.label, x: (route.lead.x + to.x) / 2, y: (route.lead.y + to.y) / 2, width: labelWidth(edge.label), height: labelHeight(edge.label), gap: layerOf.get(edge.from) });
        }
    });
    for (const label of placeLabels(labels, horizontal)) {
        const fit = fitLabel(label.text, EDGE_FIT);
        const group = svg('g', { class: 'diagram-label' });
        if (fit.cut) group.append(fullLabel(label.text));
        group.append(svg('rect', { x: label.x - label.width / 2, y: label.y - label.height / 2, width: label.width, height: label.height, rx: 4, class: 'diagram-edge-bg' }));
        fit.lines.forEach((line, index, all) => {
            const text = svg('text', { x: label.x, y: label.y + 4 + (index - (all.length - 1) / 2) * 13, 'text-anchor': 'middle', class: 'diagram-edge-label' });
            text.textContent = line;
            group.append(text);
        });
        root.append(group);
    }
    for (const [id, node] of graph.nodes) {
        const box = positions.get(id);
        const state = progress.get(id);
        const classes = ['diagram-node', ...markClasses(node.classes), highlight.has(id) || node.classes.has('phase') ? 'is-highlight' : '', state ? `is-${state}` : ''].filter(Boolean).join(' ');
        const group = svg('g', { class: classes });
        if (box.cut) group.append(fullLabel(`${node.label}${changeWords(node)}`));
        group.append(svg('rect', { x: box.x, y: box.y, width: box.width, height: box.height, rx: 6 }));
        box.lines.forEach((line, index) => {
            group.append(textLine(line, { x: box.x + box.width / 2, y: box.y + 22 + index * NODE_LINE, 'text-anchor': 'middle', ...(index >= box.tagFrom ? { class: 'diagram-tag' } : {}) }));
        });
        if (state) {
            // A corner mark: a check for done, a dot for in progress.
            const mark = svg('g', { class: `diagram-mark is-${state}` });
            const cx = box.x + box.width - 2;
            const cy = box.y + 2;
            mark.append(svg('circle', { cx, cy, r: 7 }));
            mark.append(state === 'done' ? svg('path', { d: `M${cx - 3} ${cy}l2 2 4-4`, class: 'diagram-mark-glyph' }) : svg('circle', { cx, cy, r: 2.5, class: 'diagram-mark-glyph' }));
            group.append(mark);
        }
        root.append(group);
    }
    const describe = (id) => graph.nodes.get(id).label;
    const partText = (node) => `${node.label}${changeWords(node)}${PROGRESS_WORDS[progress.get(node.id)] ? ` (${PROGRESS_WORDS[progress.get(node.id)]})` : ''}${highlight.has(node.id) ? ' (highlighted)' : ''}`;
    const boxOf = (node) => {
        let group = graph.groups.find((candidate) => candidate.id === node.group) ?? null;
        while (group && group.depth > 2) group = graph.groups.find((candidate) => candidate.id === group.parent) ?? null;
        return group;
    };
    const boxNames = (group) => {
        const names = [];
        for (let current = group; current; current = graph.groups.find((candidate) => candidate.id === current.parent) ?? null) names.unshift(`${current.label}${changeWords(current)}`);
        return names.join(', in ');
    };
    const inBoxes = graph.groups.filter((group) => group.depth <= 2).map((group) => {
        const parts = [...graph.nodes.values()].filter((node) => boxOf(node)?.id === group.id);
        return parts.length ? h('li', { text: `In ${boxNames(group)}: ${parts.map(partText).join('; ')}` }) : null;
    }).filter(Boolean);
    const list = h('ul', { class: 'diagram-text' },
        inBoxes,
        [...graph.nodes.values()].filter((node) => !boxOf(node)).map((node) => h('li', { text: partText(node) })),
        graph.edges.map((edge) => h('li', { text: `${describe(edge.from)} ${edge.label || 'connects to'} ${describe(edge.to)}${edge.dashed ? ' (dashed line)' : ''}` })));
    // Scales down to fit its column, then scrolls rather than shrinking text below 80 percent.
    root.style.minWidth = `${Math.round((width + pad * 2) * 0.8)}px`;
    return h('figure', { class: 'diagram' },
        h('div', { class: 'diagram-scroll', tabindex: '0', role: 'region', 'aria-label': `${caption}, scrollable` }, root),
        h('figcaption', null, caption),
        h('details', { class: 'diagram-details', open: Boolean(options.textOpen), ontoggle: (event) => options.onTextToggle?.(event.target.open) }, h('summary', { text: 'Show as text' }), list));
}
