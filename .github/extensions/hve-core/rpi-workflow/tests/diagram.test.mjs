// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { OLDER_AFTER } from './helpers/older-map.mjs';

let restore;
let diagram;
before(async () => {
    restore = installFakeDom();
    diagram = await import('../ui/diagram.mjs');
});
after(() => restore());

const AFTER = OLDER_AFTER;
/** The planning skill's reference, whose Example change map the canvas must always draw. */
const REFERENCE = fileURLToPath(new URL('../../../../skills/rpi/rpi-plan/references/planning.md', import.meta.url));
/** Groups and dashed edges, as the planning skill's diagrams use them. */
const GROUPED = [
    'flowchart LR',
    '    subgraph first["First pass"]',
    '        a["A"]',
    '        b["B"]',
    '    end',
    '    subgraph second',
    '        direction TB',
    '        c["C"]',
    '    end',
    '    a --> b',
    '    b -.-> c',
    '    a -.->|removed: reads| c',
].join('\n');
/** A change map in the planning skill's format: formatted labels, tags, marks, nested boxes. */
const MAP = [
    'flowchart LR',
    '    accTitle: After: documents paired by work',
    '    accDescr: The reader pairs documents; the page shows them.',
    '    subgraph ws["`<code>lib/source/workspace.mjs</code>`"]',
    '        load["`<code>loadTask()</code>`"]',
    '        pair["`**<code>earlierDocuments()</code>**',
    '        pairs *documents* by name',
    '        changed · P24, P27`"]',
    '        gone["`**<code>oldPairing()</code>**',
    '        removed · P25`"]',
    '    end',
    '    subgraph ui["`<code>ui/</code>`"]',
    '        subgraph dm["`<code>ui/documents.mjs</code>',
    '        new file · P25`"]',
    '            compose["`**<code>composeDocument()</code>**',
    '            new · P25`"]',
    '        end',
    '        board["Task board"]',
    '    end',
    '    load --> pair',
    '    pair -->|feeds| compose',
    '    compose --> board',
    '    pair -.->|replaces| gone',
    '    classDef new stroke-dasharray: 6 4,stroke-width:2px',
    '    classDef changed stroke-width:3px',
    '    classDef removed stroke-dasharray: 2 3,stroke-width:2px',
    '    class compose,dm new',
    '    class pair changed',
    '    class gone removed',
].join('\n');

