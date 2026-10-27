// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, DISCOVERY_KIND, h, icon, idChip, idTag, known, plural, sr, TASK_STATUS, timeEl, VALIDATION } from './dom.mjs';
import { decisionCard, marginNote, md, mdInline, recordRow, row, rowActions, sectionBody, table, traceStrip } from './components.mjs';
import { anchoredDecisions, notesFor } from './view-research.mjs';
import { plainInline } from './markdown.mjs';

/** Implement view: now banner, board, changes, discoveries and plan updates, alignment, and validation. */

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
    const impl = ctx.data.session.implementation;
    return [
        { id: 'now', label: 'Now' },
        { id: 'board', label: 'Task board' },
        { id: 'changes', label: 'Changes', count: impl.changes.length },
        { id: 'discoveries', label: 'Discoveries and plan updates', count: impl.discoveries.length },
        { id: 'alignment', label: 'Business alignment', count: impl.alignment.length },
        { id: 'validation', label: 'Validation and blockers', count: impl.validation.length },
        ctx.data.session.records?.implement?.length ? { id: 'implement-record', label: 'Changes record', count: ctx.data.session.records.implement.length } : null,
    ].filter(Boolean);
}

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

export function renderView(ctx) {
    const { session } = ctx.data;
    const impl = session.implementation;
    const tasks = allTasks(ctx);
    const current = impl.current ? tasks.find((task) => task.id === impl.current.taskId) : null;
    const paused = session.decisions.filter((decision) => decision.phase === 'implement' && decision.status === 'needs-input');
    const progress = ctx.data.view.progress;
    const rows = [];

    rows.push(row(ctx, {
        id: 'now', idLabel: null, title: 'Now', level: 2,
        badges: [chip(`${progress.done} of ${progress.total} tasks done`, progress.done === progress.total ? 'success' : 'muted')],
        body: [
            h('progress', { class: 'progress', max: String(Math.max(progress.total, 1)), value: String(progress.done), 'aria-label': `${progress.done} of ${progress.total} tasks done` }),
            current
                ? h('div', { class: 'now-task' }, icon('sparkle', { className: 'tone-agent-fg' }), h('span', null, 'The agent is working on ', idChip(current.id, ctx.act.navigate), ' ', h('strong', { text: current.title }), timeEl(impl.current.startedAt, ctx.now) ? [' · started ', timeEl(impl.current.startedAt, ctx.now)] : null))
                : session.session.nextAction ? h('p', { class: 'now-task' }, icon('info'), session.session.nextAction) : null,
            impl.activity.length ? h('ol', { class: 'activity', 'aria-label': 'Latest agent activity, newest first' }, impl.activity.slice(-6).reverse().map((line) => h('li', null, icon(ACTIVITY_ICON[line.kind] ?? 'info'), h('span', { class: 'activity-text', text: line.text }), timeEl(line.at, ctx.now)))) : null,
        ],
        margin: [
            ...paused.map((decision) => h('article', { class: ['card', 'paused-card'] },
                h('header', { class: 'card-head' }, icon('pause', { className: 'card-icon tone-attention-fg' }), h('h4', { class: 'card-title', text: 'Work is paused for you' })),
                h('p', null, h('span', { class: 'id-chip', text: decision.id }), ` ${decision.title}`),
                h('p', { class: 'meta' }, mdInline(ctx, decision.impact, { doc: decision.phase })),
                h('div', { class: 'btn-row' }, button('Answer now', { kind: 'primary', iconName: 'hand', onClick: () => ctx.act.navigate(decision.id) })))),
            impl.blockers.length ? h('article', { class: 'card' }, h('header', { class: 'card-head' }, icon('alert', { className: 'card-icon tone-danger-fg' }), h('h4', { class: 'card-title', text: plural(impl.blockers.length, 'blocker') })),
                impl.blockers.map((blocker) => h('p', null, blocker.taskId ? [idChip(blocker.taskId, ctx.act.navigate), ' '] : null, blocker.text, blockerNote(blocker)))) : null,
        ],
    }));

    const selected = tasks.find((task) => task.id === ctx.ui.selectedTask) ?? null;
    rows.push(row(ctx, {
        id: 'board', idLabel: null, title: 'Task board', level: 2,
        body: [
            h('div', { class: 'board' }, COLUMNS.map((column) => {
                const items = tasks.filter((task) => task.status === column.status);
                const meta = TASK_STATUS[column.status];
                return h('section', { class: ['board-col', `col-${column.status}`], 'aria-labelledby': `col-${column.status}` },
                    h('h4', { class: 'board-col-title', id: `col-${column.status}` }, icon(meta.icon, { className: `tone-${meta.tone}-fg` }), column.label, h('span', { class: 'count', text: String(items.length) })),
                    items.length ? h('ul', { class: 'board-list' }, items.map((task) => boardCard(ctx, task))) : h('p', { class: 'empty small', text: 'None' }));
            })),
            taskDetail(ctx, selected),
        ],
    }));

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
