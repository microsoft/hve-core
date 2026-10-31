// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
    artifactKind,
    parseArtifact,
    parseChanges,
    parseCritique,
    parsePlan,
    parseResearch,
    parseReview,
    parseState,
    stateDecision,
} from '../lib/source/parse.mjs';
import { CHANGES, CHILD_CHANGES, CHILD_STATE, CRITIQUE, PLAN, RESEARCH, REVIEW, ROOT_STATE, STALE_STATE } from './helpers/rpi-fixture.mjs';


/** A critique record with a lens table, as the critique writes it while it runs and when it ends. */
const critiqueRecord = (execution, verdict, lenses, findings = '') => [
    '# RPI Plan Critique: Lens progress',
    '',
    '## Metadata',
    '',
    `* Critique execution: ${execution}`,
    '',
    '## Lens Assessments',
    '',
    '| Lens | Scope | Reasoning effort and source | Status | Candidates |',
    '|------|-------|-----------------------------|--------|------------|',
    ...lenses.map(([lens, status]) => `| ${lens} | every phase | direct | ${status} | pending |`),
    '',
    '## Verdict',
    '',
    `* Verdict: ${verdict}`,
    '',
    '## Findings',
    '',
    findings,
].join('\n');

describe('artifact kinds and state', () => {
    it('recognizes each kind by its first heading', () => {
        assert.deepEqual([RESEARCH, PLAN, CRITIQUE, CHANGES, REVIEW].map(artifactKind), ['research', 'plan', 'critique', 'changes', 'review']);
        assert.equal(artifactKind('# Something else\n'), null);
        assert.equal(parseArtifact('no heading at all'), null);
    });

    it('normalizes state files, including variants and garbage', () => {
        const root = parseState(ROOT_STATE);
        assert.equal(root.taskId, 'trail-maps');
        assert.equal(root.parent, null);
        assert.equal(root.activePhase, 'Follow-up');
        assert.equal(root.artifacts.review, '.copilot-tracking/reviews/logs/2026-01-15/trail-maps-review.md');
        assert.equal(root.followUps.length, 2);
        assert.equal(stateDecision(root, 'review STEP').status, 'run');
        const child = parseState(CHILD_STATE);
        assert.deepEqual(child.parent, { taskId: 'trail-maps', taskSlug: 'trail-maps', statePath: '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-state.json' });
        assert.equal(child.sessionName, 'Offline trail maps');
        assert.deepEqual(child.children, []);
        assert.deepEqual(root.children, [{ taskId: 'trail-maps-fixes', taskSlug: 'trail-maps-fixes', statePath: '.copilot-tracking/rpi-sessions/2026-01-15/trail-maps/trail-maps-fixes-state.json' }]);
        assert.equal(child.artifacts.critique, null);
        const stale = parseState(STALE_STATE);
        assert.equal(stale.sessionName, null);
        assert.deepEqual(stale.children, []);
        assert.deepEqual(stale.followUps, [{ rank: 1, task: 'Ask the vendor about tile licensing', rationale: 'Owner: user', evidence: '' }]);
        assert.deepEqual(stale.blockers, [{ id: 'B1', summary: 'Waiting on the map vendor', resolution: '' }]);
        const garbage = parseState(['not', 'a', 'state']);
        assert.equal(garbage.taskId, null);
        assert.equal(garbage.warnings.length, 1);
        assert.deepEqual(garbage.followUps, []);
    });

    it('lists every document of each kind in creation order, with artifact_paths naming the current work\'s', () => {
        const base = { task_id: 't', artifact_paths: { research: 'r2.md', plan: null } };
        const one = parseState(base);
        assert.deepEqual(one.documents.research, ['r2.md'], 'a state without documents has one per kind');
        assert.deepEqual(one.documents.plan, []);
        const many = parseState({ ...base, documents: { research: ['r1.md', 'r2.md', 'r1.md'], plan: ['p1.md'] } });
        assert.deepEqual(many.documents.research, ['r1.md', 'r2.md']);
        assert.deepEqual(many.documents.plan, ['p1.md'], 'earlier work\'s plan stays listed');
        assert.equal(many.artifacts.plan, null, 'a null path means the current work has no plan yet');
        assert.deepEqual(many.warnings, []);
        const reused = parseState({ ...base, documents: { research: ['r2.md', 'r1.md'] } });
        assert.deepEqual(reused.documents.research, ['r2.md', 'r1.md'], 'the current work may reuse an earlier document');
        assert.deepEqual(reused.warnings, []);
        const off = parseState({ ...base, documents: { research: ['r1.md'], plan: 'p1.md' } });
        assert.deepEqual(off.documents.research, ['r1.md', 'r2.md'], 'a path the list lacks joins its end');
        assert.ok(off.warnings.some((text) => /documents\.research does not list artifact_paths\.research/.test(text)), off.warnings.join(' | '));
        assert.ok(off.warnings.some((text) => /documents\.plan is not a list/.test(text)));
        assert.ok(parseState({ ...base, documents: ['r1.md'] }).warnings.some((text) => /documents is not an object of lists/.test(text)));
    });

    it('keeps usable task links and warns about malformed ones', () => {
        const state = parseState({
            task_id: 'linked',
            parent_task: { task_slug: 'no-id-or-path' },
            child_tasks: [{ task_id: 'kept' }, 'text', { state_path: '.copilot-tracking/rpi-sessions/2026-01-15/s/path-only-state.json' }, {}],
        });
        assert.equal(state.parent, null);
        assert.deepEqual(state.children.map((link) => link.taskId ?? link.statePath), ['kept', '.copilot-tracking/rpi-sessions/2026-01-15/s/path-only-state.json']);
        assert.deepEqual(state.warnings, ['parent_task names no task_id or state_path.', 'child_tasks entry 2 names no task_id or state_path.', 'child_tasks entry 4 names no task_id or state_path.']);
        assert.deepEqual(parseState({ task_id: 'x', child_tasks: 'not a list' }).warnings, ['child_tasks is not a list.']);
    });
});

