// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFeedback, markChecklist, recordActivity, suggestEdit, transitionFeedback, upsertDecision, validateSession } from '../lib/model.mjs';
import {
    alignmentOf,
    assembleSession,
    confidenceOf,
    critiqueDispositionOf,
    evidenceStateOf,
    findingDecisionOf,
    lineageStatusOf,
    mergeImport,
    readinessOf,
    routeOf,
    validationOf,
} from '../lib/source/assemble.mjs';
import { parseChanges, parseCritique, parsePlan, parseResearch, parseReview, parseState } from '../lib/source/parse.mjs';
import { installFakeDom } from './helpers/fake-dom.mjs';
import { CHANGES, CHILD_CHANGES, CHILD_PLAN, CHILD_STATE, childSession, CRITIQUE, PATHS, PLAN, RESEARCH, REVIEW, ROOT_STATE, rootSession } from './helpers/rpi-fixture.mjs';

const NOW = '2026-01-15T12:00:00.000Z';

describe('vocabulary', () => {
    it('maps artifact words into the canvas vocabulary', () => {
        assert.equal(evidenceStateOf('Evidence-backed finding for the mechanism; partially supported claim for the rules'), 'evidence-backed');
        assert.equal(evidenceStateOf('Partially supported claim'), 'partially-supported');
        assert.equal(evidenceStateOf('Unverified hypothesis'), 'hypothesis');
        assert.equal(evidenceStateOf('Weakened/disproved claim'), 'weakened');
        assert.equal(evidenceStateOf('nothing recognizable'), null);
        assert.equal(confidenceOf('Medium-high; the merge needs tests'), 'medium-high');
        assert.equal(confidenceOf('See C4'), null);
        assert.deepEqual(['Passed', 'Passed with notes', 'FAILED', 'Skipped', 'Unavailable', 'Not run', 'Mostly fine'].map(validationOf), ['passed', 'passed', 'failed', 'skipped', 'unavailable', 'unavailable', null]);
        assert.deepEqual(['accepted', 'Resolved', 'child loop selected', 'Defects found'].map(findingDecisionOf), ['accepted', 'resolved', null, null]);
        assert.deepEqual(['rpi-implement', 'rpi-plan', 'Follow-up item', 'none', 'unclear'].map(routeOf), ['rpi-implement', 'rpi-plan', 'follow-up', 'none', 'none']);
        assert.deepEqual(['resolved', 'accepted with risk', 'superseded', 'pending'].map(critiqueDispositionOf), ['resolved', 'accepted with risk', 'superseded', 'open']);
        assert.equal(alignmentOf('pending-decision'), 'pending-decision');
        assert.deepEqual(['Complete and Ready', 'Ready: all set', 'Not ready: D2', 'Blocked'].map(readinessOf), ['ready', 'ready', 'not-ready', 'not-ready']);
        assert.deepEqual([{ status: 'completed', sessionStatus: 'running' }, { status: 'active', sessionStatus: 'running' }, { status: 'active', sessionStatus: 'stopped' }].map(lineageStatusOf), ['completed', 'running', 'stopped']);
    });
});

