// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
    agentEditSection,
    artifactFor,
    buildTraces,
    claimDelivery,
    composeDelivery,
    composeSessionDelivery,
    createFeedback,
    deriveView,
    discardFeedback,
    editFeedback,
    FEEDBACK_TRANSITIONS,
    feedbackOverview,
    findItem,
    LIMITS,
    markDelivered,
    ModelError,
    pendingSuggestion,
    phaseOf,
    recordActivity,
    recordChange,
    recordInterpretation,
    referenceLinks,
    releaseDelivery,
    suggestEdit,
    takeFeedback,
    transitionFeedback,
    updateSession,
    updateTask,
    upsertDecision,
    validateSession,
} from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';

const NOW = '2026-10-23T12:00:00.000Z';
const base = () => buildScenario('research', Date.parse(NOW));

function code(fn) {
    try {
        fn();
    } catch (error) {
        assert.ok(error instanceof ModelError, `expected ModelError, got ${error}`);
        return error.code;
    }
    assert.fail('expected an error');
}

describe('feedback lifecycle', () => {
    it('allows exactly the contract transitions', () => {
        const states = Object.keys(FEEDBACK_TRANSITIONS);
        let session = base();
        for (const from of states) {
            for (const to of states) {
                const created = createFeedback(session, { kind: 'comment', text: `${from} to ${to}`, state: 'draft' }, NOW);
                let s = created.session;
                const id = created.result.id;
                const path = { draft: [], queued: ['queued'], sent: ['queued', 'sent'], interpreted: ['queued', 'sent', 'interpreted'], applied: ['queued', 'sent', 'applied'], corrected: ['queued', 'sent', 'interpreted', 'corrected'], dismissed: ['dismissed'] }[from];
                for (const step of path) {
                    s = transitionFeedback(s, id, step, { interpretation: { text: 'read back' } }, NOW).session;
                }
                const allowed = FEEDBACK_TRANSITIONS[from].includes(to);
                if (allowed) {
                    assert.doesNotThrow(() => transitionFeedback(s, id, to, { interpretation: { text: 'read back' } }, NOW), `${from} -> ${to}`);
                } else {
                    assert.equal(code(() => transitionFeedback(s, id, to, { interpretation: { text: 'x' } }, NOW)), 'invalid_transition', `${from} -> ${to}`);
                }
            }
        }
        session = undefined;
    });

    it('answers a decision, and a read-back resolves it without asking the user to confirm', () => {
        let s = base();
        const created = createFeedback(s, { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both photos.' }, NOW);
        s = created.session;
        assert.equal(s.decisions.find((d) => d.id === 'D2').status, 'answered');
        const taken = takeFeedback(s, NOW);
        assert.deepEqual(taken.result.map((item) => item.id), [created.result.id]);
        const early = recordInterpretation(taken.session, { feedbackId: created.result.id, text: 'Queue same-field conflicts.', applied: false }, NOW).session;
        assert.equal(early.feedback.find((item) => item.id === created.result.id).state, 'interpreted', 'applied false reads back before the change');
        s = recordInterpretation(taken.session, { feedbackId: created.result.id, text: 'Queue same-field conflicts.', effect: 'Adds P02-T03' }, NOW).session;
        assert.equal(s.feedback.find((item) => item.id === created.result.id).state, 'applied');
        assert.equal(s.decisions.find((d) => d.id === 'D2').status, 'resolved');
        const view = deriveView(s);
        assert.ok(view.readBacks.includes(created.result.id));
        assert.equal(view.attentionCount, view.needsYou.length, 'read-backs do not need the user');
        const corrected = transitionFeedback(s, created.result.id, 'corrected', { correction: 'Keep one photo.' }, NOW);
        assert.equal(corrected.result.correctionOf, created.result.id, 'a correction from the history names the item');
        assert.equal(corrected.session.decisions.find((d) => d.id === 'D2').status, 'answered', 'and reopens the decision until the agent reads it back');
    });

    it('creates a prefilled correction linked to the original', () => {
        let s = base();
        const fb = s.feedback.find((item) => item.state === 'interpreted');
        const corrected = transitionFeedback(s, fb.id, 'corrected', { correction: 'Only announce Synced once.' }, NOW);
        s = corrected.session;
        assert.equal(s.feedback.find((item) => item.id === fb.id).state, 'corrected');
        assert.equal(corrected.result.kind, 'correction');
        assert.equal(corrected.result.state, 'queued');
        assert.equal(corrected.result.correctionOf, fb.id);
        assert.equal(corrected.result.text, 'Only announce Synced once.');
    });

    it('reopens a decision when its queued correction is dismissed', () => {
        let s = base();
        const answer = createFeedback(s, { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both photos.' }, NOW);
        s = takeFeedback(answer.session, NOW).session;
        s = recordInterpretation(s, { feedbackId: answer.result.id, text: 'Keep both photos.' }, NOW).session;
        const corrected = transitionFeedback(s, answer.result.id, 'corrected', { correction: 'Keep the newer photo.' }, NOW);
        assert.equal(corrected.session.decisions.find((d) => d.id === 'D2').status, 'answered');
        s = transitionFeedback(corrected.session, corrected.result.id, 'dismissed', {}, NOW).session;
        const decision = s.decisions.find((d) => d.id === 'D2');
        assert.equal(decision.status, 'needs-input');
        assert.equal(decision.feedbackId, undefined);

        let o = base();
        const override = createFeedback(o, { kind: 'override', target: { id: 'D1' }, optionId: 'b' }, NOW);
        o = takeFeedback(override.session, NOW).session;
        o = recordInterpretation(o, { feedbackId: override.result.id, text: 'Use option b.' }, NOW).session;
        const overrideCorrection = transitionFeedback(o, override.result.id, 'corrected', { correction: 'Only for new drafts.' }, NOW);
        o = transitionFeedback(overrideCorrection.session, overrideCorrection.result.id, 'dismissed', {}, NOW).session;
        const agentChoice = base().decisions.find((d) => d.id === 'D1').chosen;
        assert.equal(o.decisions.find((d) => d.id === 'D1').status, 'decided');
        assert.equal(o.decisions.find((d) => d.id === 'D1').chosen, agentChoice, 'withdrawing a corrected override restores the agent choice');

        const queuedOverride = createFeedback(base(), { kind: 'override', target: { id: 'D1' }, optionId: 'b' }, NOW);
        assert.equal(queuedOverride.session.decisions.find((d) => d.id === 'D1').chosen, 'b');
        const withdrawn = transitionFeedback(queuedOverride.session, queuedOverride.result.id, 'dismissed', {}, NOW).session;
        assert.equal(withdrawn.decisions.find((d) => d.id === 'D1').status, 'decided');
        assert.equal(withdrawn.decisions.find((d) => d.id === 'D1').chosen, agentChoice, 'dismissing a queued override restores the agent choice');
        assert.equal(s.decisions.find((d) => d.id === 'D2').chosen, undefined, 'a dismissed correction reopens an answer with no choice');
    });

    it('rejects answers to agent-owned decisions and unknown targets', () => {
        const s = base();
        assert.equal(code(() => createFeedback(s, { kind: 'answer', target: { id: 'D1' }, optionId: 'a' }, NOW)), 'invalid_state');
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: 'NOPE' } }, NOW)), 'not_found');
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: '__proto__' } }, NOW)), 'invalid_input');
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: 'constructor' } }, NOW)), 'not_found');
        assert.doesNotThrow(() => createFeedback(s, { kind: 'override', target: { id: 'D1' }, optionId: 'b' }, NOW));
    });

    it('bounds text and item counts', () => {
        const s = base();
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x'.repeat(LIMITS.text + 1) }, NOW)), 'invalid_input');
        const full = structuredClone(s);
        full.feedback = Array.from({ length: LIMITS.feedbackItems }, (_, i) => ({ id: `FB-${i + 900}`, kind: 'comment', state: 'applied', target: null, text: '', history: [] }));
        assert.equal(code(() => createFeedback(full, { kind: 'comment', text: 'one more' }, NOW)), 'limit_reached');
    });
});

