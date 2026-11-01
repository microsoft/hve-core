// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { agentEditSection, claimDelivery, createFeedback, markDelivered, markPickedUp, queueForAgent, recordInterpretation, suggestEdit, takeFeedback, transitionFeedback } from '../lib/model.mjs';
import { buildScenario } from '../lib/scenario.mjs';
import { elements, installFakeDom, serialize } from './helpers/fake-dom.mjs';
import { rootSession } from './helpers/rpi-fixture.mjs';

const NOW = '2026-10-26T12:00:00.000Z';
const sample = () => buildScenario('research', Date.parse(NOW));
const html = (nodes) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).map(serialize).join('');
const keyed = (nodes, key) => (Array.isArray(nodes) ? nodes : [nodes]).flat(Infinity).filter(Boolean).flatMap((node) => [node, ...elements(node)]).find((element) => (element.dataset?.key ?? element.getAttribute?.('data-key')) === key) ?? null;
const textOf = (markup) => markup.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ');

let restore;
let components;
let makeContext;
let initialUi;
before(async () => {
    restore = installFakeDom();
    components = await import('../ui/components.mjs');
    ({ makeContext, initialUi } = await import('./helpers/render-views.mjs'));
});
after(() => restore());

function withSuggestion(session, extra = '\n\nOne more line.') {
    const section = session.sections['research-summary'];
    const made = suggestEdit(session, { sectionId: 'research-summary', markdown: `${section.markdown}${extra}`, baseRevision: section.revision }, NOW);
    return { session: made.session, id: made.result.feedbackId, original: section.markdown };
}

describe('steering panel', () => {
    it('lists what is not sent with Review and send, and offers no delivery modes', () => {
        const session = createFeedback(sample(), { kind: 'comment', text: 'Please compare quotas.', target: { id: 'F1' } }, NOW).session;
        const steer = components.steerPanel(makeContext(session, 'research'));
        const out = html(steer);
        assert.match(textOf(out), /Not sent yet \(\d+\)/);
        assert.equal(keyed(steer, 'open-send'), null, 'Review and send is at the top of the canvas, not in the panel');
        assert.doesNotMatch(out, /Deliver feedback by|Attach to my next message|Queue for the agent|Preview what will be sent|Share review with the agent|other loops/);
        assert.match(textOf(out), /Add comment/);
        assert.match(textOf(out), /What you add waits in Your feedback until you send or queue it with Review and send\./);
        const id = session.feedback.at(-1).id;
        assert.match(serialize(keyed(steer, `fb-goto-${id}`)), /title="Go to what FB-\d{3} is about"/);
        assert.match(serialize(keyed(steer, `fb-edit-${id}`)), /title="Change the words of FB-\d{3}"/);
        assert.match(serialize(keyed(steer, `fb-discard-${id}`)), /title="Discard FB-\d{3}"/);
    });

    it('explains how to add input when nothing waits', () => {
        const { session } = rootSession();
        const out = textOf(html(components.steerPanel(makeContext(session, 'research'))));
        assert.match(out, /Nothing waiting to send\. Your answers, comments, and suggested edits collect here until you send or queue them with Review and send at the top of the canvas\./);
    });
});

describe('the second press', () => {
    it('arms on the first press, ignores a press inside the half-second guard, and confirms a deliberate one', () => {
        const { confirmPress, CONFIRM_GUARD_MS } = components;
        const key = 'review-discard-trail-maps-FB-001';
        assert.equal(CONFIRM_GUARD_MS, 500);
        assert.equal(confirmPress(null, key, 1000), 'arm', 'the first press arms');
        const armed = { key, at: 1000 };
        assert.equal(confirmPress(armed, key, 1000), 'ignore', 'the second click of a double click');
        assert.equal(confirmPress(armed, key, 1499), 'ignore', 'a press just inside the guard');
        assert.equal(confirmPress(armed, key, 1500), 'confirm', 'a deliberate second press');
        assert.equal(confirmPress(armed, 'review-discard-trail-maps-FB-002', 1100), 'arm', 'a press on another button arms that one');
    });

    it('holds back a repeated Enter or Space, so a held key presses nothing', () => {
        const pressed = [];
        const ctx = { ui: { confirm: null }, act: { pressConfirm: (key) => pressed.push(key), disarmConfirm: () => {}, confirmBlurred: () => {} } };
        const button = components.confirmButton(ctx, { key: 'k', label: 'Discard', armedLabel: 'Discard FB-001?', onConfirm: () => {} });
        let prevented = 0;
        for (const key of ['Enter', ' ']) {
            for (const listener of button.listeners.keydown ?? []) listener({ key, repeat: true, preventDefault: () => { prevented += 1; }, stopPropagation: () => {} });
        }
        assert.equal(prevented, 2, 'each repeat is held back before the browser turns it into a click');
        for (const listener of button.listeners.keydown ?? []) listener({ key: 'Enter', repeat: false, preventDefault: () => { prevented += 1; }, stopPropagation: () => {} });
        assert.equal(prevented, 2, 'a single key press goes through');
        assert.deepEqual(pressed, [], 'key presses reach the button only as clicks');
    });
});

