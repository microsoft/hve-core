// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { buildScenario, STAGES } from '../lib/scenario.mjs';
import { ID_KINDS, ID_SOURCE, kindOf, LEGEND_GROUPS, LINK_ICONS } from '../ui/ids.mjs';

const NOW = Date.parse('2026-10-23T12:00:00.000Z');
const matches = (text) => [...text.matchAll(new RegExp(ID_SOURCE, 'g'))].map((match) => match[0]);

/** Every item ID the canvas can navigate to in a session, from the same pools `find` searches. */
function itemIds(session) {
    const pools = [session.research.questions, session.research.findings, session.research.evidence, session.research.lanes, session.decisions, session.plan.requirements, session.plan.critique?.findings ?? [], session.implementation.changes, session.implementation.discoveries, session.implementation.alignment, session.review.findings, session.review.history, session.followUps.items, session.feedback];
    const ids = pools.flatMap((pool) => (pool ?? []).map((item) => item.id));
    for (const phase of session.plan.phases ?? []) {
        ids.push(phase.id, ...phase.tasks.map((task) => task.id));
    }
    return ids;
}

describe('ID table', () => {
    it('names each family once and recognizes its own example', () => {
        assert.equal(new Set(ID_KINDS.map((entry) => entry.key)).size, ID_KINDS.length);
        for (const entry of ID_KINDS) {
            assert.equal(kindOf(entry.example)?.key, entry.key, entry.example);
            assert.ok(entry.kind && entry.description, entry.key);
        }
    });

    it('finds whole IDs in text and skips near misses', () => {
        assert.deepEqual(matches('See P01-T02, NFR-002, FR-003, C22, W11, FU-2, and D100; not P1, FR-01, C1234, xC22, or FB-12.'),
            ['P01-T02', 'NFR-002', 'FR-003', 'C22', 'W11', 'FU-2', 'D100']);
    });

    it('reads a plan task as a task, never as its phase', () => {
        assert.deepEqual(matches('P03-T01 then P03'), ['P03-T01', 'P03']);
        assert.equal(kindOf('P03-T01').key, 'T');
        assert.equal(kindOf('plan.D2').key, 'D');
    });

    for (const stage of STAGES) {
        it(`has a family for every item in the ${stage} scenario`, () => {
            const missing = itemIds(buildScenario(stage, NOW)).filter((id) => !kindOf(id));
            assert.deepEqual(missing, []);
        });
    }

    it('groups every family in the legend and explains each icon', () => {
        const phases = new Set(LEGEND_GROUPS.map((group) => group.phase));
        for (const entry of ID_KINDS) assert.ok(phases.has(entry.phase), entry.key);
        assert.deepEqual(LINK_ICONS.map((entry) => entry.icon), ['go-to', 'file', 'globe', 'file-code']);
    });
});
