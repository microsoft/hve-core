// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, button, chip, h, icon, idChip, SEVERITY, TASK_STATUS } from './dom.mjs';
import { decisionCard, marginNote, row, rowActions, sectionBody, table } from './components.mjs';
import { renderDiagram } from './diagram.mjs';
import { anchoredDecisions, notesFor } from './view-research.mjs';

/** Plan view: summary, change map, phases with expandable tasks, requirements, and critique. */

const DISPOSITION = {
    resolved: { icon: 'check-circle', label: 'Resolved', tone: 'success' },
    'accepted with risk': { icon: 'alert', label: 'Accepted with risk', tone: 'attention' },
    open: { icon: 'hand', label: 'Open', tone: 'attention' },
    superseded: { icon: 'dash-circle', label: 'Superseded', tone: 'muted' },
};

export function outline(ctx) {
    const plan = ctx.data.session.plan;
    return [
        { id: 'plan-summary', label: 'Summary' },
        { id: 'change-map', label: 'Change map' },
        ...plan.phases.map((phase) => ({ id: phase.id, label: phase.title, prefix: phase.id, count: `${phase.tasks.filter((t) => t.status === 'done').length}/${phase.tasks.length}` })),
        { id: 'requirements', label: 'Requirements', count: plan.requirements.length },
        { id: 'critique', label: 'Critique', count: plan.critique?.findings.length ?? 0 },
    ];
}

function taskBlock(ctx, task, index, siblings) {
    const expanded = ctx.ui.expanded.has(task.id);
    const panelId = `task-panel-${task.id}`;
    const decision = task.decisionId ? ctx.data.session.decisions.find((d) => d.id === task.decisionId) : null;
    return h('li', { class: ['task', `is-${task.status}`, ctx.ui.highlight === task.id ? 'is-highlight' : null], dataset: { item: task.id }, tabindex: '-1' },
        h('div', { class: 'task-head' },
            h('button', { type: 'button', class: 'task-toggle', 'aria-expanded': String(expanded), 'aria-controls': panelId, onclick: () => ctx.act.toggleExpanded(task.id) },
                icon('chevron', { className: 'chev' }),
                h('span', { class: 'id-chip', text: task.id }),
                h('span', { class: 'task-title', text: task.title })),
            badge(TASK_STATUS[task.status]),
            decision && decision.status === 'needs-input' ? h('button', { type: 'button', class: 'badge tone-attention is-link', onclick: () => ctx.act.navigate(decision.id) }, icon('hand'), `Waiting on ${decision.id}`) : null),
        h('div', { class: 'task-panel', id: panelId, hidden: !expanded },
            h('p', { class: 'task-goal' }, h('strong', { text: 'Goal: ' }), task.goals),
            h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Requirements' }), task.requirements.map((id) => idChip(id, ctx.act.navigate))),
            h('div', { class: 'task-details' }, h('p', { class: 'meta', text: 'Details' }), sectionBody(ctx, task.sectionId)),
            task.guidance?.length ? h('div', { class: 'guidance' }, h('p', { class: 'meta' }, icon('pencil'), 'Guidance added during implementation'), h('ul', null, task.guidance.map((line) => h('li', { text: line })))) : null,
            h('p', { class: 'chip-row' }, h('span', { class: 'meta', text: 'Depends on' }), task.dependencies.length ? task.dependencies.map((id) => idChip(id, ctx.act.navigate)) : h('span', { class: 'meta', text: 'nothing' })),
            h('div', { class: 'btn-row' },
                button('Edit details', { iconName: 'pencil', onClick: () => ctx.act.startEdit(task.sectionId) }),
                button('Move up', { iconName: 'arrow-up', disabled: index === 0, onClick: () => ctx.act.requestTask(task.id, `Move ${task.id} before ${siblings[index - 1]?.id}.`) }),
                button('Move down', { iconName: 'arrow-down', disabled: index === siblings.length - 1, onClick: () => ctx.act.requestTask(task.id, `Move ${task.id} after ${siblings[index + 1]?.id}.`) }),
                button('Comment', { iconName: 'message', onClick: () => ctx.act.anchorComposer(task.id, 'comment') }))));
}

