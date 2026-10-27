// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { buildScenario } from '../lib/scenario.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';

let restore;
let diagram;
before(async () => {
    restore = installFakeDom();
    diagram = await import('../ui/diagram.mjs');
});
after(() => restore());

const AFTER = buildScenario('plan').plan.diagram.after;

describe('parseFlowchart', () => {
    it('parses the plan subset and ignores directives and style declarations', () => {
        const graph = diagram.parseFlowchart(AFTER);
        assert.equal(graph.direction, 'LR');
        assert.equal(graph.nodes.size, 10);
        assert.equal(graph.edges.length, 9);
        assert.ok(graph.nodes.get('store').classes.has('new'));
        assert.equal(graph.nodes.get('form').classes.size, 0);
        assert.deepEqual(graph.edges.find((edge) => edge.from === 'sync' && edge.to === 'api'), { from: 'sync', to: 'api', label: 'If-Match PUT' });
    });

    it('rejects other diagram types, unknown lines, and oversized graphs', () => {
        assert.throws(() => diagram.parseFlowchart('sequenceDiagram\n  A->>B: hi'), /Only flowchart/);
        assert.throws(() => diagram.parseFlowchart('flowchart LR\n  a["A"]\n  click a call alert()'), /Unsupported diagram line/);
        const many = ['flowchart LR', ...Array.from({ length: 130 }, (_, i) => `n${i}["Node ${i}"]`)].join('\n');
        assert.throws(() => diagram.parseFlowchart(many), /limited to 120 parts/);
    });
});

describe('layout', () => {
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

describe('renderDiagram', () => {
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
