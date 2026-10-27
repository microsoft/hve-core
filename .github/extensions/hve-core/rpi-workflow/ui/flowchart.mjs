// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Reads the Mermaid flowchart subset RPI plans use, without DOM, so the page draws it and
 * the source reader can report a diagram it cannot draw: labeled nodes; solid (`-->`) and
 * dashed (`-.->`) edges, each with an optional label; `class` lines; and `subgraph` groups
 * closed by `end`. `%%` lines, `classDef` styles, and `direction` lines are ignored, and
 * anything else throws, naming the line.
 */

const NODE_RE = /^([A-Za-z][\w-]{0,40})\["([^"\n]{1,120})"\]$/;
const EDGE_RE = /^([A-Za-z][\w-]{0,40})\s*(-->|-\.->)\s*(?:\|([^|\n]{1,60})\|\s*)?([A-Za-z][\w-]{0,40})$/;
const CLASS_RE = /^class\s+([\w,-]{1,400})\s+([A-Za-z][\w-]{0,30})$/;
const GROUP_RE = /^subgraph\s+([A-Za-z][\w-]{0,40})(?:\s*\["([^"\n]{1,120})"\]|\s*\[([^\]\n]{1,120})\])?$/;
const MAX_NODES = 120;
const MAX_EDGES = 240;
const MAX_DEPTH = 8;

/**
 * @typedef {{ id: string, label: string, classes: Set<string> }} FlowNode
 * @typedef {{ from: string, to: string, label: string, dashed: boolean }} FlowEdge
 * @typedef {{ id: string, label: string, members: string[] }} FlowGroup
 */

/**
 * Parses a flowchart; throws an Error naming the first line it cannot read.
 *
 * @param {string} source
 * @returns {{ direction: 'LR' | 'TD', nodes: Map<string, FlowNode>, edges: FlowEdge[], groups: FlowGroup[] }} `groups` lists each subgraph with the nodes it introduced, in source order
 */
export function parseFlowchart(source) {
    const lines = String(source ?? '').split('\n').map((line) => line.trim()).filter((line) => line && !line.startsWith('%%'));
    const header = lines.shift() ?? '';
    const direction = /^flowchart\s+(LR|TD|TB)$/.exec(header)?.[1];
    if (!direction) {
        throw new Error('Only flowchart LR and TD diagrams are supported.');
    }
    const nodes = new Map();
    const edges = [];
    const groups = [];
    const open = [];
    const ensure = (id) => {
        if (!nodes.has(id)) {
            nodes.set(id, { id, label: id, classes: new Set() });
            open.at(-1)?.members.push(id);
        }
        return nodes.get(id);
    };
    for (const line of lines) {
        if (line.startsWith('classDef ') || /^direction\s+(LR|RL|TB|TD|BT)$/.test(line)) continue;
        let match = NODE_RE.exec(line);
        if (match) {
            ensure(match[1]).label = match[2];
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
            }
            continue;
        }
        match = GROUP_RE.exec(line);
        if (match && open.length < MAX_DEPTH) {
            const group = { id: match[1], label: (match[2] ?? match[3] ?? match[1]).trim(), members: [] };
            groups.push(group);
            open.push(group);
            continue;
        }
        if (line === 'end' && open.length) {
            open.pop();
            continue;
        }
        throw new Error(`Unsupported diagram line: ${line.slice(0, 60)}`);
    }
    if (open.length) {
        throw new Error(`The subgraph ${open.at(-1).id} has no end line.`);
    }
    if (nodes.size > MAX_NODES || edges.length > MAX_EDGES) {
        throw new Error(`Diagrams are limited to ${MAX_NODES} parts and ${MAX_EDGES} relationships.`);
    }
    return { direction: direction === 'LR' ? 'LR' : 'TD', nodes, edges, groups };
}
