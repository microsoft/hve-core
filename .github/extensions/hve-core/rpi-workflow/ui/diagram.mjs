// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { h } from './dom.mjs';
import { parseFlowchart } from './flowchart.mjs';

export { parseFlowchart };

/**
 * Draws the Mermaid flowchart subset RPI plans use (see `./flowchart.mjs`) as native SVG with
 * a text alternative. A dashed edge draws dashed; subgraph groups appear in the text version.
 * Labels keep every word (see `fitLabel`). A diagram it cannot read falls back to its source,
 * with the reason in the caption.
 */

const SVG_NS = 'http://www.w3.org/2000/svg';

/**
 * Wraps at spaces and slashes, so paths such as src/api/file.ts can break too. A word longer
 * than `width` breaks inside it, so no line is wider than `width`.
 */
export function wrap(label, width) {
    const tokens = label.split(/(?<=[\s/])/).flatMap((token) => {
        const word = token.trimEnd();
        if (word.length <= width) return [token];
        const pieces = word.match(new RegExp(`.{1,${width}}`, 'gu'));
        pieces[pieces.length - 1] += token.slice(word.length);
        return pieces;
    });
    const lines = [];
    let current = '';
    for (const token of tokens) {
        if (current && (current + token).trimEnd().length > width) {
            lines.push(current.trimEnd());
            current = token.trimStart();
        } else {
            current += token;
        }
    }
    if (current.trim()) lines.push(current.trimEnd());
    return lines;
}

/** Node labels: 14 to 22 characters a line, four lines before a box grows taller, at most eight. */
export const NODE_FIT = Object.freeze({ min: 14, max: 22, lines: 4, cap: 8 });
/** Edge labels: 10 to 16 characters a line, two lines before a label grows taller, at most four. */
export const EDGE_FIT = Object.freeze({ min: 10, max: 16, lines: 2, cap: 4 });

/**
 * Fits a label into lines without losing words: the narrowest width from `fit.min` to `fit.max`
 * that needs at most `fit.lines` lines, else `fit.max` wide with up to `fit.cap` lines. Only a
 * label longer than that is cut: its last line ends with an ellipsis and `cut` is true, so the
 * caller can show the full label on hover.
 *
 * @param {string} label
 * @param {{ min: number, max: number, lines: number, cap: number }} fit
 * @returns {{ lines: string[], cut: boolean }}
 */
export function fitLabel(label, fit) {
    for (let width = fit.min; width < fit.max; width += 1) {
        const lines = wrap(label, width);
        if (lines.length <= fit.lines) return { lines, cut: false };
    }
    const lines = wrap(label, fit.max);
    if (lines.length <= fit.cap) return { lines, cut: false };
    const kept = lines.slice(0, fit.cap);
    kept[fit.cap - 1] = `${kept[fit.cap - 1].slice(0, fit.max - 1).trimEnd()}…`;
    return { lines: kept, cut: true };
}

const labelLines = (text) => fitLabel(text, EDGE_FIT).lines;
const labelWidth = (text) => Math.max(...labelLines(text).map((line) => line.length)) * 6 + 12;
const labelHeight = (text) => labelLines(text).length * 13 + 6;

/**
 * Layered layout: longest-path layers, nodes pulled toward their successors so edges
 * span one layer where possible, then barycenter sweeps to reduce crossings.
 */