describe('changing and discarding unsent feedback', () => {
    it('changes the words of an unsent item, and refuses what was sent, is being sent, or lives elsewhere', () => {
        let s = createFeedback(base(), { kind: 'comment', text: 'First words', target: { id: 'F1' } }, NOW).session;
        const id = s.feedback.at(-1).id;
        const LATER = '2026-10-23T12:05:00.000Z';
        const edited = editFeedback(s, id, '  Better words  ', LATER);
        const item = edited.session.feedback.find((entry) => entry.id === id);
        assert.deepEqual([item.text, item.state, item.editedAt, item.updatedAt, edited.session.revision], ['Better words', 'queued', LATER, LATER, s.revision + 1]);
        assert.equal(code(() => editFeedback(s, id, '   ', LATER)), 'invalid_input', 'a comment needs words');
        assert.equal(code(() => editFeedback(s, 'FB-999', 'x', LATER)), 'not_found');
        assert.equal(code(() => editFeedback(claimDelivery(s, [id], NOW).session, id, 'x', LATER)), 'invalid_state', 'not while it is being sent');
        assert.equal(code(() => editFeedback(markDelivered(s, [id], 'send', NOW).session, id, 'x', LATER)), 'invalid_state', 'not once it was sent');
        s = suggestEdit(s, { sectionId: 'research-summary', markdown: `${s.sections['research-summary'].markdown}\n\nMore.`, baseRevision: s.sections['research-summary'].revision }, NOW).session;
        assert.equal(code(() => editFeedback(s, s.feedback.at(-1).id, 'x', LATER)), 'invalid_input', 'a suggested edit changes in its editor');
    });

    it('lets an answer with an option drop its note, but not an answer in words alone', () => {
        const chosen = createFeedback(base(), { kind: 'answer', target: { id: 'D2' }, optionId: 'b', text: 'Because' }, NOW).session;
        assert.equal(editFeedback(chosen, chosen.feedback.at(-1).id, '', NOW).session.feedback.at(-1).text, '');
        const worded = createFeedback(base(), { kind: 'answer', target: { id: 'D2' }, text: 'Something else' }, NOW).session;
        assert.equal(code(() => editFeedback(worded, worded.feedback.at(-1).id, '', NOW)), 'invalid_input');
    });

    it('discards every unsent item it names in one revision, and skips the rest', () => {
        let s = base();
        for (const text of ['One', 'Two', 'Three']) s = createFeedback(s, { kind: 'comment', text }, NOW).session;
        const [a, b, c] = s.feedback.slice(-3).map((item) => item.id);
        s = markDelivered(s, [c], 'send', NOW).session;
        const { session, result } = discardFeedback(s, [a, b, c, 'FB-999'], NOW);
        assert.deepEqual(result, { discarded: [a, b], skipped: [c, 'FB-999'] });
        assert.deepEqual([a, b, c].map((id) => session.feedback.find((item) => item.id === id).state), ['dismissed', 'dismissed', 'sent']);
        assert.equal(session.revision, s.revision + 1);
        assert.equal(discardFeedback(s, [c], NOW).session, s, 'nothing to discard changes nothing');
    });

    it('summarizes another loop\'s unsent items with their whole words, target, and whether they can change here', () => {
        const long = 'x'.repeat(600);
        const s = createFeedback(base(), { kind: 'comment', text: long, target: { id: 'F1', part: 'paragraph 2' } }, NOW).session;
        const [entry] = feedbackOverview(s, NOW).pending.filter((item) => item.kind === 'comment');
        assert.deepEqual([entry.text.length, entry.target, entry.editable, entry.optionLabel], [600, { id: 'F1', part: 'paragraph 2' }, true, null]);
    });
});