describe('suggested edits', () => {
    it('show beside the unchanged text with their line changes and actions', () => {
        const { session, id, original } = withSuggestion(sample());
        const out = html(components.sectionBody(makeContext(session, 'research'), 'research-summary'));
        assert.ok(out.includes(serialize(components.sectionBody(makeContext(sample(), 'research'), 'research-summary'))), 'the section renders exactly as before');
        assert.match(textOf(out), /Your suggested edit/);
        assert.match(textOf(out), /Waits in Review and send\. The document changes when the agent applies it\./);
        assert.match(out, /Added: <\/span>/);
        assert.match(textOf(out), /One more line\./);
        assert.match(out, new RegExp(`data-key="edit-suggestion-${id}"`));
        assert.match(out, new RegExp(`data-key="remove-suggestion-${id}"`));
        assert.doesNotMatch(out, /Edited by you/);
        assert.ok(original.length > 0);
    });

    it('note a section that changed since, hide actions while sending, and show the read-back', () => {
        let { session, id } = withSuggestion(sample());
        session = agentEditSection(session, { sectionId: 'research-summary', markdown: 'The agent rewrote this.' }, NOW).session;
        assert.match(textOf(html(components.sectionBody(makeContext(session, 'research'), 'research-summary'))), /This section changed after you made this suggestion/);
        const sending = claimDelivery(session, [id], NOW).session;
        const sendingOut = html(components.sectionBody(makeContext(sending, 'research'), 'research-summary'));
        assert.match(textOf(sendingOut), /Sending/);
        assert.doesNotMatch(sendingOut, /edit-suggestion-/);
        session = markDelivered(session, [id], 'send', NOW).session;
        session = recordInterpretation(session, { feedbackId: id, text: 'Add the line to the summary.', applied: false }, NOW).session;
        const readBack = html(components.sectionBody(makeContext(session, 'research'), 'research-summary'));
        assert.match(textOf(readBack), /Agent understood Add the line to the summary\./);
        assert.match(textOf(readBack), /The agent read it back and has not made the change yet\. Correct it if it misunderstood you\./);
        assert.match(readBack, new RegExp(`data-key="correct-card-${id}"`));
        assert.doesNotMatch(readBack, /Looks right/);
    });

    it('say the file changes for a real session, and show text saved before suggestions', () => {
        const { session } = rootSession();
        const made = suggestEdit(session, { sectionId: 'finding-f1', markdown: 'Clearer wording.', baseRevision: session.sections['finding-f1'].revision }, NOW);
        assert.match(textOf(html(components.sectionBody(makeContext(made.session, 'research'), 'finding-f1'))), /The file changes when the agent applies it\./);
        const legacy = structuredClone(made.session);
        const item = legacy.feedback.find((entry) => entry.id === made.result.feedbackId);
        item.section = { id: 'finding-f1', title: 'T', revision: 2, markdown: 'Typed into the old editor', truncated: false };
        assert.match(textOf(html(components.sectionBody(makeContext(legacy, 'research'), 'finding-f1'))), /Typed into the old editor/);
    });

    it('open in an editor that adds or updates the suggestion', () => {
        const session = sample();
        const ui = initialUi('research');
        ui.editing = { sectionId: 'research-summary', draft: 'x', start: 'x', baseRevision: 1, suggestionId: null, mode: 'write', conflict: null, compare: false, saving: false };
        const added = textOf(html(components.sectionBody(makeContext(session, 'research', ui), 'research-summary')));
        assert.match(added, /Add suggestion/);
        assert.match(added, /Your suggestion waits in Review and send\. The document changes when the agent applies it\./);
        ui.editing.suggestionId = 'FB-009';
        ui.editing.conflict = { markdown: 'New text', revision: 2 };
        const updating = textOf(html(components.sectionBody(makeContext(session, 'research', ui), 'research-summary')));
        assert.match(updating, /Update suggestion/);
        assert.match(updating, /This section changed while you were editing\./);
        assert.match(updating, /Keep my suggestion/);
        assert.match(updating, /Start from the new text/);
    });
});

