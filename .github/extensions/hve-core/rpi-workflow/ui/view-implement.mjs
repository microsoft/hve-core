// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, DISCOVERY_KIND, h, icon, idChip, idTag, known, plural, sr, TASK_STATUS, timeEl, VALIDATION } from './dom.mjs';
import { decisionCard, marginNote, md, mdInline, recordRow, row, rowActions, sectionBody, table } from './components.mjs';
import { renderDiagram } from './diagram.mjs';
import { boardLanes, laneOf, taskMarkers } from './board.mjs';
import { anchoredDecisions, notesFor } from './view-research.mjs';
import { taskBlock } from './view-plan.mjs';
import { plainInline } from './markdown.mjs';

/**
 * Implement view: the task board pinned under the context bar with progress and one card per
 * lane, phases and tasks with a filter, the change map with progress, changes, discoveries
 * and plan updates, alignment, and validation.
 */

const ACTIVITY_ICON = { read: 'eye', edit: 'pencil', run: 'code', test: 'check-circle', think: 'bulb', note: 'info' };
const ALIGNMENT = {
    'pending-decision': { icon: 'hand', label: 'Pending decision', tone: 'attention' },
    'divergence-confirmed': { icon: 'signpost', label: 'Divergence confirmed', tone: 'severe' },
    clarification: { icon: 'info', label: 'Clarification', tone: 'muted' },
    'source-gap': { icon: 'alert', label: 'Source gap', tone: 'danger' },
};

const allTasks = (ctx) => ctx.data.session.plan.phases.flatMap((phase) => phase.tasks.map((task) => ({ ...task, phaseId: phase.id })));
const TASK_ID_RE = /^P\d{2}(?:-T\d{2})?$/;

/** Owner and clearing condition of a blocker, when recorded. */
function blockerNote(blocker) {
    const text = [blocker.owner ? `Owner: ${blocker.owner}.` : null, blocker.clear || null].filter(Boolean).join(' ');
    return text ? [' ', h('span', { class: 'meta', text })] : null;
}

export function outline(ctx) {
    const { session } = ctx.data;
    const impl = session.implementation;
    const tasks = allTasks(ctx);
    return [
        { id: 'board', label: 'Task board' },
        tasks.length ? { id: 'implement-phases', label: 'Phases and tasks', count: `${tasks.filter((task) => task.status === 'done').length}/${tasks.length}` } : null,
        session.plan.diagram ? { id: 'implement-map', label: 'Change map' } : null,
        { id: 'changes', label: 'Changes', count: impl.changes.length },
        { id: 'discoveries', label: 'Discoveries and plan updates', count: impl.discoveries.length },
        { id: 'alignment', label: 'Business alignment', count: impl.alignment.length },
        { id: 'validation', label: 'Validation and blockers', count: impl.validation.length },
        session.records?.implement?.length ? { id: 'implement-record', label: 'Changes record', count: session.records.implement.length } : null,
    ].filter(Boolean);
}

/** The Phases and tasks filters, matching the board's lanes: In progress also holds work paused for you or blocked. */
export const TASK_FILTERS = Object.freeze([
    { id: 'active', label: 'In progress', match: (task) => laneOf(task) === 'active' },
    { id: 'backlog', label: 'Backlog', match: (task) => laneOf(task) === 'backlog' },
    { id: 'done', label: 'Done', match: (task) => laneOf(task) === 'done' },
    { id: 'all', label: 'All', match: () => true },
]);

const filterOf = (id) => TASK_FILTERS.find((filter) => filter.id === id) ?? TASK_FILTERS[0];

/** True when the filter shows a phase or task: a phase shows while any of its tasks match. */
export function filterShows(session, filterId, id) {
    const filter = filterOf(filterId);
    for (const phase of session.plan.phases ?? []) {
        if (phase.id === id) return phase.tasks.some(filter.match);
        const task = phase.tasks.find((candidate) => candidate.id === id);
        if (task) return filter.match(task);
    }
    return true;
}

/**
 * Each change-map node's progress: in progress while any phase that changes it is, done once
 * every such phase is. Nodes no phase changes have none.
 *
 * @param {any} plan
 * @returns {Map<string, 'done' | 'active'>}
 */