describe('research', () => {
    const research = parseResearch(RESEARCH);

    it('reads findings with their fields, and keeps the rest of the body', () => {
        assert.equal(research.title, 'Offline trail maps');
        assert.deepEqual(research.warnings, [], 'a research file in the template\'s shape reads cleanly');
        assert.equal(research.findings.length, 2);
        const [first] = research.findings;
        assert.deepEqual(first.evidence, ['C1', 'C2', 'C3', 'W1'], 'ranges expand');
        assert.deepEqual(first.questions, ['Q1']);
        assert.equal(first.evidenceState, 'Evidence-backed finding');
        assert.match(first.confidence, /^High/);
        assert.match(first.body, /\| Region \| Tiles \| Size \|/, 'tables inside a finding stay in its body');
        assert.doesNotMatch(first.body, /Evidence state:/, 'fields shown elsewhere are removed');
    });

    it('reads the questions, decisions, alternatives, risks, readiness, and evidence', () => {
        assert.deepEqual(research.questions.map((q) => q.status), ['answered', 'answered; renewal is a runtime check', 'open']);
        assert.deepEqual(research.decisions.map((d) => [d.id, d.owner, d.status]), [['D1', 'agent', 'confirmed'], ['D2', 'user', 'input requested']]);
        assert.deepEqual(research.alternatives.map((a) => a.disposition), ['selected', 'rejected as primary; kept for icons']);
        assert.deepEqual(research.alternatives[0].evidence, ['C1', 'W1']);
        assert.doesNotMatch(research.recommendation, /\| Option/, 'the alternatives table is not repeated in the prose');
        assert.deepEqual(research.risks.map((r) => r.priority), ['H', 'M']);
        assert.match(research.readiness, /^Ready:/);
        assert.deepEqual(research.evidence.map((e) => e.id), ['C1', 'C2', 'C3', 'W1', 'W2']);
        assert.match(research.evidence[3].source, /^\[Storage quotas\]\(https:/);
        assert.deepEqual(research.other.map((o) => o.heading), ['Scope and Questions', 'Planning Readiness and Next Step', 'Research Record']);
    });

    it('tolerates placeholders and empty tables', () => {
        const empty = parseResearch('# Task Research: x\n\n## Findings\n\nPending synthesis.\n\n## Research Record\n\n### Evidence Log\n\n| ID | Claim or finding |\n|----|------------------|\n');
        assert.deepEqual([empty.findings.length, empty.evidence.length, empty.questions.length], [0, 0, 0]);
        assert.equal(empty.warnings.length, 1, 'a missing summary is reported');
    });
});

describe('plan and critique', () => {
    const plan = parsePlan(PLAN);

    it('reads phases and tasks with their blocks, status, and diagrams', () => {
        assert.equal(plan.title, 'Offline trail maps');
        assert.equal(plan.taskId, 'trail-maps');
        assert.deepEqual(plan.phases.map((p) => [p.id, p.checked, p.tasks.length]), [['P01', true, 1], ['P02', false, 2]]);
        const [task] = plan.phases[0].tasks;
        assert.equal(task.title, 'Save tiles by region');
        assert.match(task.requirements, /\n {2}\* from the last saved tile/);
        assert.match(task.details, /region -> tiles \| metadata/);
        assert.deepEqual(plan.phases[1].tasks.map((t) => t.checked), [true, false]);
        assert.match(plan.before, /^%%\{init/);
        assert.match(plan.after, /class store new/);
        assert.match(plan.phases[0].diagram, /store -->\|downloads\| net/);
        assert.equal(plan.phases[1].diagram, null);
        assert.equal(plan.phases[0].highlighted, '`store`.');
        assert.match(plan.summary, /Bottom line/);
        assert.doesNotMatch(plan.summary, /Tiles expire/, 'What You May Not Know is separate');
        assert.match(plan.unknowns, /Tiles expire/);
    });

    it('reads the walk-through under After without its key or comments, and none without an After', () => {
        const text = [
            '# RPI Plan: x', '', '## Phase Checklist', '', '### After', '',
            '```mermaid', 'flowchart LR', '    a["A"]', '```', '',
            'Key: arrows point from a part to what it uses; thick border, changed.', '',
            'The form saves drafts first (P01).', 'Then the sync engine sends them (P02).', '',
            '<!-- a note for the agent -->', '',
            '<!<!-- a -->-- a comment that removing another one completes -->', '',
            'Conflicts wait for a person.', '',
            '<!-- rpi:phase id=P01 -->', '### [ ] P01: One', '', 'Goals:', '* g', '',
        ].join('\n');
        assert.equal(parsePlan(text).walkthrough, 'The form saves drafts first (P01).\nThen the sync engine sends them (P02).\n\nConflicts wait for a person.');
        assert.equal(parsePlan('# RPI Plan: x\n\n## Phase Checklist\n\n### [ ] P01: One\n\nGoals:\n* g\n').walkthrough, '');
    });

    it('stays fast on deeply nested comment openers in the walk-through', () => {
        const nested = `${'<!'.repeat(40000)}-- x -->${'-- -->'.repeat(40000)}`;
        const text = ['# RPI Plan: x', '', '## Phase Checklist', '', '### After', '', '```mermaid', 'flowchart LR', '    a["A"]', '```', '', nested, ''].join('\n');
        const started = performance.now();
        parsePlan(text);
        const ms = performance.now() - started;
        // Bounded removal passes keep this to a few milliseconds; removing one layer per pass takes seconds.
        assert.ok(ms < 500, `${Math.round(ms)} ms`);
    });

    it('reads requirements, decisions, readiness, critique dispositions, and follow-ups', () => {
        assert.deepEqual(plan.requirements.map((r) => r.id), ['FR-001', 'FR-002', 'FR-003', 'NFR-001']);
        assert.match(plan.requirements[3].text, /Objective threshold/);
        assert.deepEqual(plan.decisions.map((d) => d.id), ['D1', 'D2']);
        assert.equal(plan.readiness, 'Complete and Ready');
        assert.deepEqual(plan.critique.dispositions.map((d) => [d.finding, d.disposition]), [['PC-001', 'resolved'], ['PC-002', 'accepted with risk']]);
        assert.equal(plan.critique.setting, 'standard; first-task default');
        assert.deepEqual(plan.followUps, ['Cache a second region. Owner: user.']);
        assert.deepEqual(plan.other.map((o) => o.heading), ['Planning Readiness and Next Step', 'Risks and Open Questions']);
    });

    it('falls back to checkbox headings when markers are missing', () => {
        const unmarked = parsePlan('# RPI Plan: x\n\n## Phase Checklist\n\n### [x] P01: One\n\nGoals:\n* g\n\n#### [ ] P01-T01: Task\n\nGoals:\n* t\n');
        assert.deepEqual(unmarked.phases.map((p) => [p.id, p.tasks.map((t) => t.id)]), [['P01', ['P01-T01']]]);
        assert.equal(unmarked.warnings.length, 1);
    });

    it('reads lens progress, and expects findings only from a finished critique that did not pass', () => {
        const running = parseCritique(critiqueRecord('started', 'pending', [['Coverage', 'Complete'], ['Evidence', 'in progress'], ['Risk', 'queued']]));
        assert.equal(running.execution, 'started');
        assert.deepEqual(running.lenses, [{ lens: 'Coverage', status: 'Complete' }, { lens: 'Evidence', status: 'in progress' }, { lens: 'Risk', status: 'queued' }]);
        assert.deepEqual(running.warnings, [], 'a running critique may have no findings yet');
        assert.deepEqual(parseCritique(critiqueRecord('Complete', 'Pass', [['Coverage', 'direct']])).warnings, [], 'a passing critique may have none');
        assert.deepEqual(parseCritique(critiqueRecord('Complete', 'Revise', [['Coverage', 'Complete']])).warnings, ['The critique has no findings.']);
        assert.deepEqual(parseCritique(CRITIQUE).lenses, [], 'a record without a lens table has no lenses');
    });

    it('reads critique findings with severity and related plan IDs', () => {
        const critique = parseCritique(CRITIQUE);
        assert.equal(critique.verdict, 'Revise');
        assert.deepEqual(critique.findings.map((f) => [f.id, f.severity]), [['PC-001', 'high'], ['PC-002', 'low']]);
        assert.deepEqual(critique.findings[0].related, ['P01-T01', 'FR-001']);
        assert.deepEqual(critique.findings[1].related, ['P01'], 'section names in ID fields are ignored');
    });
});

describe('changes and review', () => {
    it('reads completed work, flat plan updates, validation, and lists', () => {
        const changes = parseChanges(CHANGES);
        assert.equal(changes.status.status, 'Complete');
        assert.deepEqual(changes.entries.map((e) => e.taskId), ['P01-T01', 'P02-T01']);
        assert.deepEqual(changes.entries[1].ids, ['P02-T01', 'RV-002']);
        assert.deepEqual(changes.entries[0].files, ['src/storage/tiles.ts', 'src/storage/quota.ts']);
        assert.match(changes.entries[0].behavior, /^\* A region downloads/);
        assert.deepEqual(changes.planUpdates.map((u) => u.title), ['Tile size', 'P02-T01 (descriptive)']);
        assert.deepEqual(changes.validation.map((v) => v.status), ['Passed', 'Passed with notes', 'Unavailable']);
        assert.deepEqual([changes.blockers, changes.remaining], [[], ['P02-T02']]);
        assert.equal(parseChanges(CHILD_CHANGES).planUpdates.length, 0, 'placeholder text is not an update');
    });

    it('reads plan updates and business alignment written as entries', () => {
        const changes = parseChanges([
            '# RPI Changes: x',
            '',
            '## Implementation-Time Plan Updates',
            '',
            '### Tile size changed',
            '',
            '* Affected plan area or markers: P01-T01',
            '* What changed: 20 KB tiles.',
            '',
            '## Business Alignment',
            '',
            '### ADR-0007 cache tier',
            '',
            '* Source document: docs/planning/adrs/0007-cache.md (ADR-0007, status accepted)',
            '* Cited requirement IDs: ADR-0007',
            '* Owner or deciders: Maintainers',
            '* Related plan update or marker: P01-T01',
            '* What changed: Tiles use IndexedDB.',
            '* Why: Quota.',
            '* User decision: none',
            '* Alignment: clarification',
        ].join('\n'));
        assert.deepEqual(changes.planUpdates.map((u) => [u.title, u.area]), [['Tile size changed', 'P01-T01']]);
        assert.deepEqual(changes.alignment.map((a) => [a.source, a.document, a.status, a.alignment, a.marker]), [['docs/planning/adrs/0007-cache.md', 'ADR-0007', 'accepted', 'clarification', 'P01-T01']]);
    });

    it('reads review findings, history with range subjects, validation, and follow-ups', () => {
        const review = parseReview(REVIEW);
        assert.deepEqual([review.execution, review.outcome], ['Complete', 'Defects found']);
        assert.deepEqual(review.findings.map((f) => [f.id, f.severity, f.destination]), [['RV-001', 'high', 'rpi-implement'], ['RV-002', 'medium', 'rpi-implement']]);
        assert.deepEqual(review.findings[1].related, ['P02-T01', 'CH-002']);
        assert.match(review.findings[0].observed, /^\* The download stops silently\./);
        assert.equal(review.history.at(-1).subject, 'RV-001 to RV-002');
        assert.deepEqual(review.validation.map((v) => v.status), ['Passed', 'Skipped']);
        assert.deepEqual(review.followUps.map((f) => f.item), ['Second region']);
        assert.match(review.disposition, /Final outcome: Defects found/);
        assert.deepEqual(review.other.map((o) => o.heading), ['Risks, Blockers, and Residual Work', 'Review Record']);
    });
});