describe('parseFlowchart', () => {
    it('parses the plan subset and ignores directives and style declarations', () => {
        const graph = diagram.parseFlowchart(AFTER);
        assert.equal(graph.direction, 'LR');
        assert.equal(graph.nodes.size, 10);
        assert.equal(graph.edges.length, 9);
        assert.ok(graph.nodes.get('store').classes.has('new'));
        assert.equal(graph.nodes.get('form').classes.size, 0);
        assert.deepEqual(graph.edges.find((edge) => edge.from === 'sync' && edge.to === 'api'), { from: 'sync', to: 'api', label: 'If-Match PUT', dashed: false });
    });

    it('reads the subgraph groups and dashed edges the planning skill draws', () => {
        const graph = diagram.parseFlowchart(GROUPED);
        assert.deepEqual(graph.groups.map(({ id, label, members, parent, depth }) => ({ id, label, members, parent, depth })), [
            { id: 'first', label: 'First pass', members: ['a', 'b'], parent: null, depth: 1 },
            { id: 'second', label: 'second', members: ['c'], parent: null, depth: 1 },
        ]);
        assert.deepEqual(graph.edges.map((edge) => [edge.from, edge.to, edge.label, edge.dashed]), [['a', 'b', '', false], ['b', 'c', '', true], ['a', 'c', 'removed: reads', true]]);
        assert.equal(graph.nodes.size, 3, 'a group is not a node');
        assert.throws(() => diagram.parseFlowchart('flowchart LR\n  subgraph g\n  a["A"]'), /The subgraph g has no end line/);
        assert.throws(() => diagram.parseFlowchart('flowchart LR\n  a["A"]\n  end'), /Unsupported diagram line: end/);
    });

    it('rejects other diagram types, unknown lines, and oversized graphs', () => {
        assert.throws(() => diagram.parseFlowchart('sequenceDiagram\n  A->>B: hi'), /Only flowchart/);
        assert.throws(() => diagram.parseFlowchart('flowchart LR\n  a["A"]\n  click a call alert()'), /Unsupported diagram line/);
        const many = ['flowchart LR', ...Array.from({ length: 130 }, (_, i) => `n${i}["Node ${i}"]`)].join('\n');
        assert.throws(() => diagram.parseFlowchart(many), /limited to 120 parts/);
    });

    it('reads node labels up to 240 characters and edge labels up to 120, but not longer', () => {
        const graph = diagram.parseFlowchart(`flowchart LR\n  a["${'n'.repeat(240)}"]\n  b["B"]\n  a -->|${'e'.repeat(120)}| b`);
        assert.equal(graph.nodes.get('a').label.length, 240);
        assert.equal(graph.edges[0].label.length, 120);
        assert.throws(() => diagram.parseFlowchart(`flowchart LR\n  a["${'n'.repeat(241)}"]`), /Unsupported diagram line/);
        assert.throws(() => diagram.parseFlowchart(`flowchart LR\n  a -->|${'e'.repeat(121)}| b`), /Unsupported diagram line/);
    });

    it('reads a formatted label over several lines as runs, plain text, and a tag', () => {
        const graph = diagram.parseFlowchart(MAP);
        const pair = graph.nodes.get('pair');
        assert.equal(pair.label, 'earlierDocuments(), pairs documents by name');
        assert.deepEqual(pair.tag, { kind: 'changed', noun: null, phases: ['P24', 'P27'] });
        assert.deepEqual(pair.lines[0], [{ text: 'earlierDocuments()', bold: true, italic: false, code: true }]);
        assert.deepEqual(pair.lines[1].map((run) => [run.text, run.italic]), [['pairs ', false], ['documents', true], [' by name', false]]);
        assert.equal(pair.group, 'ws');
        assert.deepEqual(graph.nodes.get('load').tag, null, 'a part that stays the same has no tag');
        assert.deepEqual(graph.nodes.get('gone').tag, { kind: 'removed', noun: null, phases: ['P25'] });
        assert.ok(graph.nodes.get('gone').classes.has('removed'));
    });

    it('keeps <code> in any label and draws other tags as text, never as markup', () => {
        const graph = diagram.parseFlowchart('flowchart LR\n  a["Uses <code>layout()</code> and <b>bold</b><br>second line"]\n  b["`**x** <img src=x onerror=alert(1)>`"]');
        assert.deepEqual(graph.nodes.get('a').lines.map((line) => line.map((run) => [run.text, run.code])), [[['Uses ', false], ['layout()', true], [' and <b>bold</b>', false]], [['second line', false]]]);
        assert.equal(graph.nodes.get('b').lines[0].at(-1).text, ' <img src=x onerror=alert(1)>');
    });

    it('reads accTitle, accDescr, and an accDescr block', () => {
        assert.equal(diagram.parseFlowchart(MAP).title, 'After: documents paired by work');
        assert.equal(diagram.parseFlowchart(MAP).description, 'The reader pairs documents; the page shows them.');
        const block = diagram.parseFlowchart('flowchart LR\n  accDescr {\n    First line\n    second line\n  }\n  a["A"]');
        assert.equal(block.description, 'First line second line');
        assert.equal(block.title, null);
        assert.throws(() => diagram.parseFlowchart('flowchart LR\n  accDescr {\n  a["A"]'), /no closing brace/);
    });

    it('nests boxes, applies classes to boxes, and reads a box tag', () => {
        const graph = diagram.parseFlowchart(MAP);
        const ui = graph.groups.find((group) => group.id === 'ui');
        const docs = graph.groups.find((group) => group.id === 'dm');
        assert.deepEqual([ui.parent, ui.depth, docs.parent, docs.depth], [null, 1, 'ui', 2]);
        assert.ok(docs.classes.has('new'));
        assert.deepEqual(docs.tag, { kind: 'new', noun: 'file', phases: ['P25'] });
        assert.equal(docs.label, 'ui/documents.mjs');
        assert.deepEqual(docs.members, ['compose']);
        assert.equal(graph.nodes.get('compose').group, 'dm');
    });

    it('still rejects lines the canvas does not draw', () => {
        for (const line of ['click a call alert()', 'style a fill:#f00', 'linkStyle 0 stroke:red', 'a:::new --> b', 'a ==> b', 'a --- b']) {
            assert.throws(() => diagram.parseFlowchart(`flowchart LR\n  a["A"]\n  b["B"]\n  ${line}`), /Unsupported diagram line/, line);
        }
    });
});