export function nodeProgress(plan) {
    const statuses = new Map();
    for (const phase of plan.phases ?? []) {
        for (const node of plan.diagram?.phaseNodes?.[phase.id] ?? []) {
            if (!statuses.has(node)) statuses.set(node, []);
            statuses.get(node).push(phase.status);
        }
    }
    const progress = new Map();
    for (const [node, list] of statuses) {
        if (list.some((status) => status === 'in-progress')) progress.set(node, 'active');
        else if (list.every((status) => status === 'done')) progress.set(node, 'done');
    }
    return progress;
}

const PHASE_PROGRESS = {
    done: { icon: 'check-circle', label: 'done', tone: 'success' },
    'in-progress': { icon: 'active', label: 'in progress', tone: 'accent' },
    todo: { icon: 'circle', label: 'backlog', tone: 'muted' },
};

/** A card's marker badge: icon and words, with the words hidden visually on narrow boards. */
function marker(meta, className) {
    return h('span', { class: ['badge', `tone-${meta.tone}`, 'board-flag', className] }, icon(meta.icon), h('span', { class: 'board-flag-text', text: meta.label }));
}

/**
 * One task as a card: its ID, its markers, and its title, and on the agent's task the latest
 * activity. A click goes to the task in Phases and tasks; hovering or focusing it shows the
 * task's preview.
 *
 * @param {any} ctx
 * @param {any} task
 * @param {string} key the card's `data-key`, distinct for the lane's card and its dropdown copy
 */
function boardCard(ctx, task, key) {
    const impl = ctx.data.session.implementation;
    const markers = taskMarkers(ctx.data.session, task);
    const agent = impl.current?.taskId === task.id;
    const activity = agent ? impl.activity.at(-1) ?? null : null;
    return h('button', {
        type: 'button',
        class: ['board-card', agent ? 'is-current' : null, markers.paused ? 'is-paused' : null, markers.blocked ? 'is-blocked' : null],
        dataset: { key, preview: task.id },
        onclick: () => ctx.act.navigate(task.id, 'implement'),
    },
    h('span', { class: 'board-card-head' },
        idTag(task.id, 'go-to'),
        agent ? marker({ icon: 'sparkle', label: 'Agent', tone: 'agent' }, 'is-agent') : null,
        markers.paused ? marker(TASK_STATUS.paused, 'is-paused') : null,
        markers.blocked ? marker(TASK_STATUS.blocked, 'is-blocked') : null),
    h('span', { class: 'board-card-title', text: task.title }),
    activity ? h('span', { class: 'board-card-activity' }, icon(ACTIVITY_ICON[activity.kind] ?? 'info'), h('span', { class: 'activity-text', text: activity.text }), timeEl(activity.at, ctx.now)) : null);
}

/**
 * One lane: its header with the lane's count and markers for paused or blocked cards it
 * hides, then its one card. A lane with more than one card heads with a disclosure button
 * whose dropdown lists all of them over the page.
 */
function boardLane(ctx, lane) {
    const meta = TASK_STATUS[lane.status];
    const open = ctx.ui.boardLane === lane.id && lane.tasks.length > 1;
    const titleId = `board-lane-${lane.id}`;
    const dropId = `board-drop-${lane.id}`;
    const hiddenFlags = [
        lane.hidden.paused ? h('span', { class: 'lane-flag tone-attention-fg' }, icon('pause'), sr(`, ${lane.hidden.paused} more paused for you`)) : null,
        lane.hidden.blocked ? h('span', { class: 'lane-flag tone-danger-fg' }, icon('alert'), sr(`, ${lane.hidden.blocked} more blocked`)) : null,
    ];
    const label = [icon(meta.icon, { className: `tone-${meta.tone}-fg` }), h('span', { class: 'lane-label', text: lane.label }), h('span', { class: 'count', text: String(lane.tasks.length) }), ...hiddenFlags];
    const head = lane.tasks.length > 1
        ? h('button', { type: 'button', class: 'board-lane-toggle', 'aria-expanded': String(open), 'aria-controls': dropId, dataset: { key: `board-lane-${lane.id}` }, onclick: () => ctx.act.toggleLane(lane.id) },
            ...label, icon('chevron', { className: 'chev' }))
        : h('span', { class: 'board-lane-label' }, ...label);
    return h('section', { class: ['board-col', `lane-${lane.id}`, open ? 'is-open' : null, lane.tasks.length ? null : 'is-empty'], 'aria-labelledby': titleId, dataset: { lane: lane.id } },
        h('div', { class: 'board-lane-head' },
            h('h4', { class: 'board-col-title', id: titleId }, head),
            lane.tasks.length > 1
                ? h('div', { class: 'board-drop', id: dropId, hidden: !open },
                    h('ul', { class: 'board-list', 'aria-label': `${lane.label}: ${plural(lane.tasks.length, 'task')}` }, lane.tasks.map((task) => h('li', null, boardCard(ctx, task, `board-drop-${task.id}`)))))
                : null),
        lane.card ? h('div', { class: 'board-lane-card' }, boardCard(ctx, lane.card, `board-card-${lane.card.id}`)) : h('p', { class: 'empty small', text: 'None' }));
}

