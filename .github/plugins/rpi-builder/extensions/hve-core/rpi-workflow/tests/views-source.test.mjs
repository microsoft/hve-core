// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createActionHandlers } from '../lib/actions.mjs';
import { composeDelivery, createFeedback, transitionFeedback, upsertDecision } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { createStore } from '../lib/store.mjs';
import { decisionAlias } from '../ui/dom.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { childSession, FIXTURE_NOW as NOW, minimalSession, rootSession } from './helpers/rpi-fixture.mjs';

const decisionOf = (session, id) => session.decisions.find((decision) => decision.id === id);
const errorCode = (fn) => {
    try {
        fn();
    } catch (error) {
        return error.code;
    }
    return assert.fail('expected an error');
};
const byKey = (node, key) => elements(node).find((element) => element.getAttribute('data-key') === key);
const textOf = (html) => html.replace(/<[^>]*>/g, ' ');
const attributesOf = (html) => [...html.matchAll(/="([^"]*)"/g)].map((match) => match[1]);
const MISSING = /\b(?:undefined|null|NaN)\b|\[object Object\]/;

describe('answers and overrides in the user\'s words', () => {
    it('answers a decision that lists no options with text, and withdrawing reopens it', () => {
        let { session } = rootSession();
        assert.deepEqual(decisionOf(session, 'D2').options, []);
        assert.equal(errorCode(() => createFeedback(session, { kind: 'answer', target: { id: 'D2' } }, NOW)), 'invalid_input');
        assert.equal(errorCode(() => createFeedback(session, { kind: 'answer', target: { id: 'D2' }, text: '   ' }, NOW)), 'invalid_input');
        const answered = createFeedback(session, { kind: 'answer', target: { id: 'D2' }, optionId: null, text: 'Ship the coast first.' }, NOW);
        session = answered.session;
        assert.equal(decisionOf(session, 'D2').status, 'answered');
        assert.equal(decisionOf(session, 'D2').chosen, undefined);
        assert.equal(answered.result.optionId, undefined);
        assert.match(composeDelivery(session, [answered.result.id], NOW).prompt, /Answer to D2 [^\n]*\n {3}File: \.copilot-tracking\/research\/[^\n]+\n {3}Answer: Ship the coast first\./);
        const withdrawn = transitionFeedback(session, answered.result.id, 'dismissed', {}, NOW).session;
        assert.equal(decisionOf(withdrawn, 'D2').status, 'needs-input');
    });

    it('takes an answer in the user\'s words even when the decision lists options, but not an empty one', () => {
        const { session: base } = rootSession();
        const { session, result } = upsertDecision(base, { owner: 'user', title: 'Pick a basemap', question: 'Which basemap?', options: [{ label: 'Terrain' }, { label: 'Satellite' }] }, NOW);
        assert.equal(errorCode(() => createFeedback(session, { kind: 'answer', target: { id: result.id } }, NOW)), 'invalid_input', 'neither an option nor words');
        const own = createFeedback(session, { kind: 'answer', target: { id: result.id }, text: 'A hybrid of both' }, NOW);
        assert.deepEqual([own.result.optionId, own.result.text, decisionOf(own.session, result.id).status, decisionOf(own.session, result.id).chosen], [undefined, 'A hybrid of both', 'answered', undefined]);
    });

    it('overrides an agent decision without alternatives, restores it on withdrawal, and resolves it when applied', () => {
        let { session } = rootSession();
        assert.equal(decisionOf(session, 'plan.D2').options.length, 1);
        assert.equal(errorCode(() => createFeedback(session, { kind: 'override', target: { id: 'plan.D2' } }, NOW)), 'invalid_input');
        const override = createFeedback(session, { kind: 'override', target: { id: 'plan.D2' }, text: 'Announce every 25 percent instead.' }, NOW);
        session = override.session;
        assert.equal(decisionOf(session, 'plan.D2').status, 'override-pending');
        assert.equal(decisionOf(session, 'plan.D2').chosen, undefined);
        assert.equal(override.result.previousChosen, 'a');
        assert.match(composeDelivery(session, [override.result.id], NOW).prompt, /Override of plan\.D2 [^\n]*\n {3}File: \.copilot-tracking\/plans\/[^\n]+\n {3}Do instead: Announce every 25 percent instead\./);

        const withdrawn = transitionFeedback(session, override.result.id, 'dismissed', {}, NOW).session;
        assert.equal(decisionOf(withdrawn, 'plan.D2').status, 'decided');
        assert.equal(decisionOf(withdrawn, 'plan.D2').chosen, 'a');

        let applied = transitionFeedback(session, override.result.id, 'sent', { by: 'agent' }, NOW).session;
        applied = transitionFeedback(applied, override.result.id, 'interpreted', { by: 'agent', interpretation: { text: 'Announce every 25 percent.' } }, NOW).session;
        applied = transitionFeedback(applied, override.result.id, 'applied', {}, NOW).session;
        assert.equal(decisionOf(applied, 'plan.D2').status, 'resolved');
    });

    it('hands the text to the agent through take_feedback', async () => {
        const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-free-text-'));
        const store = createStore({ root: dir });
        try {
            const { session } = rootSession();
            await store.create(session);
            await store.update(session.id, (current) => createFeedback(current, { kind: 'override', target: { id: 'plan.D2' }, text: 'Every 25 percent.' }, NOW), { by: 'user' });
            const server = { url: 'http://127.0.0.1:1/', clientInfo: null, streamClients: 1, focus: () => ({ delivered: true }), notifyReload: () => {} };
            const handlers = createActionHandlers({ getInstance: () => ({ server, sessionId: session.id, source: { kind: 'rpi' } }), store, makeError: (code, message) => Object.assign(new Error(message), { code }) });
            const taken = await handlers.take_feedback({ instanceId: 'i1', input: {} });
            assert.equal(taken.items.length, 1);
            assert.equal(taken.items[0].text, 'Every 25 percent.');
            assert.equal(taken.items[0].optionId, null);
            assert.equal(taken.items[0].target.id, 'plan.D2');
        } finally {
            store.close();
            await fs.rm(dir, { recursive: true, force: true });
        }
    });
});

