// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { buildScenario } from '../lib/scenario.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';

const NOW = '2026-10-27T12:00:00.000Z';
const html = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).map(serialize).join('');
const textOf = (markup) => markup.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ');
const all = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).flatMap((node) => [node, ...elements(node)]);
const keyed = (nodes, key) => all(nodes).find((element) => (element.dataset?.key ?? element.getAttribute?.('data-key')) === key) ?? null;
const withData = (nodes, name, value) => all(nodes).filter((element) => element.dataset?.[name] === value);
const textIn = (node) => all(node).filter((element) => element.childNodes).map((element) => element.childNodes.filter((child) => typeof child.data === 'string').map((child) => child.data).join('')).join(' ');

let restore;
let view;
let components;
let makeContext;
let initialUi;
before(async () => {
    restore = installFakeDom();
    view = await import('../ui/view-implement.mjs');
    components = await import('../ui/components.mjs');
    ({ makeContext, initialUi } = await import('./helpers/render-views.mjs'));
});
after(() => restore());

/** The sample at Implement: P02-T02 in progress, P03-T01 paused, P04-T02 blocked, and the rest done or in the backlog. */
const implementing = () => buildScenario('implement', Date.parse(NOW));
const render = (session, ui = initialUi('implement')) => view.renderView(makeContext(session, 'implement', { ...ui, taskFilter: ui.taskFilter ?? 'active' }));

describe('the pinned task board', () => {
    it('leads the page with a summary and a Collapse control, and collapses to its heading', () => {
        const rows = render(implementing());
        const dock = rows[0];
        assert.match(serialize(dock), /^<section class="board-dock" tabindex="-1" aria-labelledby="board-dock-title">/);
        assert.equal(dock.dataset.row, 'board', 'the board row ID still resolves to the board');
        assert.match(textOf(serialize(dock)), /Task board 3 of 9 tasks done · 3 in progress/);
        assert.equal(keyed(dock, 'board-toggle').getAttribute('aria-expanded'), 'true');
        assert.match(serialize(dock), /<div class="board-dock-body" id="board-dock-body" role="region" tabindex="0" aria-label="Task board, scrollable">/);
        const ui = initialUi('implement');
        ui.boardCollapsed = true;
        const collapsed = render(implementing(), ui)[0];
        assert.equal(keyed(collapsed, 'board-toggle').getAttribute('aria-expanded'), 'false');
        assert.match(serialize(collapsed), /<div class="board-dock-body" id="board-dock-body" hidden="" /);
        assert.equal(withData(render(implementing()), 'row', 'now').length, 0, 'Now moved to the steering panel');
    });
});

describe('phases and tasks', () => {
    it('starts on In progress, which holds work paused for you or blocked, and counts each filter', () => {
        const out = html(render(implementing()));
        assert.match(textOf(out), /In progress 3 Backlog 3 Done 3 All 9/);
        assert.match(out, /<input type="radio" name="task-filter" id="task-filter-active" value="active" checked=""/);
        const rows = render(implementing());
        const phases = all(rows).filter((element) => element.classList?.contains('impl-phase'));
        assert.deepEqual(phases.map((element) => element.dataset.item), ['P02', 'P03', 'P04']);
        const listed = phases.flatMap((phase) => all(phase).filter((element) => element.classList.contains('task')).map((element) => element.dataset.item));
        assert.deepEqual(listed, ['P02-T02', 'P03-T01', 'P04-T02'], 'only work in progress, paused, or blocked');
    });

    it('filters to what remains, what is done, or everything', () => {
        const count = (filter) => {
            const ui = initialUi('implement');
            ui.taskFilter = filter;
            const out = html(render(implementing(), ui));
            return (out.slice(out.indexOf('impl-phase')).match(/class="task is-[a-z-]+"/g) ?? []).length;
        };
        assert.deepEqual(['backlog', 'done', 'all'].map(count), [3, 3, 9]);
        assert.equal(view.filterShows(implementing(), 'done', 'P04'), false);
        assert.equal(view.filterShows(implementing(), 'active', 'P04'), true);
        assert.equal(view.filterShows(implementing(), 'done', 'P01-T01'), true);
    });

    it('moves tasks in plan order whatever the filter shows', () => {
        const rows = render(implementing());
        const block = all(rows).find((element) => element.classList?.contains('task') && element.dataset.item === 'P02-T02');
        const up = all(block).find((element) => element.localName === 'button' && /Move up/.test(textIn(element)));
        assert.ok(up, 'P02-T02 has Move up');
        assert.equal(up.getAttribute('disabled'), null, 'P02-T01 sits above it in the plan, though the filter hides it');
    });

    it('says what an empty filter means and offers Show all', () => {
        const session = buildScenario('review', Date.parse(NOW));
        const out = html(render(session));
        assert.match(textOf(out), /Nothing is in progress: all 9 tasks are done\./);
        assert.ok(keyed(render(session), 'task-filter-show-all'));
    });
});