describe('delivery composition', () => {
    const canvas = { handle: '3WF0', instanceId: 'rpi-workflow-demo' };

    it('produces one string for preview and prompt, naming the canvas in both texts', () => {
        let s = base();
        s = createFeedback(s, { kind: 'answer', target: { id: 'D2' }, optionId: 'a', text: 'Keep both photos.' }, NOW).session;
        s = createFeedback(s, { kind: 'research-request', target: { id: 'F1' }, text: 'Check iOS quota.' }, NOW).session;
        const ids = s.feedback.filter((item) => item.state === 'queued').map((item) => item.id);
        const preview = composeDelivery(s, ids, NOW, { canvas });
        const again = composeDelivery(s, ids, NOW, { canvas });
        assert.equal(preview.prompt, again.prompt);
        assert.equal(preview.digest, again.digest);
        assert.match(preview.prompt, /^RPI canvas 3WF0 sent 2 items from the user about task field-inspections-offline-sync \(current phase: Research\)\.\nCanvas instance ID: rpi-workflow-demo\. Pass it as instanceId to invoke_canvas_action/);
        assert.match(preview.prompt, /sample session, which has no files/);
        assert.doesNotMatch(preview.prompt, /Task files:/);
        assert.match(preview.prompt, /1\. FB-\d{3}: Answer to D2 "[^"]+" \(Research\)\n {3}Chose: Merge per field/);
        assert.match(preview.prompt, /record_interpretation on this canvas/);
        assert.equal(preview.displayPrompt, 'RPI canvas 3WF0 sent 2 items: 1 answer and 1 research request.');
        assert.equal(composeDelivery(s, ids, NOW).displayPrompt, 'RPI canvas sent 2 items: 1 answer and 1 research request.', 'a canvas without a handle still names itself');
        const noted = composeDelivery(s, ids, NOW, { canvas, note: 'Please start with the quota.\nThanks.' });
        assert.equal(noted.digest, preview.digest, 'the message does not change the digest');
        assert.match(noted.prompt, /\n\nMessage from the user:\n {3}Please start with the quota\.\n {3}Thanks\.\n\nHow to handle/);
        assert.equal(noted.displayPrompt, 'Please start with the quota.\nThanks.\n\nRPI canvas 3WF0 sent 2 items: 1 answer and 1 research request.');
        assert.equal(code(() => composeDelivery(s, ids, NOW, { note: 'x'.repeat(LIMITS.text + 1) })), 'invalid_input');
        const claimed = claimDelivery(s, ids, NOW);
        assert.equal(takeFeedback(claimed.session, NOW).result.length, 0);
        assert.equal(code(() => composeDelivery(claimed.session, ids, NOW)), 'invalid_state');
        assert.equal(code(() => claimDelivery(claimed.session, ids, NOW)), 'invalid_state');
        const later = new Date(Date.parse(NOW) + 11 * 60 * 1000).toISOString();
        assert.equal(takeFeedback(claimed.session, later).result.length, ids.length, 'a stale claim lapses');
        assert.equal(releaseDelivery(claimed.session, ids, NOW).session.feedback.filter((item) => item.deliveringSince).length, 0);
        assert.equal(code(() => markDelivered(s, ids, 'attach', NOW)), 'invalid_input');
        const delivered = markDelivered(s, ids, 'send', NOW);
        assert.deepEqual(delivered.result, ids);
        assert.ok(delivered.session.feedback.filter((item) => ids.includes(item.id)).every((item) => item.state === 'sent' && item.delivery === 'send'));
        assert.equal(code(() => composeDelivery(delivered.session, ids)), 'invalid_state');
    });

    it('names the task files for a real session and the file each item changes', () => {
        let s = base();
        s.source = { kind: 'rpi', statePath: '.copilot-tracking/rpi-sessions/2026-10-26/t-state.json', artifacts: { research: '.copilot-tracking/research/2026-10-26/t-research.md', plan: null, critique: null, changes: null, review: null } };
        s = createFeedback(s, { kind: 'answer', target: { id: 'D2' }, optionId: 'a' }, NOW).session;
        s = suggestEdit(s, { sectionId: 'research-summary', markdown: `${s.sections['research-summary'].markdown}\n\nOne more line.`, baseRevision: s.sections['research-summary'].revision }, NOW).session;
        const ids = s.feedback.filter((item) => item.state === 'queued').map((item) => item.id);
        const { prompt } = composeDelivery(s, ids, NOW, { canvas });
        assert.match(prompt, /The canvas does not change the task's files/);
        assert.match(prompt, /Task files:\n- State: \.copilot-tracking\/rpi-sessions\/2026-10-26\/t-state\.json\n- Research: \.copilot-tracking\/research\/2026-10-26\/t-research\.md\n\nItems:/);
        assert.match(prompt, /Answer to D2 [^\n]+\n {3}File: \.copilot-tracking\/research\/2026-10-26\/t-research\.md\n {3}Chose:/);
        assert.match(prompt, /Suggested edit to research-summary "Summary" \(Research\)\n {3}File: \.copilot-tracking\/research\/2026-10-26\/t-research\.md\n {3}Made against revision 1 of the section\. Change these lines:\n {3}~~~diff\n {3}@@ /);
        assert.match(prompt, /\n {3}\+One more line\.\n {3}~~~/);
        assert.equal(artifactFor(s, 'plan'), s.source.statePath, 'a phase without an artifact falls back to the state file');
        assert.equal(artifactFor(base(), 'research'), null);
    });

    it('accepts comments on the Decisions rows and names their file', () => {
        let s = base();
        s.feedback = [];
        s.source = { kind: 'rpi', statePath: '.copilot-tracking/rpi-sessions/2026-10-26/s/t-state.json', artifacts: { research: '.copilot-tracking/research/2026-10-26/t-research.md', plan: '.copilot-tracking/plans/2026-10-26/t-plan.md', critique: null, changes: null, review: null } };
        assert.deepEqual([findItem(s, 'research-decisions')?.type, phaseOf(s, 'research-decisions'), phaseOf(s, 'plan-decisions')], ['decisions-row', 'research', 'plan']);
        s = createFeedback(s, { kind: 'comment', target: { id: 'research-decisions' }, text: 'Lay the questions out one per line.' }, NOW).session;
        s = createFeedback(s, { kind: 'comment', target: { id: 'plan-decisions' }, text: 'Same for the plan.' }, NOW).session;
        const ids = s.feedback.map((item) => item.id);
        const { prompt } = composeDelivery(s, ids, NOW, { canvas });
        assert.match(prompt, /1\. FB-\d{3}: Comment on research-decisions "Research decisions" \(Research\)\n {3}File: \.copilot-tracking\/research\/2026-10-26\/t-research\.md\n {3}Lay the questions out one per line\./);
        assert.match(prompt, /2\. FB-\d{3}: Comment on plan-decisions "Plan decisions" \(Plan\)\n {3}File: \.copilot-tracking\/plans\/2026-10-26\/t-plan\.md\n {3}Same for the plan\./);
    });

    it('anchors a comment to a part of any view row and sends the part and its quote', () => {
        let s = base();
        s.feedback = [];
        assert.deepEqual([findItem(s, 'risks')?.type, phaseOf(s, 'risks'), phaseOf(s, 'board'), phaseOf(s, 'session-loops')], ['row', 'research', 'implement', 'followup']);
        const quote = '  Quota eviction on\n full devices  ';
        const created = createFeedback(s, { kind: 'comment', target: { id: 'risks', part: 'table row 2', quote }, text: 'Raise this to High.' }, NOW);
        assert.deepEqual(created.result.target, { id: 'risks', type: 'row', phase: 'research', part: 'table row 2', quote: 'Quota eviction on full devices' }, 'the quote keeps single spaces');
        s = created.session;
        const plain = createFeedback(s, { kind: 'comment', target: { id: 'questions' }, text: 'A question is missing.' }, NOW);
        assert.deepEqual(plain.result.target, { id: 'questions', type: 'row', phase: 'research' }, 'a whole-row comment has no part');
        s = plain.session;
        const { prompt } = composeDelivery(s, s.feedback.map((item) => item.id), NOW, { canvas });
        assert.match(prompt, /1\. FB-\d{3}: Comment on risks "Risks and open questions" \(Research\), table row 2\n {3}Quote: "Quota eviction on full devices"\n {3}Raise this to High\./);
        assert.match(prompt, /2\. FB-\d{3}: Comment on questions "Questions" \(Research\)\n {3}A question is missing\./);
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: 'risks', part: 'p'.repeat(81) } }, NOW)), 'invalid_input');
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: 'risks', quote: 'q'.repeat(301) } }, NOW)), 'invalid_input');
        assert.equal(code(() => createFeedback(s, { kind: 'comment', text: 'x', target: { id: 'risks', part: 3 } }, NOW)), 'invalid_input');
    });

    it('groups items from several tasks by task, numbers them through, and asks for the task with each read-back', () => {
        const rpi = (id, status, phase) => {
            const s = base();
            s.feedback = [];
            s.task = { ...s.task, id, title: `Title ${id}` };
            s.session = { ...s.session, status, activePhase: phase };
            s.source = { kind: 'rpi', statePath: `.copilot-tracking/rpi-sessions/2026-10-26/s/${id}-state.json`, artifacts: { research: `.copilot-tracking/research/2026-10-26/${id}-research.md`, plan: null, critique: null, changes: null, review: null } };
            return createFeedback(s, { kind: 'comment', target: { id: 'F1' }, text: `About ${id}` }, NOW).session;
        };
        const child = rpi('child', 'active', 'implement');
        const parent = rpi('parent', 'completed', 'followup');
        const [childId, parentId] = [child.feedback[0].id, parent.feedback[0].id];
        assert.equal(childId, parentId, 'feedback IDs repeat across tasks');
        const both = composeSessionDelivery([{ session: child, ids: [childId] }, { session: parent, ids: [parentId] }], NOW, { canvas, sessionName: 'Session S' });
        assert.match(both.prompt, /^RPI canvas 3WF0 sent 2 items from the user about 2 tasks in session "Session S": 1 for child and 1 for parent\./);
        assert.match(both.prompt, /taskId and feedbackId as listed \(feedback IDs repeat across tasks\)/);
        assert.match(both.prompt, /Items for a completed task are follow-up work for the session/);
        assert.match(both.prompt, /\nTask child: Title child \(current phase: Implement\)\nTask files:\n- State: [^\n]+child-state\.json\n- Research: [^\n]+\nItems:\n1\. FB-\d{3}: Comment on F1/);
        assert.match(both.prompt, /\nTask parent: Title parent \(completed; follow-up work\)\nTask files:\n[^]*?Items:\n2\. FB-\d{3}: Comment on F1/);
        assert.deepEqual(both.parts, [{ taskId: 'child', ids: [childId] }, { taskId: 'parent', ids: [parentId] }]);
        assert.equal(both.displayPrompt, 'RPI canvas 3WF0 sent 2 items: 2 comments.');
        assert.match(composeDelivery(parent, [parentId], NOW, { canvas }).prompt, /This task is completed, so these items are follow-up work for the session/);
        assert.doesNotMatch(composeDelivery(child, [childId], NOW, { canvas }).prompt, /follow-up work/);
        assert.equal(code(() => composeSessionDelivery([{ session: child, ids: [] }], NOW)), 'invalid_input');
        assert.equal(markDelivered(child, [childId], 'send', NOW, { tasks: 2 }).session.feedback[0].deliveredWith, 2);
        assert.equal(markDelivered(child, [childId], 'send', NOW).session.feedback[0].deliveredWith, undefined);
        const overview = feedbackOverview(parent, NOW);
        assert.equal(overview.awaiting, 0);
        assert.deepEqual(overview.pending.map((item) => [item.id, item.kind, item.text, item.phase]), [[parentId, 'comment', 'About parent', 'research']]);
        assert.match(overview.pending[0].label, /^Comment on F1 "[^"]+" \(Research\)$/);
    });

    it('sends an edit saved before suggestions with its text', () => {
        let s = base();
        s = createFeedback(s, { kind: 'comment', text: 'placeholder' }, NOW).session;
        const legacy = s.feedback.at(-1);
        Object.assign(legacy, { kind: 'edit', target: { id: 'research-summary', type: 'section', phase: 'research' }, text: 'Edited "Summary".', section: { id: 'research-summary', title: 'Summary', revision: 2, markdown: 'Old-style text', truncated: false } });
        const { prompt } = composeDelivery(s, [legacy.id], NOW);
        assert.match(prompt, /The user's version of the section:\n {3}~~~markdown\n {3}Old-style text\n {3}~~~/);
    });
});

