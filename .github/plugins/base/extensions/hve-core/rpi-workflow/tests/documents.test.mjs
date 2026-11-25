// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { loadTask, resolveWorkspace } from '../lib/source/workspace.mjs';
import { composeDocument, documentChoices, DOCUMENT_OPTION_CHARS, documentsIn, earlierDocument, findInPart, inEarlier, pairedPlanOf, partOf, scopedLookup } from '../ui/documents.mjs';
import { elements, installFakeDom } from './helpers/fake-dom.mjs';
import { initialUi, makeContext } from './helpers/render-views.mjs';
import { PATHS, ROOT_STATE, writeEarlierWork, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

const NOW = '2026-01-15T12:00:00.000Z';
let tmp;
let restore;
let session;

/** Loads the fixture task with the earlier work beside it; `state` overrides the root state. */
async function load(name, state = {}) {
    const root = path.join(tmp, name);
    await writeFixtureWorkspace(root);
    const documents = await writeEarlierWork(root);
    const target = path.join(root, PATHS.rootState);
    await fs.writeFile(target, JSON.stringify({ ...ROOT_STATE, active_phase: 'Implement', status: 'active', documents, ...state }));
    return (await loadTask(await resolveWorkspace([root]), PATHS.rootState, NOW)).session;
}

before(async () => {
    restore = installFakeDom();
    tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-documents-')));
    session = await load('pairs');
});
after(async () => {
    restore();
    await fs.rm(tmp, { recursive: true, force: true });
});

const doc = (phase, n) => earlierDocument(session, phase, n);
const textsOf = (group) => group.options.map((option) => option.text);

describe('the Document list', () => {
    it('lists changes records by title, marking the current one', () => {
        const choices = documentChoices(session, 'implement', null);
        assert.equal(choices.selected, 3);
        assert.deepEqual(choices.groups.map((group) => group.label), [null]);
        assert.deepEqual(textsOf(choices.groups[0]), ['A record without a plan', 'An early look', 'Offline trail maps (current)']);
        assert.equal(documentChoices(session, 'implement', 2).selected, 2, 'a shown earlier record is selected');
    });

    it('groups reviews by work under the work\'s plan title, in the order each work was listed', () => {
        const choices = documentChoices(session, 'review', null, (entry) => `time of ${entry.n}`);
        assert.deepEqual(choices.groups.map((group) => group.label), ['An early look', 'Offline trail maps']);
        assert.deepEqual(textsOf(choices.groups[0]), ['The first look · time of 1', 'The second look · time of 2']);
        assert.deepEqual(textsOf(choices.groups[1]), ['Offline trail maps (current) · time of 3']);
        assert.ok(choices.groups.flatMap((group) => group.options).every((option) => option.title.endsWith('.md')), 'each option names its file');
    });

    it('ends with a Current work entry outside the groups when the current work has none', async () => {
        const fresh = await load('no-review', { artifact_paths: { ...ROOT_STATE.artifact_paths, review: null } });
        const choices = documentChoices(fresh, 'review', null);
        assert.equal(choices.selected, 0);
        assert.deepEqual(choices.groups.at(-1), { label: null, options: [{ value: 0, text: 'Current work: no review yet', title: null, disabled: false }] });
        assert.deepEqual(choices.groups.slice(0, -1).map((group) => group.label), ['An early look', 'Offline trail maps'], 'the earlier reviews keep their groups');
        assert.equal(documentChoices(fresh, 'implement', null).groups[0].options.length, 3, 'Implement still lists every changes record');
    });

    it('offers no list for a phase without an earlier document, and clips long labels', () => {
        assert.equal(documentChoices(session, 'research', null), null);
        assert.equal(documentChoices(session, 'followup', null), null);
        const long = 'A plan title long enough that the option would push the context bar wider than the canvas';
        const changed = { ...session, documents: { ...session.documents, review: session.documents.review.map((entry) => ({ ...entry, workTitle: long })) } };
        const label = documentChoices(changed, 'review', null).groups[0].label;
        assert.equal(label.length, DOCUMENT_OPTION_CHARS);
        assert.ok(label.endsWith('…'));
    });

    it('marks a document that could not be read and keeps it from being chosen', () => {
        const broken = { ...session, documents: { ...session.documents, implement: session.documents.implement.map((entry) => (entry.n === 1 ? { ...entry, snapshot: undefined, missing: true } : entry)) } };
        const option = documentChoices(broken, 'implement', null).groups[0].options[0];
        assert.equal(option.disabled, true);
        assert.match(option.text, /\(unreadable\)$/);
        assert.equal(earlierDocument(broken, 'implement', 1), null);
    });
});

describe('an earlier document in place of the current work\'s', () => {
    it('shows an earlier changes record with its own plan, sections, decisions, and other sections', () => {
        const record = doc('implement', 2);
        const composed = composeDocument(session, 'implement', record);
        assert.deepEqual(composed.plan, documentsIn(session, 'plan')[0].snapshot.plan, 'the plan of its name');
        assert.ok(composed.plan.phases.flatMap((phase) => phase.tasks).every((task) => task.status !== 'in-progress'));
        assert.ok(session.plan.phases.flatMap((phase) => phase.tasks).some((task) => task.status === 'in-progress'), 'the current plan has a task in progress');
        assert.equal(composed.implementation, record.snapshot.implementation);
        assert.ok(composed.sections['task-p01-t01'] && composed.sections['changes-summary']);
        assert.equal(composed.sections['plan-summary'], undefined, 'the current plan\'s sections stay out');
        assert.ok(composed.records.implement.some((item) => item.heading === 'Early notes'));
        assert.equal(composed.phases.implement.artifact, record.path);
        assert.ok(composed.decisions.every((decision) => decision.phase === 'plan'));
        assert.equal(composeDocument(session, 'implement', record), composed, 'kept per session');
    });

    it('shows a changes record whose plan is missing without tasks, and says so', () => {
        const lonely = doc('implement', 1);
        assert.equal(pairedPlanOf(session, lonely).missing, true);
        assert.deepEqual(composeDocument(session, 'implement', lonely).plan.phases, []);
        assert.equal(pairedPlanOf(session, doc('implement', 2)).missing, false);
    });

    it('shows an earlier review and research document with their own other sections', () => {
        const second = composeDocument(session, 'review', doc('review', 2));
        assert.ok(second.records.review.some((item) => item.heading === 'Second look notes'));
        assert.ok(!composeDocument(session, 'review', doc('review', 1)).records.review.some((item) => item.heading === 'Second look notes'));
        assert.ok(!session.records.review.some((item) => item.heading === 'Second look notes'));
    });
});

describe('IDs inside an earlier document', () => {
    it('finds a review\'s own IDs first, then its work\'s changes record and plan', () => {
        const scope = { phase: 'review', doc: doc('review', 1) };
        assert.deepEqual(pick(scopedLookup(session, scope, 'RV-001')), { phase: 'review', doc: 1 });
        assert.deepEqual(pick(scopedLookup(session, scope, 'RD-003')), { phase: 'review', doc: 1 });
        assert.deepEqual(pick(scopedLookup(session, scope, 'CH-002')), { phase: 'implement', doc: 2 }, 'the early record, not the current one or the lonely one');
        assert.deepEqual(pick(scopedLookup(session, scope, 'P02-T01')), { phase: 'plan', doc: 1 });
        assert.deepEqual(pick(scopedLookup(session, scope, 'FR-001')), { phase: 'plan', doc: 1 });
        assert.equal(scopedLookup(session, scope, 'FB-001'), null, 'the caller falls back to the current work');
    });

    it('keeps a changes record\'s tasks and changes in Implement on that record', () => {
        const scope = { phase: 'implement', doc: doc('implement', 2) };
        assert.deepEqual(pick(scopedLookup(session, scope, 'P02-T01')), { phase: 'implement', doc: 2 });
        assert.deepEqual(pick(scopedLookup(session, scope, 'CH-001')), { phase: 'implement', doc: 2 });
        assert.deepEqual(pick(scopedLookup(session, { phase: 'implement', doc: doc('implement', 1) }, 'CH-002')), { phase: 'implement', doc: 1 }, 'each record keeps its own CH IDs');
    });

    it('leaves the global lookup to the current work first, then the newest earlier document', () => {
        assert.ok(findInPart('review', partOf(session, 'review', null), 'RV-001'), 'the current review holds RV-001');
        assert.deepEqual(pick(inEarlier(session, 'CH-002')), { phase: 'implement', doc: 2 }, 'newest earlier record first');
        assert.deepEqual(pick(inEarlier(session, 'RV-002')), { phase: 'review', doc: 2 });
        assert.equal(inEarlier(session, 'CH-002').item.title, 'The map reads stored tiles first');
        assert.equal(findInPart('implement', partOf(session, 'implement', null), 'plan-summary'), null, 'Implement holds no plan summary');
    });
});

describe('rendering an earlier document read-only', () => {
    const render = async (phase, composed) => {
        const view = await import(`../ui/view-${phase}.mjs`);
        const root = document.createElement('div');
        const ctx = { ...makeContext(composed, phase, { ...initialUi(phase), taskFilter: 'all' }), readOnly: true };
        for (const node of [view.renderView(ctx)].flat(Infinity).filter(Boolean)) root.appendChild(node);
        return { root, ctx };
    };

    it('shows an earlier record\'s board count and tasks from its own plan, none in progress', async () => {
        const composed = composeDocument(session, 'implement', doc('implement', 2));
        const { root } = await render('implement', composed);
        const tasks = composed.plan.phases.flatMap((phase) => phase.tasks);
        const summary = elements(root).find((node) => node.classList?.contains('board-dock-summary'));
        assert.equal(summary.textContent, `${tasks.filter((task) => task.status === 'done').length} of ${tasks.length} tasks done`);
        assert.ok(!elements(root).some((node) => node.classList?.contains('task') && node.classList.contains('is-in-progress')));
        assert.ok(!elements(root).some((node) => node.localName === 'button' && /Ask the agent to/.test(node.textContent ?? '')));
    });

    it('offers no Question this decision in an earlier review, and no Ask the agent in its file sheet', async () => {
        const { root } = await render('review', composeDocument(session, 'review', doc('review', 1)));
        assert.ok(!elements(root).some((node) => node.localName === 'button' && node.textContent?.includes('Question this decision')));
        assert.ok(!root.textContent.includes('you can question'), 'nor an invitation to question its decisions');
        const { filePreview } = await import('../ui/components.mjs');
        const composed = composeDocument(session, 'implement', doc('implement', 2));
        const change = composed.implementation.changes.find((item) => item.files.length);
        const ctx = { ...makeContext(composed, 'implement'), readOnly: true };
        const sheet = document.createElement('div');
        for (const node of filePreview(ctx, change, change.files[0]).filter(Boolean)) sheet.appendChild(node);
        assert.ok(!elements(sheet).some((node) => node.localName === 'button' && node.textContent?.includes('Ask the agent about this change')));
        const live = document.createElement('div');
        for (const node of filePreview(makeContext(session, 'implement'), session.implementation.changes.find((item) => item.files.length), session.implementation.changes.find((item) => item.files.length).files[0]).filter(Boolean)) live.appendChild(node);
        assert.ok(elements(live).some((node) => node.localName === 'button' && node.textContent?.includes('Ask the agent about this change')), 'the current record still asks');
    });
});

/** A lookup's phase and document number, without the item; `inEarlier` returns the document itself. */
function pick(hit) {
    return hit ? { phase: hit.phase, doc: typeof hit.doc === 'object' && hit.doc ? hit.doc.n : hit.doc } : null;
}