describe('assembled document', () => {
    it('builds a valid document with real sections, statuses, and sources', () => {
        const { session, warnings } = rootSession();
        assert.doesNotThrow(() => validateSession(session));
        assert.equal(session.scenario, undefined);
        assert.deepEqual(session.task, { id: 'trail-maps', title: 'Offline trail maps', repository: 'contoso/trails', branch: 'feat/offline', parent: null });
        assert.deepEqual(Object.values(session.phases).map((phase) => phase.status), ['done', 'done', 'done', 'done', 'active']);
        assert.equal(session.phases.plan.updatedAt, '2026-01-15T10:00:00.000Z');
        assert.equal(session.phases.followup.artifact, PATHS.rootState);
        assert.equal(session.source.statePath, PATHS.rootState);
        assert.ok(Array.isArray(warnings));
        for (const key of ['research-summary', 'research-unknowns', 'research-recommendation', 'finding-f1', 'finding-f2', 'plan-summary', 'plan-unknowns', 'task-p01-t01', 'changes-summary', 'review-summary', 'followup-summary']) {
            assert.ok(session.sections[key]?.markdown, `section ${key}`);
            assert.match(session.sections[key].sourceHash, /^[0-9a-f]{24}$/);
        }
    });

    it('maps research, plan, implementation, review, and follow-ups', () => {
        const { session } = rootSession();
        assert.deepEqual(session.research.findings.map((f) => [f.id, f.state, f.confidence]), [['F1', 'evidence-backed', 'high'], ['F2', 'partially-supported', 'medium']]);
        assert.deepEqual(session.research.questions.map((q) => [q.id, q.status, q.findings]), [['Q1', 'answered', ['F1']], ['Q2', 'answered', ['F2']], ['Q3', 'open', []]]);
        assert.equal(session.research.evidence.find((e) => e.id === 'W1').url, 'https://developer.mozilla.org/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria');
        assert.deepEqual(session.research.alternatives.map((a) => a.disposition), ['selected', 'rejected']);
        assert.equal(session.research.readiness.status, 'ready');
        const tasks = session.plan.phases.flatMap((p) => p.tasks);
        assert.deepEqual(tasks.map((t) => [t.id, t.status]), [['P01-T01', 'done'], ['P02-T01', 'done'], ['P02-T02', 'todo']]);
        assert.deepEqual(tasks[0].requirements, ['FR-001', 'NFR-001']);
        assert.deepEqual(tasks[1].dependencies, ['P01-T01']);
        assert.deepEqual(session.plan.phases.map((p) => p.status), ['done', 'in-progress']);
        assert.deepEqual(session.plan.diagram.phaseNodes, { P01: ['store'], P02: [] });
        assert.deepEqual(session.plan.critique.findings.map((f) => [f.id, f.disposition]), [['PC-001', 'resolved'], ['PC-002', 'accepted with risk']]);
        assert.equal(session.plan.critique.verdict, 'Revise');
        assert.deepEqual(session.implementation.changes.map((c) => [c.id, c.taskId]), [['CH-001', 'P01-T01'], ['CH-002', 'P02-T01']]);
        assert.deepEqual(session.implementation.changes[1].related, ['RV-002']);
        assert.deepEqual(session.implementation.validation.map((v) => v.status), ['passed', 'passed', 'unavailable']);
        assert.deepEqual(session.implementation.discoveries.map((d) => [d.id, d.kind, d.taskId]), [['DS-001', 'plan-change', null], ['DS-002', 'plan-change', 'P02-T01'], ['DS-003', 'follow-up', null]]);
        assert.equal(session.implementation.current, null, 'a completed task has no current work');
        assert.deepEqual(session.review.findings.map((f) => [f.id, f.decision, f.route]), [['RV-001', 'resolved', 'rpi-implement'], ['RV-002', 'resolved', 'rpi-implement']]);
        assert.deepEqual(session.followUps.items.map((i) => [i.id, i.required, i.status]), [['FU-1', true, 'in-progress'], ['FU-2', false, 'proposed']]);
        assert.equal(session.followUps.lineage.length, 2);
        assert.ok(session.records.plan.some((record) => record.heading === 'Risks and Open Questions'));
    });

    it('keeps decision IDs distinct per artifact and shows their own IDs', () => {
        const { session } = rootSession();
        assert.deepEqual(session.decisions.map((d) => [d.id, d.ref, d.status, d.owner]), [
            ['D1', 'D1', 'decided', 'agent'],
            ['D2', 'D2', 'needs-input', 'user'],
            ['plan.D1', 'D1', 'decided', 'agent'],
            ['plan.D2', 'D2', 'decided', 'agent'],
        ]);
        const needs = session.decisions.find((d) => d.id === 'D2');
        assert.deepEqual([needs.options, needs.question], [[], 'Pick the park or the coast']);
        assert.deepEqual(session.decisions[0].evidence, ['C1'], 'evidence chips keep only known evidence');
        assert.deepEqual(session.decisions[2].anchor, { phase: 'plan', rowId: 'plan-decisions' });
    });

    it('marks reused research and a skipped review in a child task', () => {
        const { session } = childSession();
        assert.deepEqual(Object.values(session.phases).map((phase) => phase.status), ['skipped', 'done', 'done', 'skipped', 'done']);
        assert.match(session.sections['research-summary'].markdown, /reused existing evidence/);
        assert.equal(session.task.parent, 'trail-maps');
        assert.equal(session.review.findings.length, 0);
        assert.equal(session.decisions[0].id, 'plan.D1');
    });

    it('marks the current task while implementation runs', () => {
        const state = parseState({ ...ROOT_STATE, active_phase: 'Implement', status: 'active', session_status: 'running' });
        const { session } = assembleSession({ id: 'x', state, artifacts: { plan: parsePlan(PLAN) }, statePath: PATHS.rootState, now: NOW });
        assert.deepEqual(session.implementation.current, { taskId: 'P02-T02', startedAt: null });
        assert.equal(session.plan.phases[1].tasks[1].status, 'in-progress');
        assert.deepEqual(Object.values(session.phases).map((phase) => phase.status), ['done', 'done', 'active', 'upcoming', 'upcoming']);
    });
});

