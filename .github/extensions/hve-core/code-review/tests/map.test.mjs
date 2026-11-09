// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { clauseIn, layoutMap, MAP_VIEWS, mapModel, mapText, shownIn, tagWords } from '../ui/map.mjs';

function recorded() {
    const part = (id, label, box, change, before, after, reasonIds = []) => ({ id, label, box, change, before, after, fileIds: [], reasonIds });
    return {
        title: 'After: the page draws its map with new modules', description: 'The page draws the map with two new modules and stops drawing impact per area.',
        boxes: [
            { id: 'core', label: 'code-review-core/', parent: null },
            { id: 'canvas', label: 'extensions/hve-core/code-review/', parent: null },
            { id: 'ui', label: 'ui/', parent: 'canvas' },
        ],
        parts: [
            part('ops', 'operations.mjs', 'core', 'changed', 'Accepted areas only', 'Accepts reasons and the map', ['R1']),
            part('state', 'review-state.json', null, 'unchanged', null, null),
            part('app', 'app.mjs', 'ui', 'changed', 'Drew impact per area', 'Draws one change map', ['R2']),
            part('diagram', 'diagram.mjs', 'ui', 'new', null, 'Draws marks and a text version', ['R2']),
            part('map', 'map.mjs', 'ui', 'new', null, 'Lays out every view once', ['R2']),
            part('impact', 'impactMap', 'ui', 'removed', 'Drew area impact links', null, ['R2']),
        ],
        links: [
            { from: 'ops', to: 'state', label: 'writes', change: 'unchanged', kind: 'uses', anchor: { fileId: 'f1', hunkId: null, side: 'file', startLine: null, endLine: null }, uncertainty: null },
            { from: 'app', to: 'diagram', label: 'draws with', change: 'new', kind: 'uses', anchor: { fileId: 'f2', hunkId: null, side: 'file', startLine: null, endLine: null }, uncertainty: null },
            { from: 'diagram', to: 'map', label: 'places parts with', change: 'new', kind: 'uses', anchor: null, uncertainty: 'Not traced' },
            { from: 'app', to: 'impact', label: 'draws with', change: 'removed', kind: 'uses', anchor: null, uncertainty: 'Not traced' },
        ],
    };
}

