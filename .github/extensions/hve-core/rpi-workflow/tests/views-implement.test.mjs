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
    const cards = (node) => all(node).filter((element) => element.classList?.contains('board-card'));
    const laneCards = (node) => cards(node).filter((card) => card.dataset.key.startsWith('board-card-'));
    const lanesOf = (node) => all(node).filter((element) => element.classList?.contains('board-col'));

    it('leads with its title, a progress bar, and Collapse, and collapses to that header', () => {
        const dock = render(implementing())[0];
        assert.match(serialize(dock), /^<section class="board-dock" tabindex="-1" aria-labelledby="board-dock-title">/);
        assert.equal(dock.dataset.row, 'board', 'the board row ID still resolves to the board');
        assert.match(serialize(dock), /<span class="board-progress"><progress class="progress" max="9" value="3" aria-labelledby="board-progress-text"><\/progress><span class="board-dock-summary" id="board-progress-text">3 of 9 tasks done<\/span><\/span>/);
        assert.doesNotMatch(serialize(dock), /scrollable|role="region"|in progress ·|· 3 in progress/, 'the board no longer scrolls or repeats the lane counts');
        assert.equal(keyed(dock, 'board-toggle').getAttribute('aria-expanded'), 'true');
        const ui = initialUi('implement');
        ui.boardCollapsed = true;
        const collapsed = render(implementing(), ui)[0];
        assert.equal(keyed(collapsed, 'board-toggle').getAttribute('aria-expanded'), 'false');
        assert.match(serialize(collapsed), /<div class="board-dock-body" id="board-dock-body" hidden="">/);
        assert.match(textOf(serialize(collapsed)), /3 of 9 tasks done/, 'progress stays in the collapsed header');
    });

    it('shows Backlog, In progress, and Done, each with its count and one card', () => {
        const dock = render(implementing())[0];
        const lanes = lanesOf(dock);
        assert.deepEqual(lanes.map((lane) => lane.dataset.lane), ['backlog', 'active', 'done']);
        assert.deepEqual(lanes.map((lane) => textIn(all(lane).find((element) => element.classList?.contains('board-col-title'))).replace(/\s+/g, ' ').trim()), ['Backlog 3', 'In progress 3 , 1 more paused for you , 1 more blocked', 'Done 3']);
        assert.deepEqual(laneCards(dock).map((card) => card.dataset.preview), ['P03-T02', 'P02-T02', 'P02-T01']);
        assert.equal(withData(render(implementing()), 'row', 'now').length, 0, 'Now is gone');
    });

    it('marks paused and blocked cards and shows the agent\'s latest activity on its card', () => {
        const ui = initialUi('implement');
        ui.boardLane = 'active';
        const dock = render(implementing(), ui)[0];
        const byTask = (id) => cards(dock).find((card) => card.dataset.key === `board-drop-${id}`);
        assert.equal(byTask('P03-T01').getAttribute('class'), 'board-card is-paused');
        assert.match(textOf(serialize(byTask('P03-T01'))), /P03-T01 Paused for you Upload photos in resumable chunks/);
        assert.equal(byTask('P04-T02').getAttribute('class'), 'board-card is-blocked');
        assert.match(textOf(serialize(byTask('P04-T02'))), /P04-T02 Blocked Test the whole flow offline/);
        assert.equal(byTask('P02-T02').getAttribute('class'), 'board-card is-current');
        assert.match(textOf(serialize(byTask('P02-T02'))), /P02-T02 Agent Send conditional writes with ETags Edited src\/offline\/sync-engine\.ts \(\+12 -4\)/);
    });

    it('opens a lane with more than one card as a dropdown of all its cards, hiding the lane\'s own card', () => {
        const ui = initialUi('implement');
        ui.boardLane = 'done';
        const dock = render(implementing(), ui)[0];
        const lane = lanesOf(dock).find((entry) => entry.dataset.lane === 'done');
        assert.match(lane.getAttribute('class'), /\bis-open\b/, 'the open lane hides its own card under the dropdown');
        const toggle = keyed(lane, 'board-lane-done');
        assert.deepEqual([toggle.getAttribute('aria-expanded'), toggle.getAttribute('aria-controls')], ['true', 'board-drop-done']);
        const drop = all(lane).find((element) => element.getAttribute?.('id') === 'board-drop-done');
        assert.equal(drop.getAttribute('hidden'), null);
        assert.deepEqual(cards(drop).map((card) => card.dataset.preview), ['P01-T01', 'P01-T02', 'P02-T01']);
        const closed = all(dock).find((element) => element.getAttribute?.('id') === 'board-drop-backlog');
        assert.equal(closed.getAttribute('hidden'), '', 'a closed lane keeps its dropdown in the page, hidden');
        assert.equal(keyed(dock, 'board-lane-backlog').getAttribute('aria-expanded'), 'false');
    });

    it('heads a lane with one card or none with a plain label', () => {
        const session = implementing();
        for (const task of session.plan.phases.flatMap((phase) => phase.tasks)) {
            if (task.id === 'P03-T01') task.status = 'done';
            if (task.id === 'P04-T02') task.status = 'todo';
        }
        const dock = render(session)[0];
        const lane = lanesOf(dock).find((entry) => entry.dataset.lane === 'active');
        assert.equal(keyed(lane, 'board-lane-active'), null);
        assert.equal(all(lane).some((element) => element.getAttribute?.('id') === 'board-drop-active'), false);
        const empty = lanesOf(render(buildScenario('review', Date.parse(NOW)))[0]).find((entry) => entry.dataset.lane === 'backlog');
        assert.match(textOf(serialize(empty)), /Backlog 0 None/);
    });

    it('gives each card a go-to ID and its task\'s preview, and leaves data-item to the task block', () => {
        const rows = render(implementing());
        for (const card of cards(rows[0])) {
            assert.equal(card.dataset.item, undefined, `${card.dataset.preview} carries no data-item`);
            assert.match(serialize(card), /<use href="#i-go-to"><\/use>/);
        }
        assert.ok(withData(rows, 'item', 'P02-T02').some((element) => element.classList.contains('task')), 'Phases and tasks holds the task block');
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

describe('the steering panel on Implement', () => {
    it('has no Now: progress, work, and activity live on the board', () => {
        const ctx = makeContext(implementing(), 'implement');
        assert.equal(view.nowSection, undefined);
        const panel = html(components.steerPanel(ctx));
        assert.doesNotMatch(panel, /steer-now/);
        assert.ok(panel.indexOf('steer-decided') < panel.indexOf('steer-feedback'), 'Your feedback follows Decided by the agent');
    });
});

describe('the task block on Implement', () => {
    it('keeps the detail panel\'s tools: changes, discoveries, trace, and the do-next and skip requests', async () => {
        const session = implementing();
        const ui = initialUi('implement');
        ui.taskFilter = 'all';
        for (const id of ['P03-T01', 'P02-T01', 'P02-T03']) ui.expanded.add(id);
        const rows = render(session, ui);
        const block = (id) => textOf(serialize(all(rows).find((element) => element.classList?.contains('task') && element.dataset.item === id)));
        assert.match(block('P03-T01'), /Discoveries DS-002 DS-004/);
        assert.match(block('P03-T01'), /Ask the agent to skip it/);
        assert.doesNotMatch(block('P03-T01'), /Ask the agent to do this next/, 'P03-T01 has started');
        if ((makeContext(session, 'implement').data.view.traces['P03-T01'] ?? []).length > 1) assert.match(block('P03-T01'), /Trace/);
        assert.match(block('P02-T01'), /Changes CH-003/);
        assert.doesNotMatch(block('P02-T01'), /Ask the agent/, 'a done task offers neither request');
        assert.match(block('P02-T03'), /Ask the agent to do this next.*Ask the agent to skip it/);
        const plan = await import('../ui/view-plan.mjs');
        const planUi = initialUi('plan');
        planUi.expanded.add('P03-T01');
        const planBlock = all(plan.renderView(makeContext(session, 'plan', planUi))).find((element) => element.classList?.contains('task') && element.dataset.item === 'P03-T01');
        assert.doesNotMatch(textOf(serialize(planBlock)), /Ask the agent|Discoveries|Changes CH-|Trace/, 'Plan\'s block is unchanged');
    });
});