export function layout(graph) {
    const ids = [...graph.nodes.keys()];
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
    // Pulling nodes toward their successors can empty a layer, such as in a cycle; renumber so none is.
    const used = [...new Set(layer.values())].sort((a, b) => a - b);
    const dense = new Map(used.map((value, index) => [value, index]));
    for (const id of ids) layer.set(id, dense.get(layer.get(id)));
    const layers = [];
    for (const id of ids) {
        (layers[layer.get(id)] ??= []).push(id);
    }
    const position = new Map();
    layers.forEach((group = []) => group.forEach((id, index) => position.set(id, index)));
    const sweep = (neighbors, from, to, step) => {
        for (let i = from; i !== to; i += step) {
            const group = layers[i];
            if (!group) continue;
            const movable = [];
            const fixed = new Map();
            group.forEach((id, index) => {
                const linked = neighbors.get(id).filter((other) => layer.get(other) === i - step);
                if (linked.length) movable.push([id, linked.reduce((sum, other) => sum + position.get(other), 0) / linked.length]);
                else fixed.set(index, id);
            });
            movable.sort((a, b) => a[1] - b[1]);
            let next = 0;
            layers[i] = group.map((_id, index) => (fixed.has(index) ? fixed.get(index) : movable[next++][0]));
            layers[i].forEach((id, index) => position.set(id, index));
        }
    };
    const adjacent = graph.edges.filter((edge) => layer.get(edge.to) === layer.get(edge.from) + 1);
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
        sweep(incoming, 1, layers.length, 1);
        sweep(outgoing, layers.length - 2, -1, -1);
        const count = crossings();
        if (count < best.count) best = { count, layers: layers.map((group) => (group ? [...group] : group)) };
    }
    best.layers.forEach((group, index) => {
        layers[index] = group;
        (group ?? []).forEach((id, slot) => position.set(id, slot));
    });
    const boxes = new Map();
    for (const id of ids) {
        const { lines, cut } = fitLabel(graph.nodes.get(id).label, NODE_FIT);
        const width = Math.min(184, Math.max(88, Math.max(...lines.map((line) => line.length)) * 6.9 + 24));
        boxes.set(id, { lines, cut, width, height: lines.length * 17 + 18 });
    }
    const horizontal = graph.direction === 'LR';
    const gaps = layers.map((_group, index) => {
        const labels = graph.edges.filter((edge) => edge.label && layer.get(edge.from) === index).map((edge) => (horizontal ? labelWidth(edge.label) : labelHeight(edge.label)));
        return Math.min(150, Math.max(56, Math.max(0, ...labels) + 28));
    });
    const gapCross = 20;
    const positions = new Map();
    let main = 0;
    const crossSizes = layers.map((group = []) => group.reduce((sum, id) => sum + (horizontal ? boxes.get(id).height : boxes.get(id).width) + gapCross, -gapCross));
    const crossTotal = Math.max(...crossSizes, 0);
    layers.forEach((group = [], index) => {
        const mainSize = Math.max(...group.map((id) => (horizontal ? boxes.get(id).width : boxes.get(id).height)), 0);
        let cross = (crossTotal - crossSizes[index]) / 2;
        for (const id of group) {
            const box = boxes.get(id);
            positions.set(id, horizontal ? { x: main, y: cross, ...box } : { x: cross, y: main, ...box });
            cross += (horizontal ? box.height : box.width) + gapCross;
        }
        main += mainSize + (index < layers.length - 1 ? gaps[index] : 0);
    });
    const width = horizontal ? main : crossTotal;
    const height = horizontal ? crossTotal : main;
    return { positions, layerOf: layer, width: Math.max(width, 1), height: Math.max(height, 1), horizontal };
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

/**
 * @param {string} source
 * @param {{ caption: string, highlight?: Iterable<string>, progress?: Map<string, 'done' | 'active'>, idPrefix: string, textOpen?: boolean, onTextToggle?: (open: boolean) => void }} options
 *   `progress` marks nodes done or in progress, with a corner mark so color is not the only cue.
 * @returns {HTMLElement}
 */