const overlaps = (a, b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;

/** A review with areas and impact links but no recorded map; the first link has evidence. */
function areaView() {
    return {
        files: [
            { id: 'f1', status: 'A', hunks: [{ id: 'f1-h1' }] },
            { id: 'f2', status: 'M', hunks: [{ id: 'f2-h1' }] },
            { id: 'f3', status: 'D', hunks: [{ id: 'f3-h1' }] },
            { id: 'f4', status: 'A', hunks: [] },
        ],
        areas: [
            { id: 'core', title: 'Core', fileIds: ['f1', 'f4'], before: '', after: 'A helper records state. Tests cover it.', impact: [] },
            { id: 'canvas', title: 'Canvas', fileIds: ['f2'], before: 'Drew four stages. It also drew lanes.', after: 'Draws three stages.', impact: [
                { from: 'canvas', to: 'Core', anchor: { fileId: 'f2', hunkId: 'f2-h1', startLine: 3, endLine: 3 }, uncertainty: null, description: 'Reads state.' },
                { from: 'canvas', to: 'core', anchor: null, uncertainty: 'Not traced', description: 'Duplicate by ID.' },
                { from: 'canvas', to: 'canvas', anchor: null, uncertainty: 'Self', description: 'Self link.' },
                { from: 'canvas', to: 'Browser', anchor: null, uncertainty: 'Not traced', description: 'Serves pages.' },
            ] },
            { id: 'old', title: 'Old docs', fileIds: ['f3'], before: 'Described Verify.', after: '', impact: [] },
        ],
        reasons: [{ id: 'R1', fileIds: ['f2'], hunkIds: [] }, { id: 'R2', fileIds: ['f1'], hunkIds: ['f3-h1'] }],
    };
}

describe('change map model', () => {
    it('keeps what each view shows: Before leaves out additions, After leaves out removals, Changes shows all', () => {
        const model = { source: 'recorded', ...recorded() };
        const parts = (view) => model.parts.filter((part) => shownIn(view, part)).map((part) => part.id);
        const links = (view) => model.links.filter((link) => shownIn(view, link, 'links')).map((link) => `${link.from}>${link.to}`);
        assert.deepEqual(parts('before'), ['ops', 'state', 'app', 'impact']);
        assert.deepEqual(parts('after'), ['ops', 'state', 'app', 'diagram', 'map']);
        assert.deepEqual(parts('changes'), model.parts.map((part) => part.id));
        assert.deepEqual(links('before'), ['ops>state', 'app>impact']);
        assert.deepEqual(links('after'), ['ops>state', 'app>diagram', 'diagram>map']);
        assert.equal(tagWords(model.parts[0]), 'changed · R1');
        assert.equal(tagWords(model.parts[1]), '');
        assert.equal(tagWords({ change: 'new', reasonIds: [] }), 'new');
        assert.equal(clauseIn('before', model.parts[2]), 'Drew impact per area');
        assert.equal(clauseIn('after', model.parts[2]), 'Draws one change map');
        assert.equal(clauseIn('changes', model.parts[5]), 'Drew area impact links');
        assert.equal(clauseIn('after', model.parts[5]), null);
        assert.equal(clauseIn('before', model.parts[3]), null);
    });

    it('lays out the union once, sizing each box for its tallest view, with no overlapping parts', () => {
        const { graph, laid } = layoutMap({ source: 'recorded', ...recorded() });
        for (const [id, box] of laid.positions) {
            assert.deepEqual(Object.keys(box.variants), MAP_VIEWS);
            const tallest = Math.max(...Object.values(box.variants).map((variant) => variant.lines.length));
            assert.equal(box.height, tallest * 17 + 18, id);
        }
        const diagram = laid.positions.get('diagram').variants;
        assert.equal(diagram.before.lines.length, 2);
        assert.ok(diagram.changes.lines.length > diagram.before.lines.length);
        assert.equal(diagram.changes.tagFrom, diagram.changes.lines.length - 1);
        const boxes = [...laid.positions.values()];
        for (let i = 0; i < boxes.length; i += 1) {
            for (let j = i + 1; j < boxes.length; j += 1) assert.equal(overlaps(boxes[i], boxes[j]), false);
        }
        for (const edge of graph.edges) assert.ok(laid.positions.get(edge.from).x < laid.positions.get(edge.to).x, `${edge.from} > ${edge.to}`);
        assert.deepEqual(graph.edges.map((edge) => edge.label), ['writes', '+ draws with', '+ places parts with (unsure)', '\u2212 draws with (unsure)']);
        assert.deepEqual([...laid.frames.keys()].sort(), ['canvas', 'core', 'ui']);
    });

    it('draws a map from the areas when none is recorded, with context parts for unknown impact ends', () => {
        const view = areaView();
        const model = mapModel(view);
        assert.equal(model.source, 'areas');
        assert.deepEqual(model.parts.map((part) => [part.id, part.change, part.before, part.after, part.reasonIds]), [
            ['area:core', 'new', null, 'A helper records state.', ['R2']],
            ['area:canvas', 'changed', 'Drew four stages.', 'Draws three stages.', ['R1']],
            ['area:old', 'removed', 'Described Verify.', null, ['R2']],
            ['context:1', 'unchanged', null, null, []],
        ]);
        assert.deepEqual(model.links.map((link) => [link.from, link.to, link.description]), [['area:canvas', 'area:core', 'Reads state.'], ['area:canvas', 'context:1', 'Serves pages.']]);
        assert.equal(mapModel({ ...view, areas: [] }), null);
        assert.equal(mapModel({ ...view, changeMap: recorded() }).source, 'recorded');
    });

    it('says each view in words, by box, with change marks and link changes', () => {
        const model = { source: 'recorded', ...recorded() };
        const changes = mapText(model, 'changes');
        assert.deepEqual(changes.boxes.map((box) => box.label), ['code-review-core/', 'ui/']);
        assert.ok(changes.boxes[1].parts.includes('app.mjs (changed · R2): before, Drew impact per area; after, Draws one change map'));
        assert.ok(changes.boxes[1].parts.includes('impactMap (removed · R2): was Drew area impact links'));
        assert.deepEqual(changes.parts, ['review-state.json']);
        assert.ok(changes.links.some((link) => link.words === 'app.mjs draws with diagram.mjs (new)'));
        const before = mapText(model, 'before');
        assert.equal(before.boxes[1].parts.some((text) => text.startsWith('map.mjs')), false);
        assert.deepEqual(before.links.map((link) => link.words), ['operations.mjs writes review-state.json', 'app.mjs draws with impactMap (removed) (unsure: Not traced)']);
        assert.ok(before.links.every((link) => link.anchor || link.words.includes('(unsure: ')), 'every link the text lists keeps its evidence or its doubt');
        const areas = mapText(mapModel(areaView()), 'changes');
        assert.deepEqual(areas.links.map((link) => [link.words, link.description, link.anchor?.fileId ?? null]), [
            ['Canvas affects Core', 'Reads state.', 'f2'],
            ['Canvas affects Browser (unsure: Not traced)', 'Serves pages.', null],
        ]);
    });
});