describe('the change map with progress', () => {
    it('marks each phase\'s parts done or in progress, starts on the phase in progress, and says so in text', () => {
        const session = implementing();
        const progress = view.nodeProgress(session.plan);
        assert.equal(progress.get('store'), 'done');
        assert.equal(progress.get('outbox'), 'active');
        const out = html(render(session));
        assert.equal(withData(render(session), 'row', 'implement-map').length, 1);
        assert.match(out, /<input type="radio" name="impl-map-phase" id="impl-map-phase-P02" value="P02" checked=""/);
        assert.match(out, /<span class="visually-hidden">, done<\/span>/);
        assert.match(out, /class="diagram-node[^"]*is-done"/);
        assert.match(out, /class="diagram-node[^"]*is-highlight is-active"/);
        assert.match(out, /<g class="diagram-mark is-done">/);
        assert.match(out, /<label for="impl-map-phase-P02"><input[^>]*><\/input><span><svg class="icon tone-accent-fg"/, 'the in-progress tab\'s icon is in the in-progress tone');
        assert.match(out, /<label for="impl-map-phase-P01"><input[^>]*><\/input><span><svg class="icon tone-success-fg"/, 'a done tab\'s icon stays in the success tone');
        assert.match(out, /<h4 class="impl-phase-head" id="impl-phase-P02">(?:(?!<\/h4>).)*<span class="badge tone-accent[^"]*">(?:(?!<\/h4>).)*In progress/, 'the phase in progress is headed in the in-progress tone');
        assert.match(textOf(out), /\(done\)/);
        assert.match(textOf(out), /\(in progress\) \(highlighted\)/);
        assert.match(textOf(out), /Done\. In progress\. Bold outline: the chosen phase\. Dashed border: added by the plan\./, 'the legend names what the map draws');
        assert.match(out, /<span class="legend-swatch is-chosen">/);
        const ui = initialUi('implement');
        ui.mapPhase = null;
        assert.match(html(render(session, ui)), /id="impl-map-phase-all" value="all" checked=""/, 'All phases highlights nothing');
    });
});

describe('Now in the steering panel', () => {
    it('shows progress, the work in hand, what is paused for you, and the latest activity after Decided by the agent', () => {
        const session = implementing();
        const ctx = makeContext(session, 'implement');
        const now = view.nowSection(ctx);
        const text = textOf(serialize(now));
        assert.match(text, /3 of 9 tasks done/);
        assert.match(text, /The agent is working on P02-T02/);
        assert.match(text, /Paused for you P03-T01/);
        assert.match(text, /Paused for you: D6/);
        assert.match(serialize(now), /<ol class="activity" aria-label="Latest agent activity, newest first">/);
        const sections = components.steerPanel(ctx, { now });
        const panel = html(sections);
        assert.match(panel, /<section class="steer-section steer-now" aria-labelledby="steer-now" tabindex="-1">/);
        assert.equal(withData(sections, 'row', 'now').length, 1, 'the now anchor resolves to the section');
        assert.ok(panel.indexOf('steer-decided') < panel.indexOf('steer-now') && panel.indexOf('steer-now') < panel.indexOf('steer-feedback'), 'Now follows Decided by the agent');
        assert.doesNotMatch(html(components.steerPanel(ctx)), /steer-now/, 'other phases have no Now');
    });
});
