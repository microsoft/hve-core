// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createFeedback, recordActivity, suggestEdit, upsertDecision, validateSession } from '../lib/model.mjs';
import {
    alignmentOf,
    assembleSession,
    bareUrl,
    confidenceOf,
    critiqueDispositionOf,
    evidenceStateOf,
    findingDecisionOf,
    lensStatusOf,
    lineageStatusOf,
    mergeImport,
    readinessOf,
    researchCitations,
    routeOf,
    validationOf,
} from '../lib/source/assemble.mjs';
import { parseChanges, parseCritique, parsePlan, parseResearch, parseReview, parseState } from '../lib/source/parse.mjs';
import { installFakeDom } from './helpers/fake-dom.mjs';
import { CHANGES, childSession, CRITIQUE, PATHS, PLAN, RESEARCH, REVIEW, ROOT_STATE, rootSession } from './helpers/rpi-fixture.mjs';

const NOW = '2026-01-15T12:00:00.000Z';

describe('research citations', () => {
    it('reads the findings and decisions each Requirements item cites after "research"', () => {
        assert.deepEqual(researchCitations('* FR-019, NFR-011\n* Research D10: each phase shows its documents.'), ['D10']);
        assert.deepEqual(researchCitations('* research F18, D19 (the trace)\n* Decision D5 stays in the plan'), ['F18', 'D19'], 'one item does not run into the next');
        assert.deepEqual(researchCitations('* Research D13 to D15, and research C31'), ['D13', 'D14', 'D15'], 'ranges expand and evidence IDs are not cited work');
        assert.deepEqual(researchCitations('* FR-001'), []);
        assert.deepEqual(researchCitations(undefined), []);
    });
});

