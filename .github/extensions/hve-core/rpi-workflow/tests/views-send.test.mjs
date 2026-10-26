// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { agentEditSection, claimDelivery, createFeedback, markChecklist, markDelivered, recordInterpretation, suggestEdit } from '../lib/model.mjs';
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
        assert.ok(keyed(steer, 'open-send'), 'Review and send opens the dialog');
        assert.equal(keyed(steer, 'open-send').getAttribute('aria-haspopup'), 'dialog');
        assert.doesNotMatch(out, /Deliver feedback by|Attach to my next message|Queue for the agent|Preview what will be sent|Share review with the agent/);
        assert.match(textOf(out), /Add comment/);
        assert.match(textOf(out), /What you add waits in Your feedback until you choose Send to agent\./);
        assert.match(out, /aria-label="Remove FB-\d{3}"|title="Remove FB-\d{3}"/);
    });

    it('explains how to add input when nothing waits', () => {
        const { session } = rootSession();
        const out = textOf(html(components.steerPanel(makeContext(session, 'research'))));
        assert.match(out, /Nothing waiting to send\. Your answers, comments, suggested edits, and checklist reviews collect here until you choose Send to agent/);
    });
});

describe('suggested edits', () => {
    it('show beside the unchanged text with their line changes and actions', () => {
        const { session, id, original } = withSuggestion(sample());
        const out = html(components.sectionBody(makeContext(session, 'research'), 'research-summary'));
        assert.ok(out.includes(serialize(components.sectionBody(makeContext(sample(), 'research'), 'research-summary'))), 'the section renders exactly as before');
        assert.match(textOf(out), /Your suggested edit/);
        assert.match(textOf(out), /Waits for Send to agent\. The document changes when the agent applies it\./);
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
        session = recordInterpretation(session, { feedbackId: id, text: 'Add the line to the summary.' }, NOW).session;
        const readBack = html(components.sectionBody(makeContext(session, 'research'), 'research-summary'));
        assert.match(textOf(readBack), /Agent understood Add the line to the summary\./);
        assert.match(readBack, new RegExp(`data-key="looks-right-card-${id}"`));
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
        assert.match(added, /Your suggestion waits for Send to agent\. The document changes when the agent applies it\./);
        ui.editing.suggestionId = 'FB-009';
        ui.editing.conflict = { markdown: 'New text', revision: 2 };
        const updating = textOf(html(components.sectionBody(makeContext(session, 'research', ui), 'research-summary')));
        assert.match(updating, /Update suggestion/);
        assert.match(updating, /This section changed while you were editing\./);
        assert.match(updating, /Keep my suggestion/);
        assert.match(updating, /Start from the new text/);
    });
});

describe('review checklist', () => {
    it('explains what reaches the agent and takes verdicts with fixed labels', () => {
        const session = sample();
        const steer = components.steerPanel(makeContext(session, 'research'));
        const out = html(steer);
        assert.match(textOf(out), /Optional questions for reviewing the research\. Mark each one as you read\. Items that need work, with your notes, go to the agent with your next send, and so does an all-good list\. Other marks only track your progress\./);
        assert.match(textOf(out), /2 of 6 reviewed\. Nothing here goes to the agent yet\./);
        assert.equal((out.match(/aria-pressed="true"/g) ?? []).length, 2);
        const okToggle = keyed(steer, 'verdict-research-R1-ok');
        assert.equal(okToggle.getAttribute('aria-pressed'), 'true');
        assert.match(serialize(okToggle), /Looks good/);
        assert.equal(keyed(steer, 'verdict-research-R1-needs-work').getAttribute('aria-pressed'), 'false');
        assert.doesNotMatch(out, /What needs work\?/);
    });

    it('opens a note for Needs work and says the review goes with the next send', () => {
        const session = markChecklist(sample(), { phase: 'research', itemId: 'R3', verdict: 'needs-work', note: 'Add a native app option.' }, NOW).session;
        const out = html(components.steerPanel(makeContext(session, 'research')));
        assert.match(textOf(out), /3 of 6 reviewed, 1 needs work\. Your review goes with your next send\./);
        assert.match(out, /<label class="field-label" for="check-note-research-R3">What needs work\? \(optional\)<\/label><textarea id="check-note-research-R3"[^>]*>Add a native app option\.<\/textarea>/);
        assert.match(out, /role="group" aria-labelledby="check-research-R3"/);
    });
});

describe('send dialog', () => {
    it('lists each item with Show and Remove, the canvas handle, a message field, and the exact text', () => {
        let session = createFeedback(sample(), { kind: 'comment', text: 'Please compare quotas.', target: { id: 'F1' } }, NOW).session;
        session = withSuggestion(session).session;
        session = markChecklist(session, { phase: 'research', itemId: 'R3', verdict: 'needs-work' }, NOW).session;
        const pending = components.pendingItems(makeContext(session, 'research'));
        const ui = initialUi('research');
        ui.send = { note: 'Start with F1.', preview: { prompt: 'EXACT PROMPT TEXT', displayPrompt: 'x', ids: pending.map((item) => item.id), digest: 'd' }, previewNote: 'Start with F1.', sending: false, error: null };
        const sheet = components.sendSheet(makeContext(session, 'research', ui));
        const out = html(sheet);
        assert.match(out, /<h2 id="sendSheetTitle" tabindex="-1">/);
        assert.match(textOf(out), /Send to the agent/);
        assert.match(out, /<code class="canvas-handle">K7QF<\/code>/);
        assert.match(textOf(out), /one message that starts with “RPI canvas K7QF”/);
        assert.match(textOf(out), /Review checklist for Research/);
        assert.match(textOf(out), /Suggested edit to Summary in Research/);
        assert.match(textOf(out), /2 lines added, 0 removed/);
        for (const item of pending) {
            assert.ok(keyed(sheet, `send-remove-${item.id}`), `Remove ${item.id}`);
        }
        assert.ok(keyed(sheet, `send-show-${pending[0].id}`));
        assert.ok(!html(sheet).includes('>null<') && !sheet.includes(null), 'no empty slots reach the dialog');
        assert.match(out, /<textarea id="send-note"[^>]*>Start with F1\.<\/textarea>/);
        assert.match(out, /EXACT PROMPT TEXT/);
        const confirm = keyed(sheet, 'send-confirm');
        assert.equal(confirm.getAttribute('disabled'), null);
        assert.match(serialize(confirm), new RegExp(`Send ${pending.length} items`));
        ui.send.preview = null;
        ui.send.error = 'Not sent: This host cannot take messages from the canvas.';
        const failed = components.sendSheet(makeContext(session, 'research', ui));
        assert.equal(keyed(failed, 'send-confirm').getAttribute('disabled'), '');
        assert.match(html(failed), /role="alert" id="send-error"/);
    });

    it('explains how to add input when nothing waits', () => {
        const { session } = rootSession();
        const out = textOf(html(components.sendSheet(makeContext(session, 'research'))));
        assert.match(out, /Canvas K7QF has nothing waiting to send\./);
        assert.match(out, /Add something first, then send it all here:/);
        assert.match(out, /Comment on a row, or suggest an edit to its text\./);
    });
});