describe('one kind of typed input', () => {
    it('adds a comment from Add input, with no choice of kind', () => {
        const out = html(components.steerPanel(makeContext(rootSession().session, 'research')));
        assert.doesNotMatch(out, /name="composer-kind"|Kind of input/);
        assert.match(out, /<textarea id="composer-text"[^>]*placeholder="Your comment for the agent: a question, context, or something to research\."/);
        assert.match(textOf(out), /Add comment/);
    });

    it('offers Comment on research rows and Ask for more research on the lanes card', async () => {
        const research = await import('../ui/view-research.mjs');
        const session = sample();
        const out = research.renderView(makeContext(session, 'research')).map(serialize).join('');
        assert.match(out, /data-key="comment-F1"/);
        assert.doesNotMatch(out, /data-key="research-F1"|Research this/);
        assert.match(out, /data-key="ask-research"[^>]*>.*Ask for more research/);
    });

    it('shows saved context and research requests as comments in the margin and in Your feedback', async () => {
        const research = await import('../ui/view-research.mjs');
        const base = sample();
        const saved = [
            { id: 'FB-091', kind: 'context', state: 'queued', target: { id: 'F1', type: 'finding', phase: 'research' }, text: 'Saved context', createdAt: NOW, updatedAt: NOW, history: [] },
            { id: 'FB-092', kind: 'research-request', state: 'queued', target: { id: 'F1', type: 'finding', phase: 'research' }, text: 'Saved research ask', createdAt: NOW, updatedAt: NOW, history: [] },
        ];
        const session = { ...base, feedback: [...base.feedback, ...saved] };
        const view = textOf(research.renderView(makeContext(session, 'research')).map(serialize).join(''));
        assert.match(view, /Saved context/);
        assert.match(view, /Saved research ask/, 'a saved research request is a note, not a requested lane');
        assert.doesNotMatch(view, /Requested by you/);
        const steer = textOf(html(components.steerPanel(makeContext(session, 'research'))));
        assert.match(steer, /Comment about F1 \(Research\) Not sent Go to FB-091 Discard FB-091 Saved context/, 'a comment with Go to and Discard, and no Edit');
        assert.match(steer, /Comment about F1 \(Research\) Not sent Go to FB-092 Discard FB-092 Saved research ask/);
    });
});

