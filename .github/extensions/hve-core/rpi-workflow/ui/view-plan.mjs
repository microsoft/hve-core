// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, h, icon, idChip, idTag, known, plural, SEVERITY, TASK_STATUS } from './dom.mjs';
import { decisionCard, decisionsRow, marginNote, mdInline, recordRow, row, rowActions, sectionBody, table, traceStrip, updatedMark } from './components.mjs';
import { renderDiagram } from './diagram.mjs';
import { anchoredDecisions, decisionsOutline, notesFor } from './view-research.mjs';

/** Plan view: summary, change map, phases with expandable tasks, requirements, and critique. */

const DISPOSITION = {
    resolved: { icon: 'check-circle', label: 'Resolved', tone: 'success' },
    'accepted with risk': { icon: 'alert', label: 'Accepted with risk', tone: 'attention' },
    open: { icon: 'hand', label: 'Open', tone: 'attention' },
    superseded: { icon: 'dash-circle', label: 'Superseded', tone: 'muted' },
};

/** A critique lens's status, in words and with an icon. */
const LENS_STATUS = {
    queued: { icon: 'clock', label: 'Queued', tone: 'muted' },
    'in progress': { icon: 'active', label: 'In progress', tone: 'accent' },
    complete: { icon: 'check', label: 'Done', tone: 'success' },
    partial: { icon: 'alert', label: 'Partial', tone: 'attention' },
    blocked: { icon: 'x-circle', label: 'Blocked', tone: 'danger' },
};

/** Finished lenses, the lens in progress, and the total. */
export function lensProgress(critique) {
    const lenses = critique?.lenses ?? [];
    const done = lenses.filter((lens) => lens.status !== 'queued' && lens.status !== 'in progress').length;
    return { done, total: lenses.length, current: lenses.find((lens) => lens.status === 'in progress') ?? null };
}

/** Findings the plan has addressed, any disposition but open, of all findings. */
export function addressedFindings(critique) {
    const findings = critique?.findings ?? [];
    return { done: findings.filter((finding) => finding.disposition !== 'open').length, total: findings.length };
}

const progressBar = (done, total, label) => h('progress', { class: 'progress', max: String(Math.max(total, 1)), value: String(done), 'aria-label': label });

/** What a critique is doing now: running with its lens progress, stopped, or how far the plan's revision has come. */
function critiqueProgress(critique) {
    const findings = critique.findings.length;
    if (critique.run) {
        const lenses = lensProgress(critique);
        const so = `${plural(findings, 'finding')} so far.`;
        const text = critique.run === 'stopped'
            ? `The critique stopped before it finished${lenses.total ? `, after ${lenses.done} of ${lenses.total} lenses` : ''}; ${so}`
            : lenses.current ? `Assessing the ${lenses.current.lens} lens, ${lenses.done + 1} of ${lenses.total}; ${so}` : lenses.total ? `${lenses.done} of ${lenses.total} lenses done; ${so}` : `Starting; ${so}`;
        return [lenses.total ? progressBar(lenses.done, lenses.total, `${lenses.done} of ${lenses.total} critique lenses done`) : null, h('p', { class: 'critique-now', text })];
    }
    const fixed = addressedFindings(critique);
    if (!fixed.total) return [];
    const text = `${fixed.done} of ${plural(fixed.total, 'finding')} addressed in the plan.`;
    return fixed.done < fixed.total ? [progressBar(fixed.done, fixed.total, text), h('p', { class: 'critique-now', text })] : [h('p', { class: 'critique-now', text })];
}

function runBadge(critique, long = false) {
    if (critique?.run === 'running') return badge({ icon: 'active', label: long ? 'Critique running' : 'Running', tone: 'accent' });
    if (critique?.run === 'stopped') return badge({ icon: 'pause', label: long ? 'Critique stopped' : 'Stopped', tone: 'attention' });
    return null;
}

export function outline(ctx) {
    const plan = ctx.data.session.plan;
    return [
        { id: 'plan-summary', label: 'Summary' },
        plan.diagram ? { id: 'change-map', label: 'Change map' } : null,
        ...plan.phases.map((phase) => ({ id: phase.id, label: phase.title, prefix: phase.id, count: `${phase.tasks.filter((t) => t.status === 'done').length}/${phase.tasks.length}` })),
        ...decisionsOutline(ctx, 'plan'),
        { id: 'requirements', label: 'Requirements', count: plan.requirements.length },
        { id: 'critique', label: 'Critique', count: plan.critique?.findings.length ?? 0 },
        ctx.data.session.records?.plan?.length ? { id: 'plan-record', label: 'Plan record', count: ctx.data.session.records.plan.length } : null,
    ].filter(Boolean);
}

