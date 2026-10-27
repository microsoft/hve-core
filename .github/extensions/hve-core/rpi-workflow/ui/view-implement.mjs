// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, DISCOVERY_KIND, h, icon, idChip, idTag, known, plural, sr, TASK_STATUS, timeEl, VALIDATION } from './dom.mjs';
import { decisionCard, marginNote, md, mdInline, recordRow, row, rowActions, sectionBody, table, traceStrip } from './components.mjs';
import { renderDiagram } from './diagram.mjs';
import { anchoredDecisions, notesFor } from './view-research.mjs';
import { taskBlock } from './view-plan.mjs';
import { plainInline } from './markdown.mjs';

/**
 * Implement view: the task board pinned under the context bar, phases and tasks with a
 * filter, the change map with progress, changes, discoveries and plan updates, alignment,
 * and validation. Now lives in the steering panel.
 */

const COLUMNS = [
    { status: 'todo', label: 'Up next' },
    { status: 'in-progress', label: 'In progress' },
    { status: 'paused', label: 'Paused for you' },
    { status: 'done', label: 'Done' },
    { status: 'blocked', label: 'Blocked' },
];
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

/** The Phases and tasks filters; In progress also holds work paused for you or blocked. */
export const TASK_FILTERS = Object.freeze([
    { id: 'active', label: 'In progress', match: (task) => task.status === 'in-progress' || task.status === 'paused' || task.status === 'blocked' },
    { id: 'remaining', label: 'Remaining', match: (task) => task.status === 'todo' },
    { id: 'done', label: 'Done', match: (task) => task.status === 'done' },
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
    todo: { icon: 'circle', label: 'up next', tone: 'muted' },
};

function validationSummary(changes) {
    const checks = changes.flatMap((change) => change.validation);
    if (!checks.length) return null;
    const failed = checks.filter((check) => check.status === 'failed').length;
    return failed ? badge({ icon: 'x-circle', label: `${failed} failed`, tone: 'danger' }) : badge({ icon: 'check', label: `${checks.length} passed`, tone: 'success' });
}

function boardCard(ctx, task) {
    const changes = ctx.data.session.implementation.changes.filter((change) => change.taskId === task.id);
    const files = new Set(changes.flatMap((change) => change.files.map((file) => file.path)));
    const selected = ctx.ui.selectedTask === task.id;
    const decision = task.decisionId ? ctx.data.session.decisions.find((d) => d.id === task.decisionId) : null;
    const current = ctx.data.session.implementation.current?.taskId === task.id;
    return h('li', null, h('button', {
        type: 'button', class: ['board-card', selected ? 'is-selected' : null, current ? 'is-current' : null], 'aria-pressed': String(selected), dataset: { item: task.id },
        onclick: () => ctx.act.selectTask(task.id),
    },
    h('span', { class: 'board-card-head' }, idTag(task.id, 'file'), current ? h('span', { class: 'badge tone-agent' }, icon('sparkle'), 'Agent') : null),
    h('span', { class: 'board-card-title', text: task.title }),
    h('span', { class: 'board-card-meta' },
        files.size ? h('span', { class: 'meta' }, icon('diff'), plural(files.size, 'file')) : null,
        validationSummary(changes),
        decision && decision.status === 'needs-input' ? h('span', { class: 'badge tone-attention' }, icon('hand'), `Waiting on ${decision.id}`) : null)));
}

function taskDetail(ctx, task) {
    if (!task) {
        return h('p', { class: 'empty', text: 'Select a card to see its goal, changes, and discoveries, or to ask the agent to change its order.' });
    }
    const impl = ctx.data.session.implementation;
    const changes = impl.changes.filter((change) => change.taskId === task.id);
    const discoveries = impl.discoveries.filter((item) => item.taskId === task.id);
    return h('div', { class: 'task-detail', role: 'region', 'aria-label': `${task.id} details` },
        h('p', { class: 'detail-head' }, h('span', { class: 'id-chip', text: task.id }), h('strong', { text: task.title }), badge(TASK_STATUS[task.status])),
        h('p', null, h('strong', { text: 'Goal: ' }), task.goals),
        task.guidance?.length ? h('div', { class: 'guidance' }, h('p', { class: 'meta' }, icon('pencil'), 'Guidance'), h('ul', null, task.guidance.map((line) => h('li', { text: line })))) : null,
        changes.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Changes' }), changes.map((change) => idChip(change.id, ctx.act.navigate))) : null,
        discoveries.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Discoveries' }), discoveries.map((item) => idChip(item.id, ctx.act.navigate))) : null,
        traceStrip(ctx, task.id),
        h('div', { class: 'btn-row' },
            button('Open in plan', { iconName: 'list', onClick: () => ctx.act.navigate(task.id, 'plan') }),
            task.status === 'todo' ? button('Ask the agent to do this next', { iconName: 'arrow-up', onClick: () => ctx.act.requestTask(task.id, `Work on ${task.id} next.`) }) : null,
            task.status !== 'done' ? button('Ask the agent to skip it', { iconName: 'dash-circle', onClick: () => ctx.act.requestTask(task.id, `Skip ${task.id} for now and record why.`) }) : null,
            button('Comment', { iconName: 'message', onClick: () => ctx.act.anchorComposer(task.id, 'comment') })));
}

/**
 * The task board, pinned under the context bar in its own scrolling panel, with a summary
 * line and Collapse.
 */
function boardDock(ctx, tasks) {
    const collapsed = ctx.ui.boardCollapsed === true;
    const done = tasks.filter((task) => task.status === 'done').length;
    const active = tasks.filter(TASK_FILTERS[0].match).length;
    const selected = tasks.find((task) => task.id === ctx.ui.selectedTask) ?? null;
    return h('section', { class: ['board-dock', collapsed ? 'is-collapsed' : null], dataset: { row: 'board' }, tabindex: '-1', 'aria-labelledby': 'board-dock-title' },
        h('header', { class: 'board-dock-head' },
            h('h3', { class: 'board-dock-title', id: 'board-dock-title' }, icon('list'), 'Task board'),
            h('span', { class: 'board-dock-summary', text: `${done} of ${plural(tasks.length, 'task')} done${active ? ` · ${active} in progress` : ''}` }),
            button(collapsed ? 'Expand the task board' : 'Collapse the task board', { iconName: 'chevron', hideLabel: true, attrs: { class: ['btn', 'btn-neutral', 'btn-icon', 'board-dock-toggle'].join(' '), 'aria-expanded': String(!collapsed), 'aria-controls': 'board-dock-body', 'data-key': 'board-toggle' }, onClick: () => ctx.act.toggleBoard() })),
        h('div', { class: 'board-dock-body', id: 'board-dock-body', hidden: collapsed, role: 'region', tabindex: '0', 'aria-label': 'Task board, scrollable' },
            h('div', { class: 'board' }, COLUMNS.map((column) => {
                const items = tasks.filter((task) => task.status === column.status);
                const meta = TASK_STATUS[column.status];
                return h('section', { class: ['board-col', `col-${column.status}`, items.length ? null : 'is-empty'], 'aria-labelledby': `col-${column.status}` },
                    h('h4', { class: 'board-col-title', id: `col-${column.status}` }, icon(meta.icon, { className: `tone-${meta.tone}-fg` }), column.label, h('span', { class: 'count', text: String(items.length) })),
                    items.length ? h('ul', { class: 'board-list' }, items.map((task) => boardCard(ctx, task))) : h('p', { class: 'empty small', text: 'None' }));
            })),
            taskDetail(ctx, selected)));
}

/** What an empty filter means, with Show all. */
function emptyFilter(ctx, filter, tasks) {
    const done = tasks.filter((task) => task.status === 'done').length;
    const text = {
        active: done === tasks.length ? `Nothing is in progress: all ${plural(tasks.length, 'task')} are done.` : done === 0 ? `Nothing is in progress yet; ${plural(tasks.length, 'task')} remain.` : `Nothing is in progress right now; ${done} of ${plural(tasks.length, 'task')} are done.`,
        remaining: 'Nothing remains: every task is done or in progress.',
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
                        h('ol', { class: 'task-list' }, shown.map((task) => taskBlock(ctx, task, phase.tasks.indexOf(task), phase.tasks))));
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
    const chosen = ctx.ui.mapPhase === undefined ? working : ctx.ui.mapPhase;
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

/**
 * Now, for the steering panel on Implement: progress, the tasks being worked on, what is
 * paused for you, blockers, and the latest activity.
 *
 * @param {any} ctx
 */
export function nowSection(ctx) {
    const { session } = ctx.data;
    const impl = session.implementation;
    const tasks = allTasks(ctx);
    const progress = ctx.data.view.progress;
    const current = impl.current ? tasks.find((task) => task.id === impl.current.taskId) : null;
    const working = tasks.filter((task) => TASK_FILTERS[0].match(task) && task.id !== current?.id);
    const paused = session.decisions.filter((decision) => decision.phase === 'implement' && decision.status === 'needs-input');
    return h('div', { class: 'now-panel' },
        h('p', { class: 'now-count' }, h('strong', { text: `${progress.done} of ${progress.total}` }), ' tasks done'),
        h('progress', { class: 'progress', max: String(Math.max(progress.total, 1)), value: String(progress.done), 'aria-label': `${progress.done} of ${progress.total} tasks done` }),
        current
            ? h('p', { class: 'now-task' }, icon('sparkle', { className: 'tone-agent-fg' }), h('span', null, 'The agent is working on ', idChip(current.id, ctx.act.navigate), ' ', h('strong', { text: current.title }), timeEl(impl.current.startedAt, ctx.now) ? [' · started ', timeEl(impl.current.startedAt, ctx.now)] : null))
            : session.session.nextAction ? h('p', { class: 'now-task' }, icon('info'), h('span', { text: session.session.nextAction })) : null,
        working.length ? h('ul', { class: 'now-list', 'aria-label': 'Other tasks in progress' }, working.map((task) => h('li', null, badge(TASK_STATUS[task.status]), ' ', idChip(task.id, ctx.act.navigate), ' ', h('span', { text: task.title })))) : null,
        paused.length ? h('ul', { class: 'now-list', 'aria-label': 'Paused for you' }, paused.map((decision) => h('li', null, icon('pause', { className: 'tone-attention-fg' }), ' Paused for you: ', idChip(decision.id, ctx.act.navigate), ' ', h('span', { text: decision.title })))) : null,
        impl.blockers.length ? h('ul', { class: 'now-list', 'aria-label': 'Blockers' }, impl.blockers.map((blocker) => h('li', null, icon('alert', { className: 'tone-danger-fg' }), ' ', blocker.taskId ? [idChip(blocker.taskId, ctx.act.navigate), ' '] : null, blocker.text, blockerNote(blocker)))) : null,
        impl.activity.length ? h('ol', { class: 'activity', 'aria-label': 'Latest agent activity, newest first' }, impl.activity.slice(-4).reverse().map((line) => h('li', null, icon(ACTIVITY_ICON[line.kind] ?? 'info'), h('span', { class: 'activity-text', text: line.text }), timeEl(line.at, ctx.now)))) : null);
}

export function renderView(ctx) {
    const { session } = ctx.data;
    const impl = session.implementation;
    const tasks = allTasks(ctx);
    const rows = [boardDock(ctx, tasks)];
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