describe('vocabulary', () => {
    it('maps artifact words into the canvas vocabulary', () => {
        assert.equal(evidenceStateOf('Evidence-backed finding for the mechanism; partially supported claim for the rules'), 'evidence-backed');
        assert.equal(evidenceStateOf('Partially supported claim'), 'partially-supported');
        assert.equal(evidenceStateOf('Unverified hypothesis'), 'hypothesis');
        assert.equal(evidenceStateOf('Weakened/disproved claim'), 'weakened');
        assert.equal(evidenceStateOf('nothing recognizable'), null);
        assert.equal(confidenceOf('Medium-high; the merge needs tests'), 'medium-high');
        assert.equal(confidenceOf('See C4'), null);
        assert.deepEqual(['see https://a.example/x; and more', 'https://a.example/wiki/Foo_(bar)).', 'https://a.example/p?q=1,', '(https://a.example/y)', 'no address'].map(bareUrl), ['https://a.example/x', 'https://a.example/wiki/Foo_(bar)', 'https://a.example/p?q=1', 'https://a.example/y', null]);
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
        assert.equal(session.research.evidence.find((e) => e.id === 'C2').claim, 'The `Cache` API has no **metadata**', 'claims keep their inline Markdown');
        assert.equal(session.research.evidence.find((e) => e.id === 'W1').source, '[Storage quotas](https://developer.mozilla.org/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)');
        assert.equal(session.research.evidence.find((e) => e.id === 'W2').url, 'https://example.com/terms/tiles', 'a bare address stops before trailing punctuation');
        assert.equal(session.research.risks[0].action, 'Call `navigator.storage.persist()`');
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
        assert.deepEqual(session.followUps.tree.tasks.map((t) => [t.id, t.depth, t.shown]), [['trail-maps', 0, true], ['trail-maps-fixes', 1, false]]);
        assert.equal(session.followUps.tree.name, 'Offline trail maps');
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

    it('shows each phase as its documents are when the agent moves back', () => {
        const artifacts = { research: parseResearch(RESEARCH), plan: parsePlan(PLAN), changes: parseChanges(CHANGES), review: parseReview(REVIEW) };
        const statuses = (activePhase, files) => {
            const state = parseState({ ...ROOT_STATE, active_phase: activePhase, status: 'active', session_status: 'running' });
            return Object.values(assembleSession({ id: 'x', state, artifacts: files, statePath: PATHS.rootState, now: NOW }).session.phases).map((phase) => phase.status);
        };
        assert.deepEqual(statuses('Plan', artifacts), ['done', 'active', 'done', 'done', 'done'], 'finished work stays done while the agent plans again');
        const unfinished = { ...artifacts, changes: { ...artifacts.changes, status: { ...artifacts.changes.status, status: 'In progress' } }, review: { ...artifacts.review, execution: 'started' } };
        assert.deepEqual(statuses('Research', unfinished), ['active', 'done', 'active', 'active', 'done'], 'unfinished documents read in progress');
        assert.deepEqual(statuses('Plan', { research: artifacts.research, plan: artifacts.plan }), ['done', 'active', 'upcoming', 'upcoming', 'upcoming'], 'a later phase with no document has not started');
    });
});

describe('a critique while it runs', () => {
    const record = (execution, statuses) => [
        '# RPI Plan Critique: Offline trail maps',
        '',
        '## Metadata',
        '',
        `* Critique execution: ${execution}`,
        '',
        '## Lens Assessments',
        '',
        '| Lens | Scope | Reasoning effort and source | Status | Candidates |',
        '|------|-------|-----------------------------|--------|------------|',
        ...statuses.map(([lens, status]) => `| ${lens} | all | direct | ${status} | pending |`),
        '',
        '## Verdict',
        '',
        '* Verdict: pending',
    ].join('\n');
    const assemble = (critique, session) => assembleSession({
        id: 'rpi-trail-maps',
        state: parseState({ ...ROOT_STATE, status: 'active', active_phase: 'Plan', session_status: session }),
        artifacts: { plan: parsePlan(PLAN), critique: parseCritique(critique) },
        statePath: PATHS.rootState,
        now: '2026-01-15T12:00:00.000Z',
    }).session.plan.critique;

    it('reads each lens status, and treats direct from older records as finished', () => {
        assert.deepEqual(['queued', 'Pending', 'in progress', 'In-progress', 'Complete', 'direct', 'Partial', 'Blocked'].map(lensStatusOf), ['queued', 'queued', 'in progress', 'in progress', 'complete', 'complete', 'partial', 'blocked']);
    });

    it('shows a started critique as running while the session runs, and as stopped otherwise, with no verdict', () => {
        const lenses = [['Coverage', 'Complete'], ['Evidence', 'in progress'], ['Risk', 'queued']];
        const running = assemble(record('started', lenses), 'running');
        assert.deepEqual([running.run, running.verdict, running.status], ['running', null, 'started']);
        assert.deepEqual(running.lenses.map((lens) => lens.status), ['complete', 'in progress', 'queued']);
        assert.equal(assemble(record('started', lenses), 'stopped').run, 'stopped', 'a critique left started by a stopped session stopped before it finished');
        const done = assemble(record('Complete', [['Coverage', 'direct']]).replace('* Verdict: pending', '* Verdict: Revise'), 'running');
        assert.deepEqual([done.run, done.verdict, done.lenses], [null, 'Revise', [{ lens: 'Coverage', status: 'complete' }]]);
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
        stored = recordActivity(stored, { text: 'Reading the plan' }, NOW).session;
        stored = upsertDecision(stored, { owner: 'user', phase: 'plan', title: 'Ship the coast first?', question: 'Which region?', options: [{ label: 'Coast' }, { label: 'Park' }] }, NOW).session;
        const asked = stored.decisions.at(-1);
        assert.equal(asked.id, 'D3', 'canvas decisions never collide with imported IDs');
        stored = { ...stored, scenario: { userChanges: 2 } };
        const merged = mergeImport(stored, withResearch(RESEARCH.replace('Tile licenses limit', 'Vendor licenses limit')), LATER);
        assert.notEqual(merged, stored);
        assert.equal(merged.revision, stored.revision + 1);
        assert.deepEqual(merged.feedback, stored.feedback);
        assert.equal(merged.implementation.activity.length, 1);
        assert.ok(merged.decisions.some((decision) => decision.id === 'D3'));
        assert.deepEqual(merged.scenario, { userChanges: 2 });
        assert.match(merged.sections['research-unknowns'].markdown, /Vendor licenses/);
    });

    it('drops the checklists a session saved before the canvas stopped keeping them', () => {
        const stored = { ...rootSession().session, checklists: { research: [{ id: 'R1', label: 'Old wording', verdict: 'needs-work', note: 'Old note' }] } };
        const merged = mergeImport(stored, rootSession().session, LATER);
        assert.notEqual(merged, stored, 'the first import after the change writes once');
        assert.equal(merged.revision, stored.revision + 1);
        assert.equal(merged.checklists, undefined);
        assert.equal(mergeImport(merged, rootSession().session, LATER), merged, 'and then writes nothing');
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

    it('lets every row the views show take a comment', async () => {
        const { findItem } = await import('../lib/model.mjs');
        const { buildScenario, STAGES } = await import('../lib/scenario.mjs');
        const sessions = [rootSession().session, childSession().session, ...STAGES.map((stage) => buildScenario(stage, Date.parse(NOW)))];
        for (const session of sessions) {
            const rendered = await renderAll(session);
            for (const [phase, { html }] of Object.entries(rendered)) {
                const rows = [...html.matchAll(/data-row="([^"]+)"/g)].map((match) => match[1]);
                const untargetable = rows.filter((id) => !findItem(session, id));
                assert.deepEqual(untargetable, [], `${session.id} ${phase}: rows a comment cannot target`);
            }
        }
    });
});

describe('plan diagrams', () => {
    const assembleWith = (plan) => assembleSession({
        id: 'rpi-trail-maps',
        state: parseState(ROOT_STATE),
        artifacts: { research: parseResearch(RESEARCH), plan: parsePlan(plan), critique: parseCritique(CRITIQUE), changes: parseChanges(CHANGES), review: parseReview(REVIEW) },
        statePath: PATHS.rootState,
        now: NOW,
    });

    it('report a Before or After diagram the canvas cannot draw, naming the line', () => {
        const { warnings } = assembleWith(PLAN.replace('    class store new\n', '    class store new\n    click store call alert()\n'));
        assert.ok(warnings.includes('Plan: the After diagram is shown as source. Unsupported diagram line: click store call alert()'), warnings.join(' | '));
        assert.equal(warnings.filter((warning) => warning.startsWith('Plan: the Before diagram')).length, 0);
    });

    it('draw groups and dashed edges without a warning', () => {
        const grouped = PLAN.replace('    map["Map view"]\n    net["Tile server"]\n    store["Added: tile store"]\n    map -->|reads| store', '    subgraph app["App"]\n        map["Map view"]\n        store["Added: tile store"]\n    end\n    net["Tile server"]\n    map -->|reads| store\n    map -.->|removed: fetches| net');
        assert.notEqual(grouped, PLAN, 'the fixture\'s After diagram changed');
        const { warnings, session } = assembleWith(grouped);
        assert.equal(warnings.filter((warning) => warning.startsWith('Plan:')).length, 0, warnings.join(' | '));
        assert.ok(session.plan.diagram.after.includes('subgraph app'));
    });

    /** The fixture plan with a change map in the planning skill's format: tags name the phases. */
    const tagged = (after = TAGGED_AFTER) => {
        const plan = PLAN.replace(/### Before\n[\s\S]*?The map reads tiles from a local store\./, `### Before\n\n\`\`\`mermaid\n${TAGGED_BEFORE}\n\`\`\`\n\n### After\n\n\`\`\`mermaid\n${after}\n\`\`\`\n\nThe map reads tiles from a local store.`);
        assert.notEqual(plan, PLAN, 'the fixture\'s change map changed');
        return plan;
    };
    const TAGGED_BEFORE = [
        'flowchart LR',
        '    accTitle: Before: tiles come from the server',
        '    accDescr: The map fetches tiles over the network.',
        '    subgraph app["`<code>src/map/</code>`"]',
        '        map["`**Map view**',
        '        changed · P01`"]',
        '        live["`**Live fetch**',
        '        removed · P02`"]',
        '    end',
        '    net["Tile server"]',
        '    map -->|uses| live',
        '    live -->|fetches| net',
        '    class map changed',
        '    class live removed',
    ].join('\n');
    const TAGGED_AFTER = [
        'flowchart LR',
        '    accTitle: After: tiles come from a local store',
        '    accDescr: The map reads a local store that downloads tiles.',
        '    subgraph app["`<code>src/map/</code>`"]',
        '        map["`**Map view**',
        '        changed · P01`"]',
        '        store["`**Tile store**',
        '        new · P01, P02`"]',
        '    end',
        '    net["Tile server"]',
        '    map -->|reads| store',
        '    store -->|downloads| net',
        '    class store new',
        '    class map changed',
    ].join('\n');

    it('take each phase\'s parts from the tags in After and Before', () => {
        const { warnings, session } = assembleWith(tagged());
        assert.equal(warnings.filter((warning) => warning.startsWith('Plan:')).length, 0, warnings.join(' | '));
        assert.deepEqual(session.plan.diagram.phaseNodes, { P01: ['map', 'store'], P02: ['store', 'live'] }, 'a part the plan removes counts for its phase');
    });

    it('name a tag that points to no phase and a marked part without a tag', () => {
        const { warnings, session } = assembleWith(tagged(TAGGED_AFTER.replace('new · P01, P02', 'new · P09').replace('    class map changed', '    class map,net changed')));
        assert.ok(warnings.includes('Plan: the After diagram tags store with P09, which is not a phase in this plan.'), warnings.join(' | '));
        assert.ok(warnings.includes('Plan: the After diagram marks net as a change but gives it no tag naming its phases.'), warnings.join(' | '));
        assert.deepEqual(session.plan.diagram.phaseNodes, { P01: ['map'], P02: ['live'] });
    });

    it('keep reading an older plan\'s phase diagrams when no part has a tag', () => {
        const { warnings, session } = assembleWith(PLAN);
        assert.deepEqual(session.plan.diagram.phaseNodes, { P01: ['store'], P02: [] });
        assert.equal(warnings.filter((warning) => warning.includes('no tag')).length, 0, 'older plans mark parts without tags');
    });
});