describe('suggested edits', () => {
    it('records a suggestion without changing the section, and updates it in place', () => {
        const s = base();
        const before = s.sections['research-summary'];
        const first = suggestEdit(s, { sectionId: 'research-summary', markdown: 'New summary', baseRevision: before.revision }, NOW);
        assert.equal(first.result.conflict, false);
        assert.deepEqual(first.session.sections['research-summary'], before, 'the document keeps its text');
        const item = first.session.feedback.find((entry) => entry.id === first.result.feedbackId);
        assert.equal(item.kind, 'edit');
        assert.equal(item.state, 'queued');
        assert.equal(item.section.markdown, 'New summary');
        assert.equal(item.section.revision, before.revision);
        assert.match(item.section.diff, /^@@ -1,\d+ \+1,1 @@\n-/);
        assert.equal(item.section.added, 1);
        assert.match(item.text, /^Suggested edit to "Summary": 1 line added, \d+ removed\.$/);
        assert.equal(pendingSuggestion(first.session, 'research-summary').id, item.id);
        const second = suggestEdit(first.session, { sectionId: 'research-summary', markdown: 'Newer summary', baseRevision: before.revision }, NOW);
        assert.equal(second.result.feedbackId, item.id, 'one pending suggestion per section');
        assert.equal(second.session.feedback.filter((entry) => entry.kind === 'edit').length, 1);
        assert.equal(second.session.feedback.find((entry) => entry.id === item.id).section.markdown, 'Newer summary');
        const taken = takeFeedback(second.session, NOW).result.find((entry) => entry.id === item.id);
        assert.equal(taken.section.markdown, 'Newer summary');
    });

    it('withdraws a pending suggestion that matches the text again, and refuses one being sent', () => {
        const s = base();
        const before = s.sections['research-summary'];
        assert.deepEqual(suggestEdit(s, { sectionId: 'research-summary', markdown: before.markdown, baseRevision: before.revision }, NOW).result, { conflict: false, unchanged: true });
        const made = suggestEdit(s, { sectionId: 'research-summary', markdown: 'Changed', baseRevision: before.revision }, NOW);
        const claimed = claimDelivery(made.session, [made.result.feedbackId], NOW).session;
        assert.equal(code(() => suggestEdit(claimed, { sectionId: 'research-summary', markdown: 'Again', baseRevision: before.revision }, NOW)), 'invalid_state');
        const back = suggestEdit(made.session, { sectionId: 'research-summary', markdown: before.markdown, baseRevision: before.revision }, NOW);
        assert.equal(back.result.withdrawn, made.result.feedbackId);
        assert.equal(back.session.feedback.find((entry) => entry.id === made.result.feedbackId).state, 'dismissed');
        assert.equal(pendingSuggestion(back.session, 'research-summary'), null);
        assert.equal(code(() => suggestEdit(s, { sectionId: 'nope', markdown: 'x', baseRevision: 1 }, NOW)), 'not_found');
    });

    it('caps stored line changes and reports a conflict when the agent changed the section meanwhile', () => {
        const s = base();
        const base0 = s.sections['finding-f3'].revision;
        const agent = agentEditSection(s, { sectionId: 'finding-f3', markdown: 'Agent text' }, NOW).session;
        const result = suggestEdit(agent, { sectionId: 'finding-f3', markdown: 'Mine', baseRevision: base0 }, NOW);
        assert.equal(result.result.conflict, true);
        assert.equal(result.result.section.markdown, 'Agent text');
        assert.equal(result.session, agent);
        const long = Array.from({ length: 1500 }, (_, i) => `line ${i} ${'x'.repeat(20)}`).join('\n');
        const big = suggestEdit(s, { sectionId: 'research-summary', markdown: long, baseRevision: s.sections['research-summary'].revision }, NOW);
        const item = big.session.feedback.find((entry) => entry.id === big.result.feedbackId);
        assert.equal(item.section.diffTruncated, true);
        assert.ok(item.section.diff.length <= 20000);
        assert.equal(item.section.markdown, long);
        assert.match(composeDelivery(big.session, [item.id], NOW).prompt, /The change continues\. get_state with detail "full"/);
    });
});