describe('phase-first decision IDs', () => {
    it('names the viewed phase\'s decision first, then the exact ID', () => {
        const { session } = rootSession();
        assert.equal(decisionAlias(session, 'D1', 'plan'), 'plan.D1');
        assert.equal(decisionAlias(session, 'D1', 'research'), 'D1');
        assert.equal(decisionAlias(session, 'D1', 'implement'), 'D1');
        assert.equal(decisionAlias(session, 'P01', 'plan'), 'P01');
        assert.equal(decisionAlias(session, 'D9', 'plan'), 'D9');
    });
});

describe('views of imported sessions', () => {
    let restore;
    let components;
    let renderAll;
    let makeContext;
    before(async () => {
        restore = installFakeDom();
        components = await import('../ui/components.mjs');
        ({ renderAll, makeContext } = await import('./helpers/render-views.mjs'));
    });
    after(() => restore());

    it('renders an earlier document read-only: no row actions, notes, answers, or task buttons', async () => {
        let { session } = rootSession();
        session = createFeedback(session, { kind: 'comment', text: 'A note on the newest summary', target: { id: 'research-summary' } }, '2026-01-15T12:00:00.000Z').session;
        const research = await import('../ui/view-research.mjs');
        const plan = await import('../ui/view-plan.mjs');
        const open = makeContext(session, 'research');
        const openHtml = research.renderView(open).map(serialize).join('');
        assert.match(openHtml, /data-key="comment-research-summary"/, 'the newest offers comments');
        assert.match(openHtml, /A note on the newest summary/);
        assert.match(openHtml, /Ask for more research/, 'the current research offers more research');
        const readOnly = { ...makeContext(session, 'research'), readOnly: true };
        const html = research.renderView(readOnly).map(serialize).join('');
        assert.doesNotMatch(html, /data-key="(?:comment|edit-section|research)-/, 'no row actions');
        assert.doesNotMatch(html, /A note on the newest summary/, 'notes for the newest do not show on an earlier document');
        assert.doesNotMatch(html, /Ask for more research/, 'no lanes card on an earlier document');
        assert.match(html, /Store map tiles in IndexedDB/, 'the content still shows');
        const card = serialize(components.decisionCard(readOnly, decisionOf(session, 'D2')));
        assert.doesNotMatch(card, /<textarea|data-key="submit-D2"|Override/, 'a decision cannot be answered or overridden there');
        assert.equal(components.rowActions(readOnly, { sectionId: 'research-summary', rowId: 'research-summary' }).length, 0);
        const planUi = makeContext(session, 'plan').ui;
        planUi.expanded = new Set(session.plan.phases[0].tasks.map((task) => task.id));
        const planHtml = plan.renderView({ ...makeContext(session, 'plan', planUi), readOnly: true }).map(serialize).join('');
        assert.doesNotMatch(planHtml, /Suggest an edit|Move up|Move down/, 'task panels offer no changes');
        assert.match(plan.renderView(makeContext(session, 'plan', planUi)).map(serialize).join(''), /Move up/, 'the newest plan still does');
    });

    it('asks for an answer in the user\'s words when a decision lists no options', () => {
        const { session } = rootSession();
        const ctx = makeContext(session, 'research');
        const card = components.decisionCard(ctx, decisionOf(session, 'D2'));
        const html = serialize(card);
        assert.match(html, /<label[^>]*>Your answer<\/label>/);
        assert.doesNotMatch(html, /type="radio"/);
        assert.notEqual(byKey(card, 'submit-D2').getAttribute('disabled'), null);
        ctx.ui.decisionDrafts.set('D2', { optionId: null, note: 'Coast first' });
        const ready = components.decisionCard(ctx, decisionOf(session, 'D2'));
        assert.equal(byKey(ready, 'submit-D2').getAttribute('disabled'), null);
        assert.equal(byKey(ready, 'submit-D2').getAttribute('data-needs-text'), 'true');
    });

    it('offers an override in the user\'s words when there are no alternatives, labeled with the artifact ID', () => {
        const { session } = rootSession();
        const ctx = makeContext(session, 'plan');
        const plain = serialize(components.decisionCard(ctx, decisionOf(session, 'plan.D2')));
        assert.match(plain, /<span class="id-chip">D2<\/span>/);
        assert.doesNotMatch(plain, /plan\.D2<\/span>/);
        ctx.ui.overrides.add('plan.D2');
        const html = serialize(components.decisionCard(ctx, decisionOf(session, 'plan.D2')));
        assert.match(html, /What should the agent do instead\?/);
        assert.doesNotMatch(html, /type="radio"/);
    });

    it('keeps the agent\'s own choice on the card while an override waits', () => {
        const scenario = buildScenario('plan');
        const agent = scenario.decisions.find((decision) => decision.owner === 'agent' && decision.options.length > 1);
        const other = agent.options.find((option) => option.id !== agent.chosen);
        const before = agent.options.find((option) => option.id === agent.chosen);
        const { session } = createFeedback(scenario, { kind: 'override', target: { id: agent.id }, optionId: other.id }, NOW);
        const html = serialize(components.decisionCard(makeContext(session, agent.phase), decisionOf(session, agent.id)));
        const [agentVoice, userVoice] = html.split('Your override');
        assert.ok(agentVoice.includes(before.label), 'agent voice names the agent\'s choice');
        assert.ok(userVoice.includes(other.label), 'override names the user\'s choice');
    });

    it('lists imported decisions in Decisions rows and counts them in the steering panel', async () => {
        const { session } = rootSession();
        const rendered = await renderAll(session);
        assert.match(rendered.research.html, /id="row-research-decisions"/);
        assert.match(rendered.plan.html, /id="row-plan-decisions"/);
        assert.ok(rendered.plan.outline.some((item) => item.id === 'plan-decisions'));
        assert.match(rendered.research.steer, /Recorded decisions<span class="count">3<\/span>/);
        assert.match(rendered.research.steer, /3 decisions the agent recorded<\/span><span class="id-chip">D1/);
        assert.doesNotMatch(rendered.research.steer, /you made/, 'no count for decisions you have not made');
        assert.doesNotMatch(rendered.research.steer, /class="steer-card"/);
        assert.match(rendered.research.steer, /class="steer-link"[^>]*>.*?<span class="id-chip">D2<svg[^>]*><use href="#i-go-to"><\/use><\/svg><\/span> Which region ships first\?/);
        const answered = structuredClone(session);
        answered.decisions.find((decision) => decision.id === 'D2').status = 'resolved';
        assert.match((await renderAll(answered)).research.steer, /1 decision you made<\/span><span class="id-chip">D2/);
    });

    it('shows each phase\'s unmodeled sections in a record row', async () => {
        const { session } = rootSession();
        const rendered = await renderAll(session);
        for (const [phase, rowId] of [['plan', 'plan-record'], ['implement', 'implement-record'], ['review', 'review-record']]) {
            const records = session.records[phase];
            if (records.length) {
                assert.match(rendered[phase].html, new RegExp(`id="row-${rowId}"`), phase);
                for (const record of records) assert.ok(rendered[phase].html.includes(record.heading.replace(/&/g, '&amp;')), `${phase} ${record.heading}`);
            } else {
                assert.doesNotMatch(rendered[phase].html, new RegExp(`id="row-${rowId}"`), phase);
            }
        }
        for (const record of session.records.research) assert.ok(rendered.research.html.includes(record.heading.replace(/&/g, '&amp;')), record.heading);
    });

    it('lists the session\'s loops as a tree and offers Show for the other tasks', async () => {
        const rendered = await renderAll(childSession().session);
        assert.match(rendered.followup.html, /aria-label="Show Offline trail maps"/);
        assert.doesNotMatch(rendered.followup.html, /aria-label="Show Offline trail maps review fixes"/);
        assert.match(rendered.followup.html, /<li class="tree-task"><div class="tree-card">.*Offline trail maps<\/strong>.*<ol class="session-tree-level"><li class="tree-task is-shown">/s, 'the child nests under its parent and is marked as shown');
        assert.match(rendered.followup.html, /Its state files are in 2026-01-15\/trail-maps\./);
        const sample = await renderAll(buildScenario('followup'));
        assert.doesNotMatch(sample.followup.html, /aria-label="Show /);
    });

    it('never prints a missing value in any view, for full, child, and empty tasks', async () => {
        const sessions = [rootSession().session, childSession().session, minimalSession('Research').session, minimalSession('Follow-up').session];
        for (const session of sessions) {
            const rendered = await renderAll(session);
            for (const [phase, out] of Object.entries(rendered)) {
                for (const [part, html] of [['view', out.html], ['steering', out.steer]]) {
                    const label = `${session.id} ${phase} ${part}`;
                    assert.doesNotMatch(textOf(html), MISSING, label);
                    assert.doesNotMatch(textOf(html), /Not recorded/, label);
                    for (const value of attributesOf(html)) assert.doesNotMatch(value, MISSING, `${label} attribute ${value}`);
                }
                for (const item of out.outline) assert.doesNotMatch(`${item.label} ${item.count ?? ''}`, MISSING, `${session.id} ${phase} outline`);
            }
        }
    });
});