/**
 * The task board, pinned under the context bar: its title with progress and Collapse, then
 * Backlog, In progress, and Done with one card each. Progress counts the shown plan's tasks,
 * which are an earlier changes record's own when one shows.
 */
function boardDock(ctx) {
    const collapsed = ctx.ui.boardCollapsed === true;
    const tasks = allTasks(ctx);
    const done = tasks.filter((task) => task.status === 'done').length;
    const total = tasks.length;
    return h('section', { class: ['board-dock', collapsed ? 'is-collapsed' : null], dataset: { row: 'board' }, tabindex: '-1', 'aria-labelledby': 'board-dock-title' },
        h('header', { class: 'board-dock-head' },
            h('h3', { class: 'board-dock-title', id: 'board-dock-title' }, icon('list'), 'Task board'),
            h('span', { class: 'board-progress' },
                h('progress', { class: 'progress', max: String(Math.max(total, 1)), value: String(done), 'aria-labelledby': 'board-progress-text' }),
                h('span', { class: 'board-dock-summary', id: 'board-progress-text', text: `${done} of ${plural(total, 'task')} done` })),
            button(collapsed ? 'Expand the task board' : 'Collapse the task board', { iconName: 'chevron', hideLabel: true, attrs: { class: ['btn', 'btn-neutral', 'btn-icon', 'board-dock-toggle'].join(' '), 'aria-expanded': String(!collapsed), 'aria-controls': 'board-dock-body', 'data-key': 'board-toggle' }, onClick: () => ctx.act.toggleBoard() })),
        h('div', { class: 'board-dock-body', id: 'board-dock-body', hidden: collapsed },
            h('div', { class: 'board' }, boardLanes(ctx.data.session).map((lane) => boardLane(ctx, lane)))));
}

/** What an empty filter means, with Show all. */
function emptyFilter(ctx, filter, tasks) {
    const done = tasks.filter((task) => task.status === 'done').length;
    const text = {
        active: done === tasks.length ? `Nothing is in progress: all ${plural(tasks.length, 'task')} are done.` : done === 0 ? `Nothing is in progress yet; ${plural(tasks.length, 'task')} remain.` : `Nothing is in progress right now; ${done} of ${plural(tasks.length, 'task')} are done.`,
        backlog: 'Nothing is in the backlog: every task is done or in progress.',
        done: 'No task is done yet.',
        all: 'The plan has no tasks.',
    }[filter.id];
    return h('div', { class: 'empty-filter' }, h('p', { class: 'empty', text }), filter.id === 'all' ? null : button('Show all', { attrs: { 'data-key': 'task-filter-show-all' }, onClick: () => ctx.act.setTaskFilter('all') }));
}

