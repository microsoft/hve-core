// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { assembleSession } from '../lib/source/assemble.mjs';
import { parsePlan, parseResearch, parseState } from '../lib/source/parse.mjs';
import { installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { FIXTURE_NOW, PATHS, PLAN, RESEARCH, ROOT_STATE, rootSession } from './helpers/rpi-fixture.mjs';

const html = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).map(serialize).join('');
const textOf = (markup) => markup.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ');

let restore;
let planView;
let researchView;
let makeContext;
before(async () => {
    restore = installFakeDom();
    planView = await import('../ui/view-plan.mjs');
    researchView = await import('../ui/view-research.mjs');
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

    const TAGGED_BEFORE = ['flowchart LR', '    accTitle: Before: tiles come from the server', '    accDescr: The map fetches tiles.', '    subgraph app["`<code>src/map/</code>`"]', '        map["`**Map view**', '        changed · P01`"]', '        live["`**Live fetch**', '        removed · P02`"]', '    end', '    map --> live', '    class map changed', '    class live removed'].join('\n');
    const TAGGED_AFTER = ['flowchart LR', '    accTitle: After: tiles come from a local store', '    accDescr: The map reads a local store.', '    subgraph app["`<code>src/map/</code>`"]', '        map["`**Map view**', '        changed · P01`"]', '        store["`**Tile store**', '        new · P01, P02`"]', '    end', '    map --> store', '    class store new', '    class map changed'].join('\n');

    it('captions each diagram with its own title and highlights a phase in Before when the map has tags', () => {
        const { session } = rootSession();
        session.plan.diagram = { before: TAGGED_BEFORE, after: TAGGED_AFTER, phaseNodes: { P01: ['map', 'store'], P02: ['store', 'live'] }, tagged: true };
        const markup = (diagramView, diagramPhase = null) => html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView, diagramPhase })));
        const before = markup('before', 'P02');
        assert.match(before, /<figcaption>Before: tiles come from the server, P02 highlighted<\/figcaption>/);
        assert.match(before, /id="map-phase-P02" value="P02" checked=""/);
        assert.match(before, /class="diagram-node is-removed is-highlight"/);
        assert.match(textOf(before), /Thick border: changed\. Dotted border: removed\. Filled: the highlighted phase\./);
        assert.doesNotMatch(before, /how the app saves today/);
        const after = markup('after');
        assert.match(after, /<figcaption>After: tiles come from a local store<\/figcaption>/);
        assert.match(textOf(after), /Dashed border: new\. Thick border: changed\. Filled: the highlighted phase\./);
    });

    it('lets you select each part a phase changes, in Before and in After, and says so in the legend', () => {
        const { session } = rootSession();
        session.plan.diagram = { before: TAGGED_BEFORE, after: TAGGED_AFTER, phaseNodes: { P01: ['map', 'store'], P02: ['store', 'live'] }, tagged: true };
        const markup = (diagramView) => html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView })));
        const parts = (out) => [...out.matchAll(/data-preview="(part:[^"]+)"/g)].map((match) => match[1]);
        const after = markup('after');
        assert.match(after, /<svg [^>]*role="group"/);
        assert.deepEqual(parts(after), ['part:after:map', 'part:after:store']);
        assert.match(textOf(after), /Select a changed part to list its tasks\./);
        assert.deepEqual(parts(markup('before')), ['part:before:map', 'part:before:live']);
    });

    it('draws only After, with no Before switch, for a plan without a Before, and shows the plan\'s walk-through', () => {
        const { session } = rootSession();
        session.plan.diagram = { before: null, after: TAGGED_AFTER, walkthrough: 'The map reads tiles from the **local store** (P01).', phaseNodes: { P01: ['map', 'store'] }, tagged: true };
        const alone = html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView: 'before' })));
        assert.doesNotMatch(alone, /name="map-view"/);
        assert.match(alone, /<figcaption>After: tiles come from a local store<\/figcaption>/);
        assert.match(alone, /class="map-walkthrough prose"/);
        assert.match(textOf(alone), /The map reads tiles from the local store \(\s*P01\s*\)\./);
        session.plan.diagram = { ...session.plan.diagram, before: TAGGED_BEFORE, walkthrough: '' };
        const both = html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView: 'before' })));
        assert.match(both, /name="map-view"/);
        assert.doesNotMatch(both, /map-walkthrough/);
    });

    it('gives an older plan\'s Before a plain caption and no Highlight control', () => {
        const { session } = rootSession();
        assert.equal(session.plan.diagram.tagged, false);
        const before = html(planView.renderView(makeContext(session, 'plan', { ...makeContext(session, 'plan').ui, diagramView: 'before' })));
        assert.match(before, /<figcaption>Before<\/figcaption>/);
        assert.doesNotMatch(before, /name="map-phase"/);
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

describe('provided sources', () => {
    const MARKUP = '<img src=x onerror="alert(1)"> supplied by the user';
    /** A task whose Research and Plan were provided with this evidence, assembled as the canvas reads them. */
    const providedWith = (evidence) => assembleSession({
        id: 'rpi-trail-maps',
        state: parseState({ ...ROOT_STATE, active_phase: 'Implement', status: 'active', session_status: 'running', confirmed_decisions: [{ decision: 'Research disposition', status: 'provided', evidence }, { decision: 'Plan disposition', status: 'provided', evidence }] }),
        artifacts: { research: parseResearch(RESEARCH), plan: parsePlan(PLAN) },
        statePath: PATHS.rootState,
        now: FIXTURE_NOW,
    }).session;

    it('shows a provided plan\'s Source row first, with its evidence as text and no markup', () => {
        const session = providedWith(MARKUP);
        const markup = html(planView.renderView(makeContext(session, 'plan')));
        assert.ok(markup.indexOf('id="row-plan-source"') < markup.indexOf('id="row-plan-summary"'), 'the source comes before the summary');
        assert.match(textOf(markup), /The plan came from the user\. &lt;img src=x onerror=&quot;alert\(1\)&quot;&gt; supplied by the user/);
        assert.doesNotMatch(markup, /<img/, 'the evidence renders as text, never as an element');
        assert.deepEqual(planView.outline(makeContext(session, 'plan')).slice(0, 2).map((item) => item.label), ['Source', 'Summary']);
    });

    it('shows a provided research\'s Source row first, naming the session by its short ID', () => {
        const session = providedWith(`Copied from session 3fa85f64-5717-4562-b3fc-2c963f66afa6; path ${PATHS.research}; content hash 9f2c4e1a`);
        const markup = html(researchView.renderView(makeContext(session, 'research')));
        assert.ok(markup.indexOf('id="row-research-source"') < markup.indexOf('id="row-research-summary"'));
        assert.match(textOf(markup), /Research came from session 3fa85f64\. Copied from session 3fa85f64-5717-4562-b3fc-2c963f66afa6;/);
        assert.equal(researchView.outline(makeContext(session, 'research'))[0].label, 'Source');
    });

    it('has no Source row in a task whose phases were not provided', () => {
        const { session } = rootSession();
        assert.doesNotMatch(html(planView.renderView(makeContext(session, 'plan'))), /row-plan-source/);
        assert.doesNotMatch(html(researchView.renderView(makeContext(session, 'research'))), /row-research-source/);
        assert.ok(!planView.outline(makeContext(session, 'plan')).some((item) => item.id === 'plan-source'));
    });
});
