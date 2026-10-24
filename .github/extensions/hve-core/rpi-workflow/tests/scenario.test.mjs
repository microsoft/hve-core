// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { deriveView, findItem, validateSession } from '../lib/model.mjs';
import { buildScenario, STAGES } from '../lib/scenario.mjs';

const NOW = Date.parse('2026-10-23T12:00:00.000Z');

describe('scenario stages', () => {
    for (const stage of STAGES) {
        it(`builds a valid ${stage} session`, () => {
            const session = buildScenario(stage, NOW);
            assert.doesNotThrow(() => validateSession(session));
            assert.equal(session.session.activePhase, stage);
            assert.equal(session.phases[stage].status, 'active');
            for (const [from, to] of session.links) {
                assert.ok(findItem(session, from), `${stage}: link source ${from}`);
                assert.ok(findItem(session, to), `${stage}: link target ${to}`);
            }
            for (const decision of session.decisions) {
                if (decision.anchor) {
                    assert.ok(findItem(session, decision.anchor.rowId), `${stage}: anchor ${decision.anchor.rowId}`);
                }
            }
        });
    }

    it('keeps later phases empty and upcoming', () => {
        const research = buildScenario('research', NOW);
        assert.equal(research.plan.phases.length, 0);
        assert.equal(research.implementation.changes.length, 0);
        assert.equal(research.review.findings.length, 0);
        assert.equal(research.phases.plan.status, 'upcoming');
        assert.equal(research.phases.plan.artifact, null);
    });

    it('covers the minimum content each view needs', () => {
        const research = buildScenario('research', NOW);
        assert.equal(research.research.questions.length, 5);
        const states = new Set(research.research.findings.map((f) => f.state));
        for (const state of ['evidence-backed', 'partially-supported', 'hypothesis', 'weakened']) {
            assert.ok(states.has(state), state);
        }
        assert.ok(deriveView(research).needsYou.some((d) => d.id === 'D2'));
        assert.ok(research.research.evidence.filter((e) => e.kind === 'web').every((e) => e.url.startsWith('https://') && e.retrieved));

        const implement = buildScenario('implement', NOW);
        const tasks = implement.plan.phases.flatMap((p) => p.tasks);
        assert.ok(tasks.length >= 9);
        const statuses = new Set(tasks.map((t) => t.status));
        for (const status of ['done', 'in-progress', 'paused', 'todo', 'blocked']) {
            assert.ok(statuses.has(status), status);
        }
        const kinds = new Set(implement.implementation.discoveries.map((d) => d.kind));
        for (const kind of ['local', 'annotation', 'follow-up', 'plan-change']) {
            assert.ok(kinds.has(kind), kind);
        }
        assert.ok(implement.implementation.discoveries.some((d) => d.planUpdate && d.planUpdate.before && d.planUpdate.after));
        assert.equal(implement.implementation.alignment[0].alignment, 'pending-decision');
        assert.ok(deriveView(implement).needsYou.some((d) => d.id === 'D6'));

        const review = buildScenario('review', NOW);
        const severities = new Set(review.review.findings.map((f) => f.severity));
        for (const severity of ['high', 'medium', 'low']) {
            assert.ok(severities.has(severity), severity);
        }
        const followup = buildScenario('followup', NOW);
        assert.ok(followup.followUps.items.length >= 3);
        assert.ok(followup.followUps.lineage.some((l) => l.relation === 'child'));
    });

    it('rejects an unknown stage', () => {
        assert.throws(() => buildScenario('deploy', NOW), /Unknown stage/);
    });
});