/** The plan's phases and tasks, filtered, with Plan's task blocks. */
function phasesRow(ctx, tasks) {
    const { session } = ctx.data;
    const filter = filterOf(ctx.ui.taskFilter);
    const done = tasks.filter((task) => task.status === 'done').length;
    const phases = session.plan.phases.map((phase) => ({ phase, shown: phase.tasks.filter(filter.match) })).filter((entry) => entry.shown.length);
    return row(ctx, {
        id: 'implement-phases', idLabel: null, title: 'Phases and tasks', level: 2,
        badges: [chip(`${done} of ${tasks.length} tasks done`, done === tasks.length ? 'success' : 'muted')],
        actions: rowActions(ctx, { rowId: 'implement-phases' }),
        body: [
            h('fieldset', { class: 'segmented compact task-filter' }, h('legend', { class: 'visually-hidden', text: 'Show tasks' }),
                TASK_FILTERS.map((option) => h('label', { for: `task-filter-${option.id}` },
                    h('input', { type: 'radio', name: 'task-filter', id: `task-filter-${option.id}`, value: option.id, checked: filter.id === option.id, onchange: () => ctx.act.setTaskFilter(option.id) }),
                    h('span', null, option.label, ' ', h('span', { class: 'count', text: String(tasks.filter(option.match).length) }))))),
            phases.length
                ? phases.map(({ phase, shown }) => {
                    const meta = PHASE_PROGRESS[phase.status] ?? PHASE_PROGRESS.todo;
                    const phaseDone = phase.tasks.filter((task) => task.status === 'done').length;
                    return h('section', { class: 'impl-phase', dataset: { item: phase.id }, tabindex: '-1', 'aria-labelledby': `impl-phase-${phase.id}` },
                        h('h4', { class: 'impl-phase-head', id: `impl-phase-${phase.id}` },
                            h('span', { class: 'id-chip', text: phase.id }), h('span', { class: 'impl-phase-title', text: phase.title }),
                            chip(`${phaseDone} of ${phase.tasks.length} done`, phaseDone === phase.tasks.length ? 'success' : 'muted'),
                            badge({ icon: meta.icon, label: meta.label[0].toUpperCase() + meta.label.slice(1), tone: meta.tone })),
                        h('ol', { class: 'task-list' }, shown.map((task) => taskBlock(ctx, task, phase.tasks.indexOf(task), phase.tasks, { implement: true }))));
                })
                : emptyFilter(ctx, filter, tasks),
        ],
    });
}

/** The plan's change map with done and in-progress parts marked, and a tab per phase. */
function mapRow(ctx) {
    const { plan } = ctx.data.session;
    const progress = nodeProgress(plan);
    const working = plan.phases.find((phase) => phase.status === 'in-progress')?.id ?? null;
    // No choice, or a phase chosen in another plan, shows the phase in progress, else All phases.
    const known = ctx.ui.mapPhase === null || plan.phases.some((phase) => phase.id === ctx.ui.mapPhase);
    const chosen = ctx.ui.mapPhase === undefined || !known ? working : ctx.ui.mapPhase;
    const highlight = chosen ? plan.diagram.phaseNodes?.[chosen] ?? [] : [];
    const tab = (value, phase) => {
        const meta = phase ? PHASE_PROGRESS[phase.status] ?? PHASE_PROGRESS.todo : null;
        return h('label', { for: `impl-map-phase-${value}` },
            h('input', { type: 'radio', name: 'impl-map-phase', id: `impl-map-phase-${value}`, value, checked: (chosen ?? 'all') === value, onchange: () => ctx.act.setMapPhase(value === 'all' ? null : value) }),
            h('span', null, meta ? icon(meta.icon, { className: `tone-${meta.tone}-fg` }) : null, value === 'all' ? 'All phases' : value, meta ? sr(`, ${meta.label}`) : null));
    };
    return row(ctx, {
        id: 'implement-map', idLabel: null, title: 'Change map', level: 2,
        actions: rowActions(ctx, { rowId: 'implement-map' }),
        body: [
            h('div', { class: 'map-controls' },
                h('fieldset', { class: 'segmented compact map-phases' }, h('legend', { class: 'meta', text: 'Phase' }), tab('all', null), plan.phases.map((phase) => tab(phase.id, phase)))),
            renderDiagram(plan.diagram.after, {
                caption: `The intended result, with done and in-progress parts marked${highlight.length ? `, ${chosen} outlined` : ''}`,
                highlight,
                progress,
                idPrefix: 'impl-map',
                textOpen: ctx.ui.openDetails.has('impl-map-text'),
                onTextToggle: (open) => ctx.act.setDetailsOpen('impl-map-text', open),
            }),
            h('p', { class: 'meta legend' },
                h('span', { class: 'legend-swatch is-done' }), ' Done. ',
                h('span', { class: 'legend-swatch is-active' }), ' In progress. ',
                h('span', { class: 'legend-swatch is-chosen' }), ' Bold outline: the chosen phase. ',
                h('span', { class: 'legend-swatch is-new' }), ' Dashed border: added by the plan.'),
        ],
    });
}