describe('decisions, tasks, and session', () => {
    it('creates user and agent decisions and validates options', () => {
        let s = base();
        s = upsertDecision(s, { owner: 'user', phase: 'research', title: 'Pick one', question: 'Which?', options: [{ label: 'A' }, { label: 'B' }] }, NOW).session;
        const added = s.decisions.at(-1);
        assert.equal(added.id, 'D5');
        assert.equal(added.status, 'needs-input');
        assert.equal(code(() => upsertDecision(s, { owner: 'agent', title: 'No choice', options: [{ label: 'A' }] }, NOW)), 'invalid_input');
        s = upsertDecision(s, { owner: 'agent', title: 'Chosen', chosen: 'a', options: [{ id: 'a', label: 'A' }] }, NOW).session;
        assert.equal(s.decisions.at(-1).status, 'decided');
        assert.ok(deriveView(s).decidedByAgent.some((d) => d.id === s.decisions.at(-1).id));
    });

    it('moves tasks and tracks the current task', () => {
        let s = buildScenario('implement', Date.parse(NOW));
        s = updateTask(s, { taskId: 'P02-T02', status: 'done' }, NOW).session;
        assert.equal(s.implementation.current, null);
        s = updateTask(s, { taskId: 'P02-T03', status: 'in-progress', note: 'Use the Review tab' }, NOW).session;
        assert.equal(s.implementation.current.taskId, 'P02-T03');
        assert.deepEqual(s.plan.phases[1].tasks[2].guidance, ['Use the Review tab']);
        assert.equal(code(() => updateTask(s, { taskId: 'P99-T99', status: 'done' }, NOW)), 'not_found');
    });

    it('keeps the newest activity lines only', () => {
        let s = buildScenario('implement', Date.parse(NOW));
        for (let i = 0; i < LIMITS.activity + 5; i += 1) {
            s = recordActivity(s, { text: `line ${i}`, kind: 'run' }, NOW).session;
        }
        assert.equal(s.implementation.activity.length, LIMITS.activity);
        assert.equal(s.implementation.activity.at(-1).text, `line ${LIMITS.activity + 4}`);
    });

    it('updates phase and session state', () => {
        const s = updateSession(base(), { activePhase: 'plan', phaseStatus: { research: 'done' }, nextAction: 'Plan it' }, NOW).session;
        assert.equal(s.session.activePhase, 'plan');
        assert.equal(s.phases.plan.status, 'active');
        assert.equal(s.phases.research.status, 'done');
        assert.equal(code(() => updateSession(base(), { activePhase: 'deploy' }, NOW)), 'invalid_input');
    });

    it('loads a saved session that still holds checklists, and creates no checklist items', () => {
        const saved = { ...base(), checklists: { research: [{ id: 'R1', label: 'An old statement', verdict: 'ok' }] } };
        assert.equal(validateSession(saved), saved, 'a session saved with checklists still loads');
        assert.equal(base().checklists, undefined, 'new sessions carry no checklists');
        assert.equal(code(() => createFeedback(base(), { kind: 'checklist', text: 'x' }, NOW)), 'invalid_input');
    });

    it('words and sends a saved item of a kind the canvas no longer creates as a comment', () => {
        const canvas = { handle: '3WF0', instanceId: 'rpi-workflow-demo' };
        let s = createFeedback(base(), { kind: 'comment', target: { id: 'F1' }, text: 'A comment' }, NOW).session;
        const comment = s.feedback.at(-1).id;
        const legacy = { id: 'FB-090', kind: 'checklist', state: 'queued', target: null, phase: 'research', text: 'Research review: all 6 items look good.', createdAt: NOW, updatedAt: NOW, history: [] };
        s = { ...s, feedback: [...s.feedback, legacy] };
        const sent = composeDelivery(s, [comment, legacy.id], NOW, { canvas });
        assert.match(sent.prompt, /\n\d+\. FB-090: Comment on the session\n/);
        assert.equal(sent.displayPrompt, 'RPI canvas 3WF0 sent 2 items: 2 comments.', 'counted with the comments, not as its own kind');
        const entry = feedbackOverview(s, NOW).pending.find((item) => item.id === legacy.id);
        assert.equal(entry.label, 'Comment on the session');
    });
});

