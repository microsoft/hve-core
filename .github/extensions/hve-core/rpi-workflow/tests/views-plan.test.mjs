// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { rootSession } from './helpers/rpi-fixture.mjs';

const html = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).map(serialize).join('');
const textOf = (markup) => markup.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ');

let restore;
let planView;
let makeContext;
before(async () => {
    restore = installFakeDom();
    planView = await import('../ui/view-plan.mjs');
    ({ makeContext } = await import('./helpers/render-views.mjs'));
});
after(() => restore());

/** The fixture session with its critique replaced, as the canvas assembles it. */
function withCritique(critique) {
    const { session } = rootSession();
    session.plan.critique = { ...session.plan.critique, ...critique };
    return session;
}

const LENSES = [{ lens: 'Coverage', status: 'complete' }, { lens: 'Evidence', status: 'in progress' }, { lens: 'Risk', status: 'queued' }];

describe('plan critique progress', () => {
    it('shows a running critique with its lens progress and findings so far, and no verdict', () => {
        const session = withCritique({ status: 'started', run: 'running', verdict: null, lenses: LENSES });
        const text = textOf(html(planView.renderView(makeContext(session, 'plan'))));
        assert.match(text, /Critique running/);
        assert.match(text, /Assessing the Evidence lens, 2 of 3; 2 findings so far\./);
        assert.match(text, /Coverage .*Evidence .*Risk/);
        assert.doesNotMatch(text, /Not recorded|Verdict:/);
        assert.match(html(planView.renderView(makeContext(session, 'plan'))), /aria-label="1 of 3 critique lenses done"/);
        assert.deepEqual(planView.lensProgress(session.plan.critique), { done: 1, total: 3, current: LENSES[1] });
    });

    it('says a critique stopped before it finished when its session no longer runs', () => {
        const session = withCritique({ status: 'started', run: 'stopped', verdict: null, lenses: LENSES, findings: [] });
        const text = textOf(html(planView.renderView(makeContext(session, 'plan'))));
        assert.match(text, /Critique stopped/);
        assert.match(text, /The critique stopped before it finished, after 1 of 3 lenses; 0 findings so far\./);
        assert.doesNotMatch(text, /No findings yet/);
    });

    it('shows how many findings the revision has addressed', () => {
        const session = withCritique({ run: null, verdict: 'Revise', lenses: [] });
        session.plan.critique.findings[1].disposition = 'open';
        const markup = html(planView.renderView(makeContext(session, 'plan')));
        assert.match(textOf(markup), /1 of 2 findings addressed in the plan\./);
        assert.match(markup, /<progress[^>]*aria-label="1 of 2 findings addressed in the plan\."/);
        assert.deepEqual(planView.addressedFindings(session.plan.critique), { done: 1, total: 2 });
        session.plan.critique.findings[1].disposition = 'accepted with risk';
        assert.doesNotMatch(html(planView.renderView(makeContext(session, 'plan'))), /<progress[^>]*findings addressed/, 'no bar once every finding is addressed');
    });
});

describe('the change map', () => {
    it('reads a phase chosen in another plan as none', () => {
        const { session } = rootSession();
        const phase = session.plan.phases[0].id;
        const markup = (diagramPhase) => html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView: 'after', diagramPhase })));
        assert.match(markup(phase), new RegExp(`id="map-phase-${phase}" value="${phase}" checked=""`));
        const foreign = markup('P99');
        assert.match(foreign, /id="map-phase-none" value="none" checked=""/);
        assert.doesNotMatch(foreign, /P99 highlighted/);
    });
});

describe('updated marks', () => {
    it('marks plan text the agent changed in the last ten minutes, after the first read', () => {
        const { session } = rootSession();
        const now = Date.parse(session.updatedAt);
        const task = session.plan.phases[0].tasks[0];
        const ctx = makeContext(session, 'plan');
        assert.doesNotMatch(textOf(html(planView.renderView(ctx))), /Updated/, 'nothing is marked on the first read');
        session.sections['plan-summary'] = { ...session.sections['plan-summary'], revision: 2, updatedAt: new Date(now - 60 * 1000).toISOString() };
        session.sections[task.sectionId] = { ...session.sections[task.sectionId], revision: 3, updatedAt: new Date(now - 2 * 60 * 1000).toISOString() };
        session.sections['plan-unknowns'] = { ...session.sections['plan-unknowns'], revision: 2, updatedAt: new Date(now - 11 * 60 * 1000).toISOString() };
        const marks = html(planView.renderView(makeContext(session, 'plan'))).match(/updated-mark/g) ?? [];
        assert.equal(marks.length, 2, 'the summary and the task, but not text changed more than ten minutes ago');
    });
});