export function renderView(ctx) {
    const plan = ctx.data.session.plan;
    const rows = [];
    const critique = plan.critique;
    const readiness = plan.readiness;
    rows.push(row(ctx, {
        id: 'plan-summary', idLabel: null, title: 'Summary', level: 2,
        badges: [readiness ? badge(readiness.status === 'ready' ? { icon: 'check-circle', label: 'Ready to implement', tone: 'success' } : { icon: 'hand', label: 'Not ready', tone: 'attention' }) : null],
        actions: rowActions(ctx, { sectionId: 'plan-summary', rowId: 'plan-summary' }),
        body: [sectionBody(ctx, 'plan-summary'), readiness ? h('p', { class: 'readiness-line' }, icon(readiness.status === 'ready' ? 'check' : 'hand'), readiness.text) : null,
            h('div', { class: 'callout' }, icon('bulb', { className: 'callout-icon' }), sectionBody(ctx, 'plan-unknowns'))],
        margin: [critique ? h('article', { class: 'card' },
            h('header', { class: 'card-head' }, icon('shield-check', { className: 'card-icon' }), h('h4', { class: 'card-title', text: 'Plan critique' }), badge(critique.verdict === 'Pass' ? { icon: 'check', label: 'Pass', tone: 'success' } : { icon: 'pencil', label: critique.verdict, tone: 'attention' })),
            h('p', { text: `${critique.findings.length} findings, ${critique.findings.filter((f) => f.disposition === 'resolved').length} resolved in the plan. Setting: ${critique.setting}.` }),
            h('div', { class: 'btn-row' }, button('Review findings', { iconName: 'arrow-down', onClick: () => ctx.act.navigate('critique') }))) : null],
    }));

    const view = ctx.ui.diagramView;
    const phaseIds = plan.phases.map((phase) => phase.id);
    const highlight = view === 'after' && ctx.ui.diagramPhase ? plan.diagram?.phaseNodes?.[ctx.ui.diagramPhase] ?? [] : [];
    rows.push(row(ctx, {
        id: 'change-map', idLabel: null, title: 'Change map', level: 2,
        body: plan.diagram ? [
            h('div', { class: 'map-controls' },
                h('fieldset', { class: 'segmented compact' }, h('legend', { class: 'visually-hidden', text: 'Diagram' }),
                    ['before', 'after'].map((value) => h('label', { for: `map-${value}` }, h('input', { type: 'radio', name: 'map-view', id: `map-${value}`, value, checked: view === value, onchange: () => ctx.act.setDiagram({ view: value }) }), h('span', { text: value === 'before' ? 'Before' : 'After' })))),
                view === 'after' ? h('fieldset', { class: 'segmented compact' }, h('legend', { class: 'meta', text: 'Highlight' }),
                    ['none', ...phaseIds].map((value) => h('label', { for: `map-phase-${value}` }, h('input', { type: 'radio', name: 'map-phase', id: `map-phase-${value}`, value, checked: (ctx.ui.diagramPhase ?? 'none') === value, onchange: () => ctx.act.setDiagram({ phase: value === 'none' ? null : value }) }), h('span', { text: value === 'none' ? 'None' : value })))) : null),
            renderDiagram(view === 'before' ? plan.diagram.before : plan.diagram.after, { caption: view === 'before' ? 'Before: how the app saves today' : `After: the intended result${highlight.length ? `, ${ctx.ui.diagramPhase} highlighted` : ''}`, highlight, idPrefix: `map-${view}`, textOpen: ctx.ui.openDetails.has('map-text'), onTextToggle: (open) => ctx.act.setDetailsOpen('map-text', open) }),
            h('p', { class: 'meta legend' }, h('span', { class: 'legend-swatch is-new' }), ' Dashed border: added by this plan. ', h('span', { class: 'legend-swatch is-highlight' }), ' Filled: the highlighted phase.'),
        ] : [h('p', { class: 'empty', text: 'Not recorded' })],
    }));

    for (const phase of plan.phases) {
        const done = phase.tasks.filter((task) => task.status === 'done').length;
        const taskIds = phase.tasks.map((task) => task.id);
        rows.push(row(ctx, {
            id: phase.id, title: phase.title,
            badges: [chip(`${done} of ${phase.tasks.length} done`, done === phase.tasks.length ? 'success' : 'muted')],
            actions: rowActions(ctx, { rowId: phase.id }),
            body: [h('p', { class: 'phase-goal', text: phase.goals }), h('ol', { class: 'task-list' }, phase.tasks.map((task, index) => taskBlock(ctx, task, index, phase.tasks)))],
            margin: [...anchoredDecisions(ctx, [phase.id, ...taskIds]).map((decision) => decisionCard(ctx, decision)), ...notesFor(ctx, [phase.id, ...taskIds]).map((item) => marginNote(ctx, item))],
        }));
    }

    const coverage = new Map(plan.requirements.map((req) => [req.id, []]));
    for (const phase of plan.phases) {
        for (const task of phase.tasks) {
            for (const id of task.requirements) coverage.get(id)?.push(task.id);
        }
    }
    rows.push(row(ctx, {
        id: 'requirements', idLabel: null, title: 'Requirements', level: 2,
        body: [table('Requirement coverage', ['ID', 'Requirement', 'Covered by'], plan.requirements.map((req) => [
            h('span', { class: 'id-chip', dataset: { item: req.id }, tabindex: '-1', text: req.id }), req.text,
            coverage.get(req.id).length ? h('span', { class: 'chip-row' }, coverage.get(req.id).map((id) => idChip(id, ctx.act.navigate))) : badge({ icon: 'alert', label: 'Not covered', tone: 'danger' }),
        ]))],
    }));

    rows.push(row(ctx, {
        id: 'critique', idLabel: null, title: 'Critique', level: 2,
        badges: critique ? [badge({ icon: 'pencil', label: `Verdict: ${critique.verdict}`, tone: critique.verdict === 'Pass' ? 'success' : 'attention' })] : [],
        body: critique ? [h('ul', { class: 'finding-list' }, critique.findings.map((finding) => h('li', { class: 'mini-finding', dataset: { item: finding.id }, tabindex: '-1' },
            h('p', { class: 'mini-head' }, badge(SEVERITY[finding.severity]), h('span', { class: 'id-chip', text: finding.id }), h('strong', { text: finding.title }), badge(DISPOSITION[finding.disposition])),
            h('p', { class: 'meta' }, finding.response, ' ', finding.related.map((id) => idChip(id, ctx.act.navigate))))))] : [h('p', { class: 'empty', text: 'The critique has not run yet.' })],
    }));
    return rows;
}