describe('validation and traces', () => {
    it('rejects foreign and future documents', () => {
        assert.equal(code(() => validateSession({ format: 'other', version: 1 })), 'storage_corrupt');
        const future = { ...base(), version: 2 };
        assert.equal(code(() => validateSession(future)), 'storage_unsupported');
    });

    it('builds linear traces from explicit links', () => {
        const traces = buildTraces({ links: [['Q1', 'F1'], ['F1', 'D1'], ['D1', 'P01-T01']] });
        assert.deepEqual(traces['D1'], ['Q1', 'F1', 'D1', 'P01-T01']);
        assert.deepEqual(buildTraces({ links: [['A', 'B'], ['B', 'A']] })['A'].length, 2);
    });

    it('traces a change back through its task to the research the task cites', () => {
        const session = {
            research: { questions: [{ id: 'Q1', findings: ['F1'] }], findings: [{ id: 'F1' }, { id: 'F2' }] },
            decisions: [{ id: 'D1', phase: 'research' }, { id: 'plan.D1', phase: 'plan', anchor: { rowId: 'P01-T01' } }],
            plan: { phases: [{ id: 'P01', tasks: [{ id: 'P01-T01', research: ['F1', 'D1', 'F9'] }, { id: 'P01-T02', research: [] }] }] },
            implementation: { changes: [{ id: 'CH-001', taskId: 'P01-T01' }], discoveries: [] },
            review: { findings: [{ id: 'RV-001', related: ['CH-001'] }] },
        };
        const pairs = referenceLinks(session);
        assert.ok(pairs.some(([from, to]) => from === 'F1' && to === 'P01-T01') && pairs.some(([from, to]) => from === 'D1' && to === 'P01-T01'));
        assert.ok(!pairs.some(([from]) => from === 'F9'), 'a citation of an ID the research lacks adds nothing');
        assert.equal(pairs.findIndex(([, to]) => to === 'P01-T01'), pairs.findIndex(([from, to]) => from === 'F1' && to === 'P01-T01'), 'citations lead the task\'s other links');
        assert.deepEqual(buildTraces(session)['CH-001'], ['Q1', 'F1', 'P01-T01', 'CH-001', 'RV-001']);
    });

    it('derives traces from reference fields so recorded work joins them', () => {
        const s = buildScenario('implement', Date.parse(NOW));
        assert.deepEqual(buildTraces(s)['F3'], ['Q2', 'F3', 'D2', 'D5', 'P02-T03'], 'reference fields rebuild the sample chains');
        const reviewed = buildTraces(buildScenario('review', Date.parse(NOW)));
        assert.deepEqual(reviewed['Q1'], ['Q1', 'F1', 'D1', 'P01-T01', 'CH-001', 'RV-004']);
        assert.deepEqual(reviewed['P03-T02'], ['P03-T02', 'CH-007', 'RV-005'], 'the strip follows the longest path onward');
        const added = recordChange(s, { taskId: 'P04-T01', title: 'Status chip announces transitions', behavior: 'Announces Synced once.' }, NOW);
        const traces = buildTraces(added.session);
        assert.deepEqual(traces['P04-T01'].slice(-2), ['P04-T01', added.result.id]);
        assert.ok(traces[added.result.id].includes('P04-T01'));
    });
});