describe('steering panel without a checklist', () => {
    it('ends with Add input, and shows a saved checklist item as a comment', () => {
        const legacy = { id: 'FB-090', kind: 'checklist', state: 'queued', target: null, phase: 'research', text: 'Research review: all 6 items look good.', createdAt: NOW, updatedAt: NOW, history: [] };
        const base = sample();
        const session = { ...base, feedback: [...base.feedback, legacy] };
        const steer = components.steerPanel(makeContext(session, 'research'));
        const out = html(steer);
        const sections = [...out.matchAll(/<h3 class="steer-title" id="steer-([a-z]+)"/g)].map((match) => match[1]);
        assert.equal(sections.at(-1), 'add', 'Add input is the last section');
        assert.ok(!sections.includes('checklist'));
        assert.doesNotMatch(out, /data-key="verdict-/);
        assert.match(textOf(out), /Comment Not sent Discard FB-090 Research review: all 6 items look good\./, 'shown as a comment');
        assert.ok(keyed(steer, 'fb-discard-FB-090'));
        assert.equal(keyed(steer, 'fb-edit-FB-090'), null, 'no Edit, since it has nowhere to change');
    });
});

describe('send dialog', () => {
    it('lists each item with Go to, Edit, and Discard, the canvas handle, a message field, and the exact text', () => {
        let session = createFeedback(sample(), { kind: 'comment', text: 'Please compare quotas.', target: { id: 'F1' } }, NOW).session;
        session = withSuggestion(session).session;
        const pending = components.pendingItems(makeContext(session, 'research'));
        const ui = initialUi('research');
        ui.send = { note: 'Start with F1.', preview: { prompt: 'EXACT PROMPT TEXT', displayPrompt: 'x', ids: pending.map((item) => item.id), digest: 'd' }, previewNote: 'Start with F1.', sending: false, error: null };
        const ctx = makeContext(session, 'research', ui);
        const taskId = ctx.data.session.task.id;
        const sheet = components.reviewSheet(ctx);
        const out = html(sheet);
        assert.match(out, /<h2 id="sendSheetTitle" tabindex="-1">/);
        assert.match(textOf(out), /Review and send/);
        assert.match(textOf(out), /Check each one: go to it, change its words, or discard it\./);
        assert.match(out, /<code class="canvas-handle">K7QF<\/code>/);
        assert.match(textOf(out), /Send now gives them to the agent at its next step, even mid-task, as one chat message that starts with “RPI canvas K7QF”\./);
        assert.match(textOf(out), /Queue keeps them here until the agent's next checkpoint: when it changes phase, finishes a task, asks you something, or ends its turn\. You can take them back until then\./);
        assert.match(textOf(out), /Suggested edit to Summary in Research/);
        assert.match(textOf(out), /Comment about F1 \(Research\)/, 'a row about a plain ID names its phase, as other loops\' rows do');
        assert.doesNotMatch(textOf(out), /in Research \(Research\)|for Research \(Research\)/, 'no row names its phase twice');
        assert.match(textOf(out), /2 lines added, 0 removed/);
        for (const item of pending) {
            assert.ok(keyed(sheet, `review-discard-${taskId}-${item.id}`), `Discard ${item.id}`);
            assert.ok(keyed(sheet, `review-goto-${taskId}-${item.id}`), `Go to ${item.id}`);
            assert.ok(keyed(sheet, `review-edit-${taskId}-${item.id}`), `Edit ${item.id}`);
        }
        const suggestion = pending.find((item) => item.kind === 'edit');
        assert.match(serialize(keyed(sheet, `review-edit-${taskId}-${suggestion.id}`)), /title="Edit FB-\d{3} where you made it"/, 'a suggested edit changes in its editor');
        assert.ok(keyed(sheet, 'send-discard-all'), 'Discard all');
        assert.ok(!html(sheet).includes('>null<') && !sheet.includes(null), 'no empty slots reach the dialog');
        assert.match(out, /<textarea id="send-note"[^>]*>Start with F1\.<\/textarea>/);
        assert.match(out, /EXACT PROMPT TEXT/);
        const confirm = keyed(sheet, 'send-confirm');
        assert.equal(confirm.getAttribute('disabled'), null);
        assert.match(serialize(confirm), /<span>Send now<\/span>/);
        assert.equal(confirm.getAttribute('aria-describedby'), 'send-modes');
        const queue = keyed(sheet, 'send-queue');
        assert.match(serialize(queue), /<span>Queue<\/span>/);
        assert.equal(queue.getAttribute('aria-describedby'), 'send-modes');
        assert.equal(queue.getAttribute('disabled'), null);
        ui.send.preview = null;
        ui.send.error = 'Not sent: This host cannot take messages from the canvas.';
        const failed = components.reviewSheet(makeContext(session, 'research', ui));
        assert.equal(keyed(failed, 'send-confirm').getAttribute('disabled'), '');
        assert.equal(keyed(failed, 'send-queue').getAttribute('disabled'), '', 'neither button works without the prepared text');
        assert.match(html(failed), /role="alert" id="send-error"/);
    });

    it('groups items by loop when other loops of the session have unsent items, and says completed loops get follow-up work', () => {
        const session = createFeedback(rootSession().session, { kind: 'comment', text: 'About this loop.', target: { id: 'F1' } }, NOW).session;
        const ctx = makeContext(session, 'research');
        ctx.data.otherTasks = [
            { taskId: 'trail-maps-fixes', title: 'Offline trail maps review fixes', status: 'completed', statePath: 'x', pending: [{ id: 'FB-001', kind: 'comment', about: 'the session', label: 'Comment on the session', text: 'Child note', phase: null, target: null, editable: true }, { id: 'FB-002', kind: 'comment', about: 'F1 "Tiles" (Research)', label: 'Comment on F1', text: 'Second', phase: 'research', target: { id: 'F1' }, editable: true }], awaiting: 0 },
            { taskId: 'quiet', title: 'Quiet loop', status: 'running', statePath: 'y', pending: [], awaiting: 1 },
        ];
        assert.deepEqual(components.sendItems(ctx).map((item) => `${item.taskId}:${item.id}`), [`trail-maps:${components.pendingItems(ctx)[0].id}`, 'trail-maps-fixes:FB-001', 'trail-maps-fixes:FB-002']);
        const sheet = components.reviewSheet(ctx);
        assert.ok(sheet.every((node) => node && !Array.isArray(node)), 'the dialog content is a flat list of nodes, as replaceChildren needs');
        const out = html(sheet);
        assert.match(textOf(out), /has these 3 items from 2 loops of this session for the agent/);
        assert.match(out, /<section class="send-group" aria-labelledby="send-group-trail-maps"><h3 class="send-group-title" id="send-group-trail-maps" tabindex="-1">/);
        assert.match(out, /<section class="send-group" aria-labelledby="send-group-trail-maps-fixes">/);
        assert.doesNotMatch(out, /send-group-quiet/, 'a loop with nothing unsent has no group');
        assert.match(textOf(out), /This loop is completed, so these items go to the agent as follow-up work for the session\./);
        assert.match(textOf(out), /FB-001 Comment about the session/);
        assert.ok(keyed(sheet, 'review-discard-trail-maps-fixes-FB-001'), 'other loops\' items have task-qualified keys');
        assert.ok(keyed(sheet, `review-discard-trail-maps-${components.pendingItems(ctx)[0].id}`), 'so do the shown loop\'s');
        assert.equal(keyed(sheet, 'review-goto-trail-maps-fixes-FB-001'), null, 'an item about the session itself has nowhere to go');
        assert.ok(keyed(sheet, 'review-goto-trail-maps-fixes-FB-002'), 'an item about F1 goes to it in its loop');
        assert.match(out, /aria-label="Items for Offline trail maps review fixes"/);
        const steer = textOf(html(components.steerPanel(ctx)));
        assert.doesNotMatch(steer, /other loops/, 'the steering panel lists only the shown loop');
    });

    it('edits an item\'s words in place, in the dialog or the panel, and keeps a failed edit\'s words', () => {
        const session = createFeedback(rootSession().session, { kind: 'comment', text: 'Old words', target: { id: 'F1' } }, NOW).session;
        const id = session.feedback.at(-1).id;
        const ui = initialUi('research');
        ui.feedbackEdit = { where: 'dialog', taskId: 'trail-maps', id, text: 'New words', saving: false, error: null };
        const sheet = components.reviewSheet(makeContext(session, 'research', ui));
        const out = html(sheet);
        assert.match(out, new RegExp(`<label class="field-label" for="review-edit-trail-maps-${id}-text">Words of ${id}</label><textarea id="review-edit-trail-maps-${id}-text"[^>]*>New words</textarea>`));
        assert.ok(keyed(sheet, `review-edit-trail-maps-${id}-save`) && keyed(sheet, `review-edit-trail-maps-${id}-cancel`));
        assert.equal(keyed(sheet, `review-discard-trail-maps-${id}`), null, 'the editor replaces the row\'s actions');
        assert.doesNotMatch(html(components.steerPanel(makeContext(session, 'research', ui))), /fb-edit-trail-maps/, 'the panel does not open the dialog\'s editor');
        ui.feedbackEdit = { where: 'steer', taskId: 'trail-maps', id, text: 'Kept', saving: false, error: 'text must not be empty.' };
        const steer = html(components.steerPanel(makeContext(session, 'research', ui)));
        assert.match(steer, /aria-invalid="true"/);
        assert.match(textOf(steer), /Not saved: text must not be empty\. Your words are kept\./);
    });

    it('turns Discard into a question that names what goes, for one item or all of them', () => {
        const session = createFeedback(rootSession().session, { kind: 'comment', text: 'One', target: { id: 'F1' } }, NOW).session;
        const id = session.feedback.at(-1).id;
        const ui = initialUi('research');
        ui.confirm = { key: `review-discard-trail-maps-${id}`, at: Date.now() };
        const ctx = makeContext(session, 'research', ui);
        ctx.data.otherTasks = [{ taskId: 'trail-maps-fixes', title: 'Fixes', status: 'running', statePath: 'x', pending: [{ id: 'FB-001', kind: 'comment', about: 'the session', label: 'x', text: 'Two', phase: null, target: null, editable: true }], awaiting: 0 }];
        const armed = keyed(components.reviewSheet(ctx), `review-discard-trail-maps-${id}`);
        assert.match(serialize(armed), new RegExp(`class="btn btn-confirm is-armed"[^>]*><svg[^>]*>.*</svg><span>Discard ${id}\\?</span>`));
        ui.confirm = { key: 'send-discard-all', at: Date.now() };
        assert.match(serialize(keyed(components.reviewSheet(ctx), 'send-discard-all')), /Discard all 2 items from 2 loops\?/);
        ui.confirm = null;
        assert.match(serialize(keyed(components.reviewSheet(ctx), 'send-discard-all')), /<span>Discard all<\/span>/);
    });

    it('marks items queued for the agent, lists them after the rest, and drops Queue once everything is queued', () => {
        let session = createFeedback(rootSession().session, { kind: 'comment', text: 'Waits for me', target: { id: 'F1' } }, NOW).session;
        session = createFeedback(session, { kind: 'comment', text: 'Queued already' }, NOW).session;
        const [mine, queued] = session.feedback.slice(-2).map((item) => item.id);
        session = queueForAgent(session, [queued], NOW).session;
        const ui = initialUi('research');
        ui.send = { note: '', preview: { prompt: 'P', displayPrompt: 'x', ids: [mine, queued], digest: 'd' }, previewNote: '', sending: false, error: null };
        const ctx = makeContext(session, 'research', ui);
        assert.deepEqual(components.pendingItems(ctx).map((item) => item.id), [mine]);
        assert.deepEqual(components.agentQueueItems(ctx).map((item) => item.id), [queued]);
        assert.deepEqual(components.sendItems(ctx).map((item) => item.id), [mine, queued], 'Send now can take queued items too');
        assert.equal(components.waitingCount(ctx), 1, 'the header counts only what waits for you');
        const sheet = components.reviewSheet(ctx);
        const out = textOf(html(sheet));
        assert.match(out, new RegExp(`${queued} Comment Queued for the agent`));
        assert.match(out, /Queue keeps the 1 item not queued yet here until the agent's next checkpoint/);
        ctx.data.otherTasks = [{ taskId: 'trail-maps-fixes', title: 'Fixes', status: 'running', statePath: 'x', pending: [{ id: 'FB-001', kind: 'comment', about: 'the session', label: 'x', text: 'Queued there', phase: null, target: null, editable: true, queuedForAgent: true }, { id: 'FB-002', kind: 'comment', about: 'the session', label: 'x', text: 'Not yet', phase: null, target: null, editable: true }], awaiting: 0 }];
        assert.deepEqual(components.sendItems(ctx).filter((item) => item.taskId === 'trail-maps-fixes').map((item) => item.id), ['FB-002', 'FB-001'], 'another loop lists items not queued yet first');
        assert.equal(components.waitingCount(ctx), 2);
        ctx.data.otherTasks = [];
        session = queueForAgent(session, [mine], NOW).session;
        const all = components.reviewSheet(makeContext(session, 'research', ui));
        assert.equal(keyed(all, 'send-queue'), null, 'nothing is left to queue');
        assert.ok(keyed(all, 'send-confirm'), 'Send now still gives them to the agent sooner');
        assert.match(textOf(html(all)), /Queue is done: everything here waits for the agent's next checkpoint\. Send now gives it to the agent sooner\./);
    });

    it('lists queued items in the steering panel with Take back, between Not sent yet and With the agent', () => {
        let session = createFeedback(rootSession().session, { kind: 'comment', text: 'Mine', target: { id: 'F1' } }, NOW).session;
        session = createFeedback(session, { kind: 'comment', text: 'For the agent', target: { id: 'F1' } }, NOW).session;
        const queued = session.feedback.at(-1).id;
        session = queueForAgent(session, [queued], NOW).session;
        const steer = components.steerPanel(makeContext(session, 'research'));
        const out = textOf(html(steer));
        assert.match(out, /Not sent yet \(1\).*Queued for the agent \(1\) The agent collects these at its next checkpoint: when it changes phase, finishes a task, asks you something, or ends its turn\./);
        assert.match(out, new RegExp(`Queued for the agent .*${queued} .*for the agent's next checkpoint`));
        const take = keyed(steer, `take-back-${queued}`);
        assert.match(serialize(take), /title="Keep FB-\d{3} here instead of giving it to the agent at its next checkpoint"/);
        assert.ok(keyed(steer, `fb-edit-${queued}`) && keyed(steer, `fb-discard-${queued}`), 'a queued item can still change or go');
        assert.match(out, /Your feedback 2/, 'the count includes queued items');
        const onlyQueued = queueForAgent(session, [session.feedback.at(-2).id], NOW).session;
        assert.match(textOf(html(components.steerPanel(makeContext(onlyQueued, 'research')))), /Nothing waits for you to send\. What you queued is below\./);
    });

    it('shows where each item is and since when, and keeps read-backs in Feedback history with Correct this', () => {
        let session = rootSession().session;
        const add = (text) => {
            const made = createFeedback(session, { kind: 'comment', text, target: { id: 'F1' } }, NOW);
            session = made.session;
            return made.result.id;
        };
        const collected = add('Collected');
        session = takeFeedback(session, NOW).session;
        const [notSent, queued, sent, picked, applied, early, corrected] = ['Not sent', 'Queued', 'Sent', 'Picked up', 'Applied', 'Early', 'Corrected'].map(add);
        session = queueForAgent(session, [queued], NOW).session;
        session = markDelivered(session, [sent, picked, applied, early, corrected], 'send', NOW, { messageId: 'm1' }).session;
        session = markPickedUp(session, [picked], { at: NOW, how: 'steering' }, NOW).session;
        session = recordInterpretation(session, { feedbackId: applied, text: 'Done as asked.' }, NOW).session;
        session = recordInterpretation(session, { feedbackId: early, text: 'Will do.', applied: false }, NOW).session;
        session = recordInterpretation(session, { feedbackId: corrected, text: 'Done.' }, NOW).session;
        const fix = transitionFeedback(session, corrected, 'corrected', { correction: 'Not that.' }, NOW);
        session = fix.session;
        const ctx = makeContext(session, 'research');
        const stage = (id) => {
            const found = components.stageOf(ctx, session.feedback.find((item) => item.id === id));
            return [found.badge.label, found.words];
        };
        assert.deepEqual(stage(notSent), ['Not sent', null]);
        assert.deepEqual(stage(queued), ['Queued for the agent', "for the agent's next checkpoint"]);
        assert.deepEqual(stage(sent), ['Sent', 'as a chat message']);
        assert.deepEqual(stage(picked), ['The agent has it', 'at its next step']);
        assert.deepEqual(stage(collected), ['The agent has it', 'collected from the canvas']);
        assert.deepEqual(stage(early), ['Read back', 'the change is not made yet']);
        assert.deepEqual(stage(applied), ['Read back', null]);
        assert.deepEqual(stage(corrected), ['Corrected', `your correction is ${fix.result.id}`]);
        const steer = components.steerPanel(ctx);
        const out = textOf(html(steer));
        assert.match(out, /With the agent \(4\)/, 'sent, picked up, collected, and read back but not made yet');
        assert.match(out, /Feedback history \(2\)/);
        assert.ok(keyed(steer, `correct-row-${applied}`) && keyed(steer, `correct-row-${early}`), 'read-backs can be corrected, in the history too');
        assert.equal(keyed(steer, `correct-row-${sent}`), null, 'not before the agent reads it back');
        assert.doesNotMatch(out, /Looks right|Check how the agent read/);
    });

    it('shows a composer failure beside the text it keeps', () => {
        const ui = initialUi('research');
        ui.composer = { text: 'Keep me', anchor: 'research-decisions', error: 'No item research-decisions exists in this session.' };
        const out = html(components.steerPanel(makeContext(rootSession().session, 'research', ui)));
        assert.match(out, /<textarea id="composer-text"[^>]*aria-invalid="true"[^>]*aria-describedby="composer-error"[^>]*>Keep me<\/textarea>/);
        assert.match(textOf(out), /Not added: No item research-decisions exists in this session\. Your text is kept\./);
    });

    it('explains how to add input when nothing waits', () => {
        const { session } = rootSession();
        const out = textOf(html(components.reviewSheet(makeContext(session, 'research'))));
        assert.match(out, /Canvas K7QF has nothing waiting to send\./);
        assert.match(out, /Add something first, then review and send it all here:/);
        assert.match(out, /Comment on a row, or suggest an edit to its text\./);
    });
});