/**
 * One task, expandable, with its goal, requirements, details, guidance, dependencies, and
 * actions. `siblings` is the phase's full task list, so Move up and Move down follow plan
 * order wherever the block appears. On Implement (`options.implement`), the task also shows
 * its changes, discoveries, and trace, and offers to ask the agent to do it next or skip it.
 *
 * @param {any} ctx
 * @param {any} task
 * @param {number} index
 * @param {any[]} siblings
 * @param {{ implement?: boolean }} [options]
 */
export function taskBlock(ctx, task, index, siblings, options = {}) {
    const expanded = ctx.ui.expanded.has(task.id);
    const panelId = `task-panel-${task.id}`;
    const decision = task.decisionId ? ctx.data.session.decisions.find((d) => d.id === task.decisionId) : null;
    const impl = ctx.data.session.implementation;
    const changes = options.implement ? impl.changes.filter((change) => change.taskId === task.id) : [];
    const discoveries = options.implement ? impl.discoveries.filter((item) => item.taskId === task.id) : [];
    return h('li', { class: ['task', `is-${task.status}`, ctx.ui.highlight === task.id ? 'is-highlight' : null], dataset: { item: task.id }, tabindex: '-1' },
        h('div', { class: 'task-head' },
            h('button', { type: 'button', class: 'task-toggle', 'aria-expanded': String(expanded), 'aria-controls': panelId, onclick: () => ctx.act.toggleExpanded(task.id) },
                icon('chevron', { className: 'chev' }),
                idTag(task.id, 'file'),
                h('span', { class: 'task-title', text: task.title })),
            badge(TASK_STATUS[task.status]),
            updatedMark(ctx, task.sectionId),
            decision && decision.status === 'needs-input' ? h('button', { type: 'button', class: 'badge tone-attention is-link', onclick: () => ctx.act.navigate(decision.id) }, icon('hand'), `Waiting on ${decision.id}`, icon('go-to', { className: 'icon-inline chip-icon' })) : null),
        h('div', { class: 'task-panel', id: panelId, hidden: !expanded },
            task.goals ? h('p', { class: 'task-goal' }, h('strong', { text: 'Goal: ' }), task.goals) : null,
            task.requirements.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Requirements' }), task.requirements.map((id) => idChip(id, ctx.act.navigate))) : null,
            h('div', { class: 'task-details' }, h('p', { class: 'meta', text: 'Details' }), sectionBody(ctx, task.sectionId)),
            task.guidance?.length ? h('div', { class: 'guidance' }, h('p', { class: 'meta' }, icon('pencil'), 'Guidance added during implementation'), h('ul', null, task.guidance.map((line) => h('li', { text: line })))) : null,
            h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Depends on' }), task.dependencies.length ? task.dependencies.map((id) => idChip(id, ctx.act.navigate)) : h('span', { class: 'meta', text: 'nothing' })),
            changes.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Changes' }), changes.map((change) => idChip(change.id, ctx.act.navigate))) : null,
            discoveries.length ? h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Discoveries' }), discoveries.map((item) => idChip(item.id, ctx.act.navigate))) : null,
            options.implement ? traceStrip(ctx, task.id) : null,
            ctx.readOnly ? null : h('div', { class: 'btn-row' },
                options.implement && task.status === 'todo' ? button('Ask the agent to do this next', { iconName: 'arrow-up', onClick: () => ctx.act.requestTask(task.id, `Work on ${task.id} next.`) }) : null,
                options.implement && task.status !== 'done' ? button('Ask the agent to skip it', { iconName: 'dash-circle', onClick: () => ctx.act.requestTask(task.id, `Skip ${task.id} for now and record why.`) }) : null,
                button('Suggest an edit', { iconName: 'pencil', onClick: () => ctx.act.startEdit(task.sectionId) }),
                button('Move up', { iconName: 'arrow-up', disabled: index === 0, onClick: () => ctx.act.requestTask(task.id, `Move ${task.id} before ${siblings[index - 1]?.id}.`) }),
                button('Move down', { iconName: 'arrow-down', disabled: index === siblings.length - 1, onClick: () => ctx.act.requestTask(task.id, `Move ${task.id} after ${siblings[index + 1]?.id}.`) }),
                button('Comment', { iconName: 'message', onClick: () => ctx.act.anchorComposer(task.id) }))));
}