describe('merging a re-import', () => {
    const LATER = '2026-01-15T13:00:00.000Z';
    const withResearch = (research) => assembleSession({
        id: 'rpi-trail-maps',
        state: parseState(ROOT_STATE),
        artifacts: { research: parseResearch(research), plan: parsePlan(PLAN), critique: parseCritique(CRITIQUE), changes: parseChanges(CHANGES), review: parseReview(REVIEW) },
        statePath: PATHS.rootState,
        now: LATER,
    }).session;

    it('takes the first import as is and writes nothing when nothing changed', () => {
        const { session } = rootSession();
        assert.equal(mergeImport(null, session, LATER), session);
        assert.equal(mergeImport(session, rootSession().session, LATER), session, 'an identical import returns the stored object');
    });

    it('keeps what the person added in the canvas', () => {
        let stored = rootSession().session;
        stored = createFeedback(stored, { kind: 'comment', text: 'Mine', target: { id: 'F1', type: 'finding', phase: 'research' } }, NOW).session;
        stored = markChecklist(stored, { phase: 'research', itemId: 'R1', verdict: 'needs-work', note: 'Say which region first.' }, NOW).session;
        stored = recordActivity(stored, { text: 'Reading the plan' }, NOW).session;
        stored = upsertDecision(stored, { owner: 'user', phase: 'plan', title: 'Ship the coast first?', question: 'Which region?', options: [{ label: 'Coast' }, { label: 'Park' }] }, NOW).session;
        const asked = stored.decisions.at(-1);
        assert.equal(asked.id, 'D3', 'canvas decisions never collide with imported IDs');
        stored = { ...stored, scenario: { userChanges: 2 } };
        const merged = mergeImport(stored, withResearch(RESEARCH.replace('Tile licenses limit', 'Vendor licenses limit')), LATER);
        assert.notEqual(merged, stored);
        assert.equal(merged.revision, stored.revision + 1);
        assert.deepEqual(merged.feedback, stored.feedback);
        const r1 = merged.checklists.research.find((item) => item.id === 'R1');
        assert.equal(r1.verdict, 'needs-work');
        assert.equal(r1.note, 'Say which region first.');
        assert.equal(r1.label, 'The bottom line is clear');
        assert.equal(merged.implementation.activity.length, 1);
        assert.ok(merged.decisions.some((decision) => decision.id === 'D3'));
        assert.deepEqual(merged.scenario, { userChanges: 2 });
        assert.match(merged.sections['research-unknowns'].markdown, /Vendor licenses/);
    });

    it('carries verdicts saved before verdicts existed onto the current checklist labels', () => {
        const fresh = rootSession().session;
        const stored = { ...fresh, checklists: { ...fresh.checklists, research: fresh.checklists.research.map((item) => (item.id === 'R2' ? { id: 'R2', label: 'Old wording', checked: true } : item)) } };
        const merged = mergeImport(stored, withResearch(RESEARCH.replace('Tile licenses limit', 'Vendor licenses limit')), LATER);
        assert.deepEqual(merged.checklists.research.find((item) => item.id === 'R2'), { id: 'R2', label: "Each finding's evidence is convincing", verdict: 'ok' });
    });

    it('never changes section text for a suggestion, and lets the file replace text edited before suggestions', () => {
        let stored = rootSession().session;
        const original = stored.sections['finding-f1'];
        stored = suggestEdit(stored, { sectionId: 'finding-f1', markdown: 'My clearer wording.', baseRevision: 1 }, NOW).session;
        assert.deepEqual(stored.sections['finding-f1'], original, 'a suggestion leaves the section as the file has it');
        const legacy = { ...stored, sections: { ...stored.sections, 'finding-f1': { ...original, markdown: 'Text typed into the old editor.', revision: 2, editedBy: 'user' } } };
        const restored = mergeImport(legacy, withResearch(RESEARCH.replace('Tile licenses limit', 'Vendor licenses limit')), LATER);
        assert.equal(restored.sections['finding-f1'].markdown, original.markdown, 'the file text shows again');
        assert.equal(restored.sections['finding-f1'].editedBy, 'agent');
        assert.ok(restored.sections['finding-f1'].revision > 2, 'an open editor sees a conflict');
        assert.deepEqual(restored.feedback, stored.feedback, 'the suggestion stays pending');
    });

    it('keeps an answer to an imported decision while its content is unchanged', () => {
        const fresh = rootSession().session;
        const stored = { ...fresh, decisions: fresh.decisions.map((decision) => (decision.id === 'D2' ? { ...decision, status: 'answered', feedbackId: 'FB-001' } : decision)) };
        const same = mergeImport(stored, withResearch(RESEARCH.replace('Tile licenses limit', 'Vendor licenses limit')), LATER);
        assert.equal(same.decisions.find((decision) => decision.id === 'D2').status, 'answered');
        const settled = mergeImport(stored, withResearch(RESEARCH.replace('| D2 | Which region ships first? | input requested | user |', '| D2 | Which region ships first? | confirmed | user |')), LATER);
        assert.equal(settled.decisions.find((decision) => decision.id === 'D2').status, 'resolved', 'a decision the agent settled in the file replaces the canvas state');
    });
});

describe('rendering', () => {
    let restore;
    let renderAll;
    before(async () => {
        restore = installFakeDom();
        ({ renderAll } = await import('./helpers/render-views.mjs'));
    });
    after(() => restore());

    it('renders every view and the steering panel for imported documents', async () => {
        for (const build of [rootSession, childSession]) {
            const { session } = build();
            const rendered = await renderAll(session);
            for (const phase of Object.keys(rendered)) {
                assert.ok(rendered[phase].html.length > 0, `${session.id} ${phase} rendered`);
                assert.ok(Array.isArray(rendered[phase].outline));
            }
            if (session.id === 'rpi-trail-maps') {
                assert.match(rendered.review.html, /A full disk leaves a half region/);
                assert.match(rendered.plan.html, /Save tiles by region/);
                assert.match(rendered.implement.html, /Regions download into the tile store and resume/);
            }
        }
    });
});
