// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { parseFlowchart } from './flowchart.mjs';

const graphs = new Map();

/** A diagram's graph, kept for the last few sources so each hover does not parse again; null when it cannot be read. */
function graphOf(source) {
    if (!source) return null;
    if (!graphs.has(source)) {
        let graph = null;
        try {
            graph = parseFlowchart(source);
        } catch {
            graph = null;
        }
        if (graphs.size >= 8) graphs.delete(graphs.keys().next().value);
        graphs.set(source, graph);
    }
    return graphs.get(source);
}

/** The file and folder paths label runs name in code, such as `lib/source/workspace.mjs` or `ui/`; a call such as `load()` is not a path. */
function pathsIn(lines) {
    return lines.flat().filter((run) => run.code)
        .flatMap((run) => run.text.split(/[\s,]+/))
        .map((text) => text.replace(/^\.\//, '').replace(/[.,;:]+$/, ''))
        .filter((text) => text && !/[()]/.test(text) && (text.includes('/') || /\.[A-Za-z][A-Za-z0-9]{0,7}$/.test(text)));
}

const escapeRe = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** True when a task reference names a path where a path segment starts: the file itself, or a file inside a folder path. */
function namesPath(reference, path) {
    const end = path.endsWith('/') ? '' : '(?=$|[\\s)\\]`\'":,;#])';
    return new RegExp(`(?:^|[\\s/(\\[\`'"])${escapeRe(path)}${end}`).test(reference);
}

/**
 * A change-map part by its `part:<side>:<id>` reference, read from the session's plan: its
 * label, its boxes outermost first, the phases that change it, and its tasks. Its tasks are
 * those phases' tasks whose References name a path the part or its boxes name in code, where a
 * folder path names the files inside it; when none do, every task in those phases, and
 * `matched` is false. Null when the plan's map has no such part.
 *
 * @param {any} session
 * @param {string} ref
 */
export function mapPart(session, ref) {
    const match = /^part:(before|after):(.+)$/.exec(String(ref));
    const plan = session?.plan;
    const graph = match ? graphOf(plan?.diagram?.[match[1]]) : null;
    const node = graph?.nodes.get(match[2]) ?? null;
    if (!node) return null;
    const groupOf = (id) => graph.groups.find((group) => group.id === id) ?? null;
    const boxes = [];
    for (let group = groupOf(node.group); group; group = groupOf(group.parent)) boxes.unshift(group);
    const phases = (plan.phases ?? []).filter((phase) => (plan.diagram.phaseNodes?.[phase.id] ?? []).includes(node.id));
    const paths = [...new Set([...boxes, node].flatMap((item) => pathsIn(item.lines ?? [])))];
    const candidates = phases.flatMap((phase) => phase.tasks);
    const named = candidates.filter((task) => (task.references ?? []).some((reference) => paths.some((path) => namesPath(reference, path))));
    return { id: ref, kind: 'part', side: match[1], node, boxes, phases, paths, tasks: named.length ? named : candidates, matched: named.length > 0 };
}