describe('layout', () => {
    it('lays out a cycle that empties a layer with real sizes and no empty layer', () => {
        // rpi-skills-cleanup's After: skills and refs point at each other, which once left layer 0 empty.
        const graph = diagram.parseFlowchart([
            'flowchart LR',
            ...['agent', 'skills', 'refs', 'rtpl', 'briefs', 'subs', 'evals', 'docs'].map((id) => `    ${id}["${id}"]`),
            '    agent --> skills', '    skills --> refs', '    refs --> skills', '    refs --> rtpl',
            '    refs --> briefs', '    briefs --> subs', '    evals --> skills', '    docs --> briefs',
        ].join('\n'));
        const { width, height, layerOf, positions } = diagram.layout(graph);
        assert.ok(Number.isFinite(width) && Number.isFinite(height), `${width} x ${height}`);
        const layers = new Set(layerOf.values());
        assert.deepEqual([...layers].sort((a, b) => a - b), Array.from({ length: layers.size }, (_, index) => index));
        assert.ok([...positions.values()].every((box) => Number.isFinite(box.x) && Number.isFinite(box.y)));
    });

    it('places every plan edge across one layer with no crossings or overlaps', () => {
        const graph = diagram.parseFlowchart(AFTER);
        const { positions, layerOf, horizontal } = diagram.layout(graph);
        assert.equal(horizontal, true);
        for (const edge of graph.edges) {
            assert.equal(layerOf.get(edge.to) - layerOf.get(edge.from), 1, `${edge.from} -> ${edge.to}`);
        }
        const byLayer = new Map();
        for (const [id, box] of positions) (byLayer.get(layerOf.get(id)) ?? byLayer.set(layerOf.get(id), []).get(layerOf.get(id))).push(box);
        for (const boxes of byLayer.values()) {
            boxes.sort((a, b) => a.y - b.y);
            for (let i = 1; i < boxes.length; i += 1) assert.ok(boxes[i].y >= boxes[i - 1].y + boxes[i - 1].height, 'boxes overlap');
        }
        const order = (id) => positions.get(id).y;
        const adjacent = graph.edges;
        let crossings = 0;
        for (const a of adjacent) for (const b of adjacent) if (layerOf.get(a.from) === layerOf.get(b.from) && order(a.from) < order(b.from) && order(a.to) > order(b.to)) crossings += 1;
        assert.equal(crossings, 0);
    });

    it('wraps labels at spaces and slashes', () => {
        assert.deepEqual(diagram.wrap('src/api/inspections.ts', 14), ['src/api/', 'inspections.ts']);
        assert.deepEqual(diagram.wrap('Added: sync status chip', 14), ['Added: sync', 'status chip']);
    });

    it('breaks a word longer than a line inside it', () => {
        assert.deepEqual(diagram.wrap('see inspections-offline-sync-status.ts', 14), ['see', 'inspections-of', 'fline-sync-sta', 'tus.ts']);
    });

    it('keeps labels in the same gap from overlapping', () => {
        const labels = diagram.placeLabels([
            { gap: 1, x: 10, y: 50, width: 40, height: 19 },
            { gap: 1, x: 10, y: 55, width: 40, height: 19 },
            { gap: 1, x: 10, y: 52, width: 40, height: 32 },
            { gap: 2, x: 90, y: 50, width: 40, height: 19 },
        ], true);
        const gapOne = labels.filter((label) => label.gap === 1).sort((a, b) => a.y - b.y);
        for (let i = 1; i < gapOne.length; i += 1) {
            assert.ok(gapOne[i].y - gapOne[i - 1].y >= (gapOne[i].height + gapOne[i - 1].height) / 2, 'labels overlap');
        }
        assert.equal(labels[3].y, 50);
    });
});

