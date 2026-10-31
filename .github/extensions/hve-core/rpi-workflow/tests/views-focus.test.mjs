// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { buildScenario } from '../lib/scenario.mjs';
import { elements, installFakeDom } from './helpers/fake-dom.mjs';
import { initialUi, makeContext } from './helpers/render-views.mjs';

const NOW = Date.parse('2026-10-29T12:00:00Z');
const PHASES = ['research', 'plan', 'implement', 'review', 'followup'];
let restore;
let components;
let h;
before(async () => {
    restore = installFakeDom();
    components = await import('../ui/components.mjs');
    ({ h } = await import('../ui/dom.mjs'));
});
after(() => restore());

async function render(session, phase, presentation = 'focused') {
    const ctx = makeContext(session, phase, { ...initialUi(phase), presentation });
    const view = await import(`../ui/view-${phase}.mjs`);
    const root = document.createElement('div');
    root.append(...view.renderView(ctx));
    return root;
}

const rowById = (root, id) => elements(root).find((node) => node.dataset.row === id);
const folded = (root, id) => rowById(root, id).classList.contains('is-folded');

describe('focused presentation', () => {
    it('offers an explicitly labeled, page-local choice with Focused selected by default', () => {
        const ctx = makeContext(buildScenario('research', NOW), 'research');
        const before = JSON.stringify(ctx.data.session);
        let chosen;
        ctx.act = { setPresentation: (value) => { chosen = value; } };
        const control = components.presentationControl(ctx);
        const select = control.querySelector('select');
        assert.equal(select.getAttribute('aria-label'), 'Information detail');
        assert.equal(select.querySelector('option').getAttribute('selected'), '');
        select.listeners.change[0]({ target: { value: 'full' } });
        assert.equal(chosen, 'full');
        assert.equal(JSON.stringify(ctx.data.session), before);
    });

    it('folds only secondary bodies and keeps disclosure state across renders', () => {
        const ctx = makeContext(buildScenario('research', NOW), 'research');
        const spec = { id: 'support', title: 'Supporting detail', secondary: true, body: [h('p', { text: 'Complete source text' })] };
        const first = components.row(ctx, spec);
        const toggle = first.querySelector('.row-toggle');
        assert.equal(toggle.getAttribute('aria-expanded'), 'false');
        assert.equal(toggle.getAttribute('aria-controls'), 'row-support-body');
        assert.equal(first.querySelector('.row-text').hidden, true);
        assert.match(first.textContent, /Complete source text/);
        ctx.ui.openDetails.add(first.dataset.disclosure);
        const opened = components.row(ctx, { ...spec, body: [h('p', { text: 'Complete source text' })] });
        assert.equal(opened.querySelector('.row-text').hidden, false);
        assert.equal(opened.querySelector('.row-toggle').getAttribute('aria-expanded'), 'true');
        ctx.ui.presentation = 'full';
        const full = components.row(ctx, { ...spec, body: [h('p', { text: 'Complete source text' })] });
        assert.equal(full.querySelector('.row-toggle'), null);
        assert.notEqual(full.querySelector('.row-text').hidden, true);
    });

    it('never folds a secondary row containing a pending decision or an open editor', () => {
        const ctx = makeContext(buildScenario('research', NOW), 'research');
        for (const content of [
            h('article', { class: 'decision is-needs-input', text: 'Choose an option' }),
            h('textarea', null, 'Unsaved draft'),
        ]) {
            const row = components.row(ctx, { id: 'waiting', title: 'Needs your input', secondary: true, body: [content] });
            assert.equal(row.querySelector('.row-toggle'), null);
            assert.notEqual(row.querySelector('.row-text').hidden, true);
        }
    });

    it('reveals a navigation target and its margin while persisting the expansion', () => {
        const body = { hidden: true };
        const margin = { hidden: true };
        const attributes = new Map();
        let removed;
        const section = {
            dataset: { disclosure: 'row:research:F1' },
            classList: { remove: (name) => { removed = name; } },
            querySelector: (selector) => ({ '.row-text': body, '.row-margin': margin, '.row-toggle': { setAttribute: (key, value) => attributes.set(key, value) } })[selector],
        };
        const target = { closest: (selector) => {
            assert.equal(selector, '.row[data-disclosure]');
            return section;
        } };
        const saved = [];
        components.revealRow(target, { setDetailsOpen: (...args) => saved.push(args) });
        assert.equal(body.hidden, false);
        assert.equal(margin.hidden, false);
        assert.equal(removed, 'is-folded');
        assert.equal(attributes.get('aria-expanded'), 'true');
        assert.deepEqual(saved, [['row:research:F1', true]]);
        components.revealRow(null, {});
    });

    it('retains every rendered item and source body in both modes across all phases', async () => {
        const session = buildScenario('followup', NOW);
        const before = JSON.stringify(session);
        for (const phase of PHASES) {
            const focus = await render(session, phase);
            const full = await render(session, phase, 'full');
            const ids = (root) => elements(root).map((node) => node.dataset.item).filter(Boolean).sort();
            assert.deepEqual(ids(focus), ids(full), phase);
            const bodies = (root) => elements(root).filter((node) => node.classList.contains('row-text')).map((node) => node.textContent);
            assert.deepEqual(bodies(focus), bodies(full), phase);
            assert.ok(!elements(full).some((node) => node.classList.contains('is-folded')), phase);
        }
        assert.equal(JSON.stringify(session), before, 'rendering never mutates authoritative state');
    });

    it('keeps research risks and pending decisions open while folding supporting findings', async () => {
        const session = buildScenario('research', NOW);
        session.research.questions[0].status = 'blocked';
        const root = await render(session, 'research');
        assert.equal(folded(root, 'research-summary'), false);
        assert.equal(folded(root, 'research-recommendation'), false);
        assert.equal(folded(root, 'risks'), false);
        assert.equal(folded(root, 'questions'), false);
        const waiting = session.decisions.filter((decision) => decision.phase === 'research' && decision.status === 'needs-input');
        assert.ok(waiting.length);
        for (const decision of waiting) assert.equal(folded(root, decision.anchor.rowId), false);
        const supporting = session.research.findings.find((finding) => !waiting.some((decision) => decision.anchor.rowId === finding.id));
        assert.ok(supporting);
        assert.equal(folded(root, supporting.id), true);
    });

    it('keeps uncovered requirements and material critique findings expanded', async () => {
        const session = buildScenario('plan', NOW);
        session.plan.requirements.push({ id: 'FR-999', text: 'Uncovered requirement' });
        const root = await render(session, 'plan');
        assert.equal(folded(root, 'plan-summary'), false);
        assert.equal(folded(root, 'requirements'), false);
        assert.equal(folded(root, 'critique'), false);
        assert.equal(folded(root, 'change-map'), true);
    });

    it('leaves implementation validation and recorded changes exposed', async () => {
        const session = buildScenario('implement', NOW);
        session.implementation.validation.push({ check: 'Example failure', status: 'failed', scope: 'example', summary: 'Must stay visible' });
        const root = await render(session, 'implement');
        assert.equal(folded(root, 'validation'), false);
        assert.equal(folded(root, 'changes'), false);
        assert.match(rowById(root, 'validation').textContent, /Must stay visible/);
    });

    it('distinguishes open review findings from resolved history', async () => {
        const session = buildScenario('review', NOW);
        assert.ok(session.review.findings.length >= 2);
        session.review.findings[0].decision = 'accepted';
        session.review.findings[1].decision = 'resolved';
        const root = await render(session, 'review');
        assert.equal(folded(root, session.review.findings[0].id), false);
        assert.equal(folded(root, session.review.findings[1].id), true);
        assert.equal(folded(root, 'history'), true);
        assert.equal(folded(root, 'review-validation'), false);
    });

    it('never folds required follow-ups but makes optional-only work expandable', async () => {
        const session = buildScenario('followup', NOW);
        assert.ok(session.followUps.items.length);
        session.followUps.items[0].required = true;
        assert.equal(folded(await render(session, 'followup'), 'followups'), false);
        for (const item of session.followUps.items) item.required = false;
        const optional = await render(session, 'followup');
        assert.equal(folded(optional, 'followups'), true);
        assert.match(rowById(optional, 'followups').textContent, /optional/);
        assert.equal(folded(optional, 'session-loops'), true);
    });
});