export function renderDiagram(source, options) {
    let graph;
    try {
        graph = parseFlowchart(source);
    } catch (error) {
        return h('figure', { class: 'diagram is-fallback' },
            h('figcaption', null, options.caption, h('span', { class: 'meta', text: ` (shown as source: ${error instanceof Error ? error.message : 'unsupported'})` })),
            h('pre', { class: 'md-code', tabindex: '0' }, h('code', { text: source })));
    }
    const highlight = new Set(options.highlight ?? []);
    const progress = options.progress ?? new Map();
    const { positions, layerOf, width, height, horizontal } = layout(graph);
    const pad = 12;
    const titleId = `${options.idPrefix}-title`;
    const root = svg('svg', { viewBox: `${-pad} ${-pad} ${width + pad * 2} ${height + pad * 2}`, width: width + pad * 2, height: height + pad * 2, role: 'img', 'aria-labelledby': titleId, class: options.progress ? 'diagram-svg has-progress' : 'diagram-svg' });
    const title = svg('title', { id: titleId });
    title.textContent = `${options.caption}: ${graph.nodes.size} parts and ${graph.edges.length} relationships. A text version follows.`;
    root.append(title);
    const defs = svg('defs');
    const marker = svg('marker', { id: `${options.idPrefix}-arrow`, viewBox: '0 0 10 10', refX: '9', refY: '5', markerWidth: '7', markerHeight: '7', orient: 'auto-start-reverse' });
    marker.append(svg('path', { d: 'M0 0L10 5L0 10z', class: 'diagram-arrow' }));
    defs.append(marker);
    root.append(defs);
    const labels = [];
    for (const edge of graph.edges) {
        const a = positions.get(edge.from);
        const b = positions.get(edge.to);
        const [x1, y1, x2, y2] = horizontal ? [a.x + a.width, a.y + a.height / 2, b.x, b.y + b.height / 2] : [a.x + a.width / 2, a.y + a.height, b.x + b.width / 2, b.y];
        const bend = horizontal ? Math.max(24, (x2 - x1) / 2) : Math.max(24, (y2 - y1) / 2);
        const d = horizontal ? `M${x1} ${y1}C${x1 + bend} ${y1} ${x2 - bend} ${y2} ${x2 - 2} ${y2}` : `M${x1} ${y1}C${x1} ${y1 + bend} ${x2} ${y2 - bend} ${x2} ${y2 - 2}`;
        root.append(svg('path', { d, class: edge.dashed ? 'diagram-edge is-dashed' : 'diagram-edge', 'marker-end': `url(#${options.idPrefix}-arrow)` }));
        if (edge.label) {
            labels.push({ text: edge.label, x: (x1 + x2) / 2, y: (y1 + y2) / 2, width: labelWidth(edge.label), height: labelHeight(edge.label), gap: layerOf.get(edge.from) });
        }
    }
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
        const classes = ['diagram-node', node.classes.has('new') ? 'is-new' : '', highlight.has(id) || node.classes.has('phase') ? 'is-highlight' : '', state ? `is-${state}` : ''].filter(Boolean).join(' ');
        const group = svg('g', { class: classes });
        if (box.cut) group.append(fullLabel(node.label));
        group.append(svg('rect', { x: box.x, y: box.y, width: box.width, height: box.height, rx: 6 }));
        box.lines.forEach((line, index) => {
            const text = svg('text', { x: box.x + box.width / 2, y: box.y + 22 + index * 17, 'text-anchor': 'middle' });
            text.textContent = line;
            group.append(text);
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
    const list = h('ul', { class: 'diagram-text' },
        [...graph.nodes.values()].map((node) => h('li', { text: `${node.label}${node.classes.has('new') ? ' (new)' : ''}${progress.get(node.id) === 'done' ? ' (done)' : progress.get(node.id) === 'active' ? ' (in progress)' : ''}${highlight.has(node.id) ? ' (highlighted)' : ''}` })),
        graph.edges.map((edge) => h('li', { text: `${describe(edge.from)} ${edge.label || 'connects to'} ${describe(edge.to)}${edge.dashed ? ' (dashed line)' : ''}` })),
        graph.groups.filter((group) => group.members.length).map((group) => h('li', { text: `Group ${group.label}: ${group.members.map(describe).join(', ')}` })));
    // Scales down to fit its column, then scrolls rather than shrinking text below 80 percent.
    root.style.minWidth = `${Math.round((width + pad * 2) * 0.8)}px`;
    return h('figure', { class: 'diagram' },
        h('div', { class: 'diagram-scroll', tabindex: '0', role: 'region', 'aria-label': `${options.caption}, scrollable` }, root),
        h('figcaption', null, options.caption),
        h('details', { class: 'diagram-details', open: Boolean(options.textOpen), ontoggle: (event) => options.onTextToggle?.(event.target.open) }, h('summary', { text: 'Show as text' }), list));
}