export function renderView(ctx) {
    const { session } = ctx.data;
    const impl = session.implementation;
    const tasks = allTasks(ctx);
    const rows = [boardDock(ctx)];
    if (tasks.length) rows.push(phasesRow(ctx, tasks));
    if (session.plan.diagram) rows.push(mapRow(ctx));

    const fileItem = (change, file) => {
        const counted = Number.isFinite(file.additions) && Number.isFinite(file.deletions);
        return h('li', null, h('button', { type: 'button', class: 'file-btn', onclick: () => ctx.act.openFile(change.id, file.path) },
            icon(file.diff ? 'diff' : 'file'), h('code', { text: file.path }), file.kind ? h('span', { class: ['badge', `tone-${file.kind === 'added' ? 'success' : file.kind === 'deleted' ? 'danger' : 'accent'}`], text: file.kind }) : null,
            counted ? h('span', { class: 'meta diffstat' }, h('span', { class: 'add', text: `+${file.additions}` }), ' ', h('span', { class: 'del', text: `−${file.deletions}` }), sr(` ${file.additions} lines added, ${file.deletions} removed`)) : null));
    };
    const changeItem = (change) => {
        const checks = change.validation ?? [];
        return h('li', { class: 'change', dataset: { item: change.id }, tabindex: '-1' },
            h('p', { class: 'change-head' }, h('span', { class: 'id-chip', text: change.id }), h('strong', { text: change.title }), timeEl(change.at, ctx.now)),
            change.behavior ? h('div', { class: 'change-behavior prose' }, md(ctx, change.behavior)) : null,
            change.files.length ? h('ul', { class: 'file-list', 'aria-label': `Files in ${change.id}` }, change.files.map((file) => fileItem(change, file))) : null,
            checks.length ? h('p', { class: 'chip-row' }, checks.map((check) => {
                const status = known(VALIDATION, check.status) ?? { icon: 'info', label: 'Not run', tone: 'muted' };
                return h('span', { class: ['badge', `tone-${status.tone}`], title: plainInline(check.summary) || undefined }, icon(status.icon), h('code', { text: check.check }), ` ${status.label}`);
            })) : null,
            change.validationText ? h('div', { class: 'change-validation' }, h('p', { class: 'meta' }, icon('check-circle'), 'Validation'), h('div', { class: 'prose' }, md(ctx, change.validationText))) : null);
    };
    const byTask = new Map();
    for (const change of impl.changes) {
        if (!byTask.has(change.taskId)) byTask.set(change.taskId, []);
        byTask.get(change.taskId).push(change);
    }
    const taskOrder = tasks.map((task) => task.id).filter((id) => byTask.has(id)).concat([...byTask.keys()].filter((id) => !tasks.some((task) => task.id === id)));
    rows.push(row(ctx, {
        id: 'changes', idLabel: null, title: 'Changes', level: 2,
        actions: rowActions(ctx, { sectionId: 'changes-summary', rowId: 'changes' }),
        body: [sectionBody(ctx, 'changes-summary'), impl.changes.length
            ? taskOrder.map((taskId) => h('section', { class: 'group', 'aria-labelledby': `changes-${taskId ?? 'unlinked'}` },
                h('h4', { class: 'group-head', id: `changes-${taskId ?? 'unlinked'}` }, taskId ? idChip(taskId, ctx.act.navigate) : null, h('span', { text: taskId ? ctx.find(taskId)?.title ?? 'Task not in the plan' : 'Not linked to a plan task' }), h('span', { class: 'count', text: String(byTask.get(taskId).length) })),
                h('ol', { class: 'change-list' }, byTask.get(taskId).slice().reverse().map(changeItem))))
            : h('p', { class: 'empty', text: 'Completed work appears here under its task, with its files and validation, as the agent finishes each task.' })],
        margin: notesFor(ctx, ['changes', ...impl.changes.map((change) => change.id)]).map((item) => marginNote(ctx, item)),
    }));

    const discoveryItem = (item) => h('li', { class: 'discovery', dataset: { item: item.id }, tabindex: '-1' },
            h('p', { class: 'discovery-head' }, badge(DISCOVERY_KIND[item.kind]), h('span', { class: 'id-chip', text: item.id }), h('strong', { text: item.title })),
            h('p', { text: item.detail }),
            item.taskId || item.decisionId || timeEl(item.at, ctx.now) ? h('p', { class: 'chip-row' }, item.taskId ? idChip(item.taskId, ctx.act.navigate) : null, item.decisionId ? idChip(item.decisionId, ctx.act.navigate) : null, timeEl(item.at, ctx.now)) : null,
            item.planUpdate ? h('div', { class: 'plan-update' },
                h('p', { class: 'meta' }, icon('signpost'), `Plan updated: ${item.planUpdate.area}`),
                item.planUpdate.before ? h('p', { class: 'diff-line is-del' }, sr('Before: '), h('span', { class: 'diff-marker', 'aria-hidden': 'true', text: '−' }), h('span', { text: item.planUpdate.before })) : null,
                h('p', { class: 'diff-line is-add' }, sr('After: '), h('span', { class: 'diff-marker', 'aria-hidden': 'true', text: '+' }), h('span', { text: item.planUpdate.after }))) : null);
    const kinds = ['plan-change', 'follow-up', 'annotation', 'local'].filter((kind) => impl.discoveries.some((item) => item.kind === kind));
    rows.push(row(ctx, {
        id: 'discoveries', idLabel: null, title: 'Discoveries and plan updates', level: 2,
        body: [impl.discoveries.length
            ? kinds.map((kind) => h('section', { class: 'group', 'aria-labelledby': `discoveries-${kind}` },
                h('h4', { class: 'group-head', id: `discoveries-${kind}` }, icon(DISCOVERY_KIND[kind].icon, { className: `tone-${DISCOVERY_KIND[kind].tone}-fg` }), h('span', { text: DISCOVERY_KIND[kind].label }), h('span', { class: 'count', text: String(impl.discoveries.filter((item) => item.kind === kind).length) })),
                h('ol', { class: 'discovery-list' }, impl.discoveries.filter((item) => item.kind === kind).reverse().map(discoveryItem))))
            : h('p', { class: 'empty', text: 'Things the agent learns while implementing appear here, grouped as plan changes, follow-ups, implementation notes, and local judgment.' })],
        margin: anchoredDecisions(ctx, impl.discoveries.map((item) => item.id)).map((decision) => decisionCard(ctx, decision)),
    }));

    rows.push(row(ctx, {
        id: 'alignment', idLabel: null, title: 'Business alignment', level: 2,
        body: [impl.alignment.length ? impl.alignment.map((entry) => h('div', { class: 'alignment', dataset: { item: entry.id }, tabindex: '-1' },
            h('p', { class: 'discovery-head' }, badge(ALIGNMENT[entry.alignment] ?? ALIGNMENT.clarification), h('span', { class: 'id-chip', text: entry.id }), h('strong', { text: entry.requirement })),
            h('dl', { class: 'facts' },
                h('dt', { text: 'Source' }), h('dd', null, h('code', { text: entry.source }), ` (${entry.document}, ${entry.status})`),
                h('dt', { text: 'Owner' }), h('dd', { text: entry.owner }),
                h('dt', { text: 'What changed' }), h('dd', { text: entry.change }),
                h('dt', { text: 'Why' }), h('dd', { text: entry.why }),
                h('dt', { text: 'Decision' }), h('dd', null, idChip(entry.decision, ctx.act.navigate), ' ', idChip(entry.marker, ctx.act.navigate)))))
            : h('p', { class: 'empty', text: 'When work changes a requirement from a product or architecture document, the agent records it here.' })],
    }));

    rows.push(row(ctx, {
        id: 'validation', idLabel: null, title: 'Validation and blockers', level: 2,
        body: [table('Validation record', ['Check', 'Scope', 'Status', 'Result'], impl.validation.map((check) => [h('code', { text: check.check }), typeof check.scope === 'string' && TASK_ID_RE.test(check.scope) ? idChip(check.scope, ctx.act.navigate) : check.scope ?? '', badge(known(VALIDATION, check.status)), mdInline(ctx, check.summary, { doc: 'implement' })])),
            impl.blockers.length ? h('ul', { class: 'blockers' }, impl.blockers.map((blocker) => h('li', null, badge({ icon: 'alert', label: 'Blocked', tone: 'danger' }), ' ', blocker.taskId ? [idChip(blocker.taskId, ctx.act.navigate), ' '] : null, blocker.text, blockerNote(blocker)))) : h('p', { class: 'meta', text: 'No blockers.' })],
    }));

    const record = recordRow(ctx, 'implement', 'Changes record');
    if (record) rows.push(record);
    return rows;
}