export function renderView(ctx) {
    const plan = ctx.data.session.plan;
    const rows = [];
    const critique = plan.critique;
    const readiness = plan.readiness;
    rows.push(row(ctx, {
        id: 'plan-summary', idLabel: null, title: 'Summary', level: 2,
        badges: [readiness ? badge(readiness.status === 'ready' ? { icon: 'check-circle', label: 'Ready to implement', tone: 'success' } : { icon: 'hand', label: 'Not ready', tone: 'attention' }) : null, updatedMark(ctx, 'plan-summary')],
        actions: rowActions(ctx, { sectionId: 'plan-summary', rowId: 'plan-summary' }),
        body: [sectionBody(ctx, 'plan-summary'), readiness ? h('p', { class: 'readiness-line' }, icon(readiness.status === 'ready' ? 'check' : 'hand'), h('span', null, mdInline(ctx, readiness.text, { doc: 'plan' }))) : null,
            ctx.data.session.sections['plan-unknowns'] ? h('div', { class: 'callout' }, icon('bulb', { className: 'callout-icon' }), h('div', { class: 'callout-body' }, updatedMark(ctx, 'plan-unknowns'), sectionBody(ctx, 'plan-unknowns'))) : null],
        margin: [critique ? h('article', { class: ['card', 'critique-card', critique.run ? `is-${critique.run}` : null] },
            h('header', { class: 'card-head' }, icon('shield-check', { className: 'card-icon' }), h('h4', { class: 'card-title', text: 'Plan critique' }), runBadge(critique) ?? verdictBadge(critique.verdict)),
            ...critiqueProgress(critique),
            critique.run ? null : h('p', { class: 'meta', text: `${plural(critique.findings.length, 'finding')}.${critique.setting ? ` Setting: ${critique.setting}.` : ''}` }),
            h('div', { class: 'btn-row' }, button(critique.run ? 'Go to the critique' : 'Review findings', { iconName: 'arrow-down', onClick: () => ctx.act.navigate('critique') }))) : null],
    }));

    const view = ctx.ui.diagramView;
    const phaseIds = plan.phases.map((phase) => phase.id);
    const highlight = view === 'after' && ctx.ui.diagramPhase ? plan.diagram?.phaseNodes?.[ctx.ui.diagramPhase] ?? [] : [];
    if (plan.diagram) rows.push(row(ctx, {
        id: 'change-map', idLabel: null, title: 'Change map', level: 2,
        body: [
            h('div', { class: 'map-controls' },
                h('fieldset', { class: 'segmented compact' }, h('legend', { class: 'visually-hidden', text: 'Diagram' }),
                    ['before', 'after'].map((value) => h('label', { for: `map-${value}` }, h('input', { type: 'radio', name: 'map-view', id: `map-${value}`, value, checked: view === value, onchange: () => ctx.act.setDiagram({ view: value }) }), h('span', { text: value === 'before' ? 'Before' : 'After' })))),
                view === 'after' ? h('fieldset', { class: 'segmented compact' }, h('legend', { class: 'meta', text: 'Highlight' }),
                    ['none', ...phaseIds].map((value) => h('label', { for: `map-phase-${value}` }, h('input', { type: 'radio', name: 'map-phase', id: `map-phase-${value}`, value, checked: (ctx.ui.diagramPhase ?? 'none') === value, onchange: () => ctx.act.setDiagram({ phase: value === 'none' ? null : value }) }), h('span', { text: value === 'none' ? 'None' : value })))) : null),
            renderDiagram(view === 'before' ? plan.diagram.before : plan.diagram.after, { caption: view === 'before' ? 'Before: how the app saves today' : `After: the intended result${highlight.length ? `, ${ctx.ui.diagramPhase} highlighted` : ''}`, highlight, idPrefix: `map-${view}`, textOpen: ctx.ui.openDetails.has('map-text'), onTextToggle: (open) => ctx.act.setDetailsOpen('map-text', open) }),
            h('p', { class: 'meta legend' }, h('span', { class: 'legend-swatch is-new' }), ' Dashed border: added by this plan. ', h('span', { class: 'legend-swatch is-highlight' }), ' Filled: the highlighted phase.'),
        ],
    }));

    for (const phase of plan.phases) {
        const done = phase.tasks.filter((task) => task.status === 'done').length;
        const taskIds = phase.tasks.map((task) => task.id);
        rows.push(row(ctx, {
            id: phase.id, title: phase.title,
            badges: [chip(`${done} of ${phase.tasks.length} done`, done === phase.tasks.length ? 'success' : 'muted')],
            actions: rowActions(ctx, { rowId: phase.id }),
            body: [phase.goals ? h('p', { class: 'phase-goal', text: phase.goals }) : null, h('ol', { class: 'task-list' }, phase.tasks.map((task, index) => taskBlock(ctx, task, index, phase.tasks)))],
            margin: [...anchoredDecisions(ctx, [phase.id, ...taskIds]).map((decision) => decisionCard(ctx, decision)), ...notesFor(ctx, [phase.id, ...taskIds]).map((item) => marginNote(ctx, item))],
        }));
    }

    const decisions = decisionsRow(ctx, 'plan');
    if (decisions) rows.push(decisions);

    const coverage = new Map(plan.requirements.map((req) => [req.id, []]));
    for (const phase of plan.phases) {
        for (const task of phase.tasks) {
            for (const id of task.requirements) coverage.get(id)?.push(task.id);
        }
    }
    rows.push(row(ctx, {
        id: 'requirements', idLabel: null, title: 'Requirements', level: 2,
        body: [table('Requirement coverage', ['ID', 'Requirement', 'Covered by'], plan.requirements.map((req) => [
            h('span', { class: 'id-chip', dataset: { item: req.id }, tabindex: '-1', text: req.id }), mdInline(ctx, req.text, { doc: 'plan' }),
            coverage.get(req.id).length ? h('span', { class: 'chip-row' }, coverage.get(req.id).map((id) => idChip(id, ctx.act.navigate))) : badge({ icon: 'alert', label: 'Not covered', tone: 'danger' }),
        ]))],
    }));

    rows.push(row(ctx, {
        id: 'critique', idLabel: null, title: 'Critique', level: 2,
        badges: runBadge(critique, true) ? [runBadge(critique, true)] : critique?.verdict ? [badge({ icon: critique.verdict === 'Pass' ? 'check' : 'pencil', label: `Verdict: ${critique.verdict}`, tone: critique.verdict === 'Pass' ? 'success' : 'attention' })] : [],
        body: critique ? [
            critique.lenses?.length ? h('ol', { class: 'lens-list', 'aria-label': 'Critique lenses' }, critique.lenses.map((lens) => h('li', { class: ['lens-item', `is-${lens.status.replace(' ', '-')}`] }, badge(LENS_STATUS[lens.status] ?? LENS_STATUS.complete), h('span', { class: 'lens-name', text: lens.lens })))) : null,
            ...critiqueProgress(critique),
            critique.findings.length ? null : h('p', { class: 'empty', text: critique.run === 'running' ? 'No findings yet. Each lens adds its findings when it finishes.' : 'The critique recorded no findings.' }),
            h('ul', { class: 'finding-list' }, critique.findings.map((finding) => h('li', { class: 'mini-finding', dataset: { item: finding.id }, tabindex: '-1' },
            h('p', { class: 'mini-head' }, badge(known(SEVERITY, finding.severity), { strong: true }), h('span', { class: 'id-chip', text: finding.id }), h('strong', { text: finding.title }), badge(known(DISPOSITION, finding.disposition))),
            h('p', { class: 'meta' }, mdInline(ctx, finding.response, { doc: 'plan' }), ' ', finding.related.map((id) => idChip(id, ctx.act.navigate))))))] : [h('p', { class: 'empty', text: 'No critique has been recorded for this plan.' })],
    }));

    const record = recordRow(ctx, 'plan', 'Plan record');
    if (record) rows.push(record);
    return rows;
}

function verdictBadge(verdict) {
    if (!verdict) return null;
    return badge(verdict === 'Pass' ? { icon: 'check', label: 'Pass', tone: 'success' } : { icon: 'pencil', label: verdict, tone: 'attention' });
}