describe('fitLabel', () => {
    const squash = (text) => text.replace(/\s+/g, '');

    it('keeps a node label that fits four 14-character lines as it was', () => {
        const label = 'Legend: Done, In progress, Bold outline, Dashed border';
        assert.equal(diagram.wrap(label, 14).length, 4);
        assert.deepEqual(diagram.fitLabel(label, diagram.NODE_FIT), { lines: diagram.wrap(label, 14), cut: false });
    });

    it('widens a longer node label before it takes more lines, keeping every word', () => {
        for (const label of ['Chosen phase: a bold outline in the foreground color', 'Task board: progress beside the title; Backlog, In progress, Done; no scroll', 'Phases and tasks: task links land here, expanded; All only when needed']) {
            const { lines, cut } = diagram.fitLabel(label, diagram.NODE_FIT);
            assert.equal(cut, false, label);
            assert.ok(lines.length <= 4 && lines.every((line) => line.length <= 22), label);
            assert.equal(squash(lines.join('')), squash(label));
        }
    });

    it('takes up to eight lines, and only past them ends with an ellipsis and marks the label cut', () => {
        const eight = diagram.fitLabel('abcd '.repeat(30).trim(), diagram.NODE_FIT);
        assert.equal(eight.cut, false);
        assert.equal(eight.lines.length, 8);
        const nine = diagram.fitLabel('abcd '.repeat(33).trim(), diagram.NODE_FIT);
        assert.equal(nine.cut, true);
        assert.equal(nine.lines.length, 8);
        assert.ok(nine.lines.at(-1).endsWith('…'));
        assert.ok(nine.lines.every((line) => line.length <= 22));
    });

    it('fits edge labels in two lines of up to 16 characters, then four', () => {
        assert.deepEqual(diagram.fitLabel('describes', diagram.EDGE_FIT), { lines: ['describes'], cut: false });
        assert.deepEqual(diagram.fitLabel('context tier inherited by', diagram.EDGE_FIT), { lines: ['context tier', 'inherited by'], cut: false });
        const long = diagram.fitLabel('a relationship label that runs on and on well past what four lines of sixteen can hold', diagram.EDGE_FIT);
        assert.equal(long.cut, true);
        assert.equal(long.lines.length, 4);
        assert.ok(long.lines[3].endsWith('…'));
    });
});

describe('renderDiagram', () => {
    it('draws every word of a long label, and gives a cut label a hover title', () => {
        const board = 'Task board: progress beside the title; Backlog, In progress, Done; no scroll';
        const overflow = 'abcdefghijkl '.repeat(9).trim();
        const edge = 'abcdefghi '.repeat(6).trim();
        const source = ['flowchart LR', `    a["${board}"]`, `    b["${overflow}"]`, '    c["C"]', '    a -->|context tier inherited by| b', `    b -->|${edge}| c`].join('\n');
        const markup = serialize(diagram.renderDiagram(source, { caption: 'After', idPrefix: 'long' }));
        const texts = (lines) => lines.map((line) => `>${line}</text>`);
        let at = 0;
        for (const piece of texts(diagram.fitLabel(board, diagram.NODE_FIT).lines)) {
            const found = markup.indexOf(piece, at);
            assert.ok(found > at, `missing ${piece}`);
            at = found;
        }
        assert.doesNotMatch(markup, /<title>Task board/, 'a whole label needs no hover title');
        assert.match(markup, new RegExp(`<g class="diagram-node"><title>${overflow}</title><rect`));
        assert.match(markup, /<g class="diagram-label"><rect [^>]*class="diagram-edge-bg"[^>]*><\/rect><text [^>]*>context tier<\/text><text [^>]*>inherited by<\/text><\/g>/);
        assert.match(markup, new RegExp(`<g class="diagram-label"><title>${edge}</title><rect`));
    });

    it('draws dashed edges dashed and names them and the groups in the text version', () => {
        const markup = serialize(diagram.renderDiagram(GROUPED, { caption: 'After', idPrefix: 'grouped' }));
        assert.equal((markup.match(/class="diagram-edge is-dashed"/g) ?? []).length, 2);
        assert.equal((markup.match(/class="diagram-edge"/g) ?? []).length, 1);
        assert.match(markup, /<li>B connects to C \(dashed line\)<\/li>/);
        assert.match(markup, /<li>A removed: reads C \(dashed line\)<\/li>/);
        assert.match(markup, /<li>Group First pass: A, B<\/li><li>Group second: C<\/li>/);
        assert.doesNotMatch(markup, /is-fallback/);
    });

    it('marks a map that shows progress, so its chosen phase is drawn as an outline', () => {
        const withProgress = diagram.renderDiagram(AFTER, { caption: 'After', idPrefix: 'map', highlight: ['store'], progress: new Map([['store', 'done']]) });
        const plain = diagram.renderDiagram(AFTER, { caption: 'After', idPrefix: 'plan', highlight: ['store'] });
        assert.match(serialize(withProgress), /<svg [^>]*class="diagram-svg has-progress"/);
        assert.match(serialize(plain), /<svg [^>]*class="diagram-svg"/);
        assert.doesNotMatch(serialize(plain), /has-progress/, 'Plan\'s map keeps its fill for the chosen phase');
    });

    it('draws a labeled SVG figure with a text alternative', () => {
        const figure = diagram.renderDiagram(AFTER, { caption: 'After', idPrefix: 'map', highlight: ['store'] });
        const svg = elements(figure).find((el) => el.localName === 'svg');
        assert.equal(svg.getAttribute('role'), 'img');
        assert.match(elements(figure).find((el) => el.localName === 'title').textContent, /10 parts and 9 relationships/);
        const list = elements(figure).find((el) => el.className === 'diagram-text');
        assert.equal(list.childNodes.length, 19);
        assert.ok(elements(figure).some((el) => el.className === 'diagram-node is-new is-highlight'));
        assert.match(svg.style.minWidth, /^\d+px$/);
    });

    it('falls back to the source for unsupported diagrams', () => {
        const figure = diagram.renderDiagram('graph TD\n  A --> B', { caption: 'Before', idPrefix: 'x' });
        assert.ok(figure.className.includes('is-fallback'));
        assert.equal(elements(figure).find((el) => el.localName === 'code').textContent, 'graph TD\n  A --> B');
    });
});

describe('the planning skill\'s change map', () => {
    it('draws the reference\'s Before and After example without falling back to source', () => {
        const text = readFileSync(REFERENCE, 'utf8');
        const start = text.indexOf('\n### Example change map\n');
        assert.notEqual(start, -1, 'the reference has an Example change map section');
        const end = text.slice(start + 1).search(/\n#{2,3} /);
        const section = end === -1 ? text.slice(start) : text.slice(start, start + 1 + end);
        const blocks = [...section.matchAll(/```mermaid\n([\s\S]*?)```/g)].map((match) => match[1]);
        assert.equal(blocks.length, 2, 'one Before and one After');
        for (const source of blocks) {
            const graph = diagram.parseFlowchart(source);
            assert.ok(graph.title && graph.description, 'accTitle and accDescr');
            assert.ok(graph.groups.length > 0, 'boxes');
            assert.ok([...graph.nodes.values()].some((node) => node.tag), 'tags');
            const figure = diagram.renderDiagram(source, { caption: graph.title, idPrefix: 'reference' });
            assert.ok(!figure.className.includes('is-fallback'), graph.title);
        }
    });

    it('keeps drawing a map written in the older format', () => {
        const graph = diagram.parseFlowchart(OLDER_AFTER);
        assert.equal(graph.nodes.size, 10);
        assert.ok([...graph.nodes.values()].every((node) => node.tag === null));
        assert.ok(!diagram.renderDiagram(OLDER_AFTER, { caption: 'After', idPrefix: 'older' }).className.includes('is-fallback'));
    });
});
