// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { captureReview } from '../../../../skills/coding-standards/code-review-core/scripts/lib/snapshot.mjs';
import { schedule, updateContext } from '../../../../skills/coding-standards/code-review-core/scripts/lib/operations.mjs';
import {
    dismissFeedback, editFeedback, markTarget, openReview, queueFeedback, readFeedback, recordInterpretation, refresh, requestReviewer, restoreFeedback,
    sendFeedback, takeFeedback, unqueueFeedback,
} from '../lib/model.mjs';

async function fixture(t) {
    const repository = await fs.mkdtemp(path.join(os.tmpdir(), 'hve-review-canvas-'));
    t.after(() => fs.rm(repository, { recursive: true, force: true }));
    const captured = await captureReview(repository, { kind: 'selected', selection: [{ path: 'example.js', startLine: 1, endLine: 1, text: 'result();' }] });
    const statePath = `${captured.relative}/review-state.json`;
    const source = await openReview(repository, { state: statePath });
    const target = { kind: 'file', id: 'file-1', snapshotId: source.state.snapshotId };
    return { repository, captured, source, statePath, target };
}

describe('review model and independent feedback', () => {
    it('reconnects the same review without exposing unsent drafts or changing coverage', async (t) => {
        const { repository, source, statePath, target } = await fixture(t);
        const stateBefore = await fs.readFile(path.join(source.root, 'review-state.json'), 'utf8');
        await editFeedback(source, { revision: 0, kind: 'explain', target, text: 'Explain this result.' });
        const reopened = await openReview(repository, { state: statePath });
        assert.equal((await readFeedback(reopened)).items[0].text, 'Explain this result.');
        assert.deepEqual((await takeFeedback(reopened)).items, []);
        await markTarget(reopened, { revision: 1, target, kind: 'seen', value: true });
        assert.equal(await fs.readFile(path.join(source.root, 'review-state.json'), 'utf8'), stateBefore);
    });

    it('rejects concurrent stale revisions instead of losing edits', async (t) => {
        const { repository, source, statePath, target } = await fixture(t);
        const other = await openReview(repository, { state: statePath });
        const results = await Promise.allSettled([
            editFeedback(source, { revision: 0, kind: 'comment', target, text: 'First view' }),
            editFeedback(other, { revision: 0, kind: 'comment', target, text: 'Second view' }),
        ]);
        assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
        assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
        assert.equal((await readFeedback(source)).items.length, 1);
    });

    it('collects queued feedback by stable ID and requires applied read-back', async (t) => {
        const { source, target } = await fixture(t);
        const draft = await editFeedback(source, { revision: 0, kind: 'investigate', target, text: 'Trace the consumer.' });
        await queueFeedback(source, { revision: draft.revision, ids: [draft.items[0].id] });
        const first = await takeFeedback(source);
        assert.equal(first.items[0].alreadySent, false);
        assert.equal((await takeFeedback(source)).items[0].alreadySent, true);
        await recordInterpretation(source, { feedbackId: first.items[0].id, text: 'Trace requested.', effect: 'Investigation pending', applied: false });
        assert.equal((await takeFeedback(source)).items.length, 1);
        await recordInterpretation(source, { feedbackId: first.items[0].id, text: 'Consumer traced.', effect: 'Evidence recorded' });
        assert.deepEqual((await takeFeedback(source)).items, []);
    });

    it('preserves failed deliveries and never automatically resends admitted items', async (t) => {
        const { source, target } = await fixture(t);
        const draft = await editFeedback(source, { revision: 0, kind: 'comment', target, text: 'Retain this note.' });
        const queued = await queueFeedback(source, { revision: draft.revision, ids: [draft.items[0].id] });
        await assert.rejects(sendFeedback(source, queued.revision), /delivery is unavailable/);
        const feedback = await readFeedback(source);
        assert.equal(feedback.items[0].delivery.status, 'failed');
        assert.equal((await takeFeedback(source)).items[0].text, 'Retain this note.');
        let sends = 0;
        await assert.rejects(sendFeedback(source, feedback.revision, async () => { sends++; }), /No queued/);
        assert.equal(sends, 0);
    });

    it('sends earlier-snapshot items with current ones and labels them stale', async (t) => {
        const { repository, captured, source, target } = await fixture(t);
        const draft = await editFeedback(source, { revision: 0, kind: 'comment', target, text: 'Note on the earlier call.' });
        const queued = await queueFeedback(source, { revision: draft.revision, ids: [draft.items[0].id] });
        await captureReview(repository, { kind: 'selected', selection: [{ path: 'example.js', startLine: 1, endLine: 1, text: 'result(next);' }] }, captured.relative, 0);
        await refresh(source);
        assert.notEqual(source.state.snapshotId, target.snapshotId);
        const current = { ...target, snapshotId: source.state.snapshotId };
        const second = await editFeedback(source, { revision: queued.revision, kind: 'explain', target: current, text: 'Explain the new call.' });
        const both = await queueFeedback(source, { revision: second.revision, ids: [second.items[1].id] });
        const messages = [];
        const sent = await sendFeedback(source, both.revision, async (message) => { messages.push(message); return 'message-1'; });
        assert.equal(sent.sent.length, 2);
        const payload = JSON.parse(messages[0].prompt.slice(messages[0].prompt.indexOf('\n') + 1));
        assert.deepEqual(payload.map((item) => item.stale), [true, false]);
        assert.deepEqual((await readFeedback(source)).items.map((item) => [item.status, item.delivery.status, item.delivery.messageId]),
            [['sent', 'submitted', 'message-1'], ['sent', 'submitted', 'message-1']]);
        assert.deepEqual((await takeFeedback(source)).items.map((item) => item.stale), [true, false]);
    });

    it('detects malformed state and keeps distinct review feedback separate', async (t) => {
        const { repository, source, statePath } = await fixture(t);
        const second = await captureReview(repository, { kind: 'selected', selection: [{ path: 'second.js', startLine: 1, endLine: 1, text: 'second();' }] });
        const other = await openReview(repository, { state: `${second.relative}/review-state.json` });
        assert.notEqual(source.root, other.root);
        assert.equal((await readFeedback(other)).items.length, 0);
        const stateFile = path.join(source.root, 'review-state.json');
        await fs.writeFile(stateFile, '{"schemaVersion":99}');
        await assert.rejects(openReview(repository, { state: statePath }));
        await assert.rejects(refresh(source));
        assert.equal(await fs.readFile(stateFile, 'utf8'), '{"schemaVersion":99}');
    });
    it('passes reasons and the change map to the page and accepts a recorded reason as a target', async (t) => {
        const { captured, source } = await fixture(t);
        const reasons = [{ id: 'R1', title: 'Call the result helper', why: 'The agent reads the selection as a new call.', fileIds: ['file-1'], hunkIds: [] }];
        const changeMap = {
            title: 'After: the example calls result', description: 'One new call.', boxes: [],
            parts: [{ id: 'example', label: 'example.js', box: null, change: 'new', before: null, after: 'Calls result', fileIds: ['file-1'], reasonIds: ['R1'] }], links: [],
        };
        await updateContext(captured, 0, { reasons, changeMap });
        const page = await refresh(source);
        assert.deepEqual(page.reasons, reasons);
        assert.deepEqual(page.changeMap, changeMap);
        const target = { kind: 'reason', id: 'R1', snapshotId: source.state.snapshotId };
        const draft = await editFeedback(source, { revision: 0, kind: 'explain', target, text: 'Why is this one reason?' });
        assert.deepEqual(draft.items[0].target, target);
        await assert.rejects(editFeedback(source, { revision: draft.revision, kind: 'comment', target: { ...target, id: 'R2' }, text: 'Unknown reason.' }), /no longer in this review/);
    });
});

describe('dismissing feedback', () => {
    const statuses = async (source) => (await readFeedback(source)).items.map((item) => [item.status, item.dismissedFrom ?? null]);

    it('dismisses drafts, unsent items, and read-backs, keeps them from the agent, and restores them', async (t) => {
        const { source, target } = await fixture(t);
        let feedback = await editFeedback(source, { revision: 0, kind: 'comment', target, text: 'Maybe later.' });
        const draftId = feedback.items[0].id;
        feedback = await editFeedback(source, { revision: feedback.revision, kind: 'explain', target, text: 'Explain the call.' });
        const queuedId = feedback.items[1].id;
        feedback = await queueFeedback(source, { revision: feedback.revision, ids: [queuedId] });
        feedback = await dismissFeedback(source, { revision: feedback.revision, ids: [draftId, queuedId] });
        assert.deepEqual(await statuses(source), [['dismissed', 'draft'], ['dismissed', 'queued']]);
        assert.deepEqual((await takeFeedback(source)).items, []);
        feedback = await restoreFeedback(source, { revision: feedback.revision, ids: [draftId, queuedId] });
        assert.deepEqual(await statuses(source), [['draft', null], ['queued', null]]);
        const taken = await takeFeedback(source);
        assert.deepEqual(taken.items.map((item) => item.id), [queuedId]);
        await assert.rejects(dismissFeedback(source, { revision: taken.revision, ids: [queuedId] }), /agent already has sent items/);
        const read = await recordInterpretation(source, { feedbackId: queuedId, text: 'Explained the call.', effect: 'Answered in chat' });
        const cleared = await dismissFeedback(source, { revision: read.revision, ids: [queuedId] });
        assert.deepEqual((await statuses(source))[1], ['dismissed', 'interpreted']);
        await restoreFeedback(source, { revision: cleared.revision, ids: [queuedId] });
        assert.deepEqual((await statuses(source))[1], ['interpreted', null]);
    });

    it('takes an unsent item back to a draft and refuses transitions from the wrong state', async (t) => {
        const { source, target } = await fixture(t);
        let feedback = await editFeedback(source, { revision: 0, kind: 'comment', target, text: 'Fix the wording first.' });
        const itemId = feedback.items[0].id;
        await assert.rejects(unqueueFeedback(source, { revision: feedback.revision, ids: [itemId] }), /Only unsent items/);
        await assert.rejects(restoreFeedback(source, { revision: feedback.revision, ids: [itemId] }), /Only dismissed feedback/);
        feedback = await queueFeedback(source, { revision: feedback.revision, ids: [itemId] });
        feedback = await unqueueFeedback(source, { revision: feedback.revision, ids: [itemId] });
        assert.deepEqual(await statuses(source), [['draft', null]]);
        await assert.rejects(dismissFeedback(source, { revision: feedback.revision, ids: ['fb-missing'] }), /no longer exists/);
        await assert.rejects(dismissFeedback(source, { revision: feedback.revision - 1, ids: [itemId] }), /Feedback changed in another view/);
    });

    it('still loads feedback whose reason was removed, refuses to queue it, and lets it be dismissed', async (t) => {
        const { captured, source } = await fixture(t);
        const reasons = [{ id: 'R1', title: 'Call the result helper', why: 'The agent reads the selection as a new call.', fileIds: ['file-1'], hunkIds: [] }];
        const state = await updateContext(captured, 0, { reasons });
        await refresh(source);
        const target = { kind: 'reason', id: 'R1', snapshotId: source.state.snapshotId };
        let feedback = await editFeedback(source, { revision: 0, kind: 'explain', target, text: 'Why this reason?' });
        feedback = await editFeedback(source, { revision: feedback.revision, kind: 'comment', target, text: 'Queued about the reason.' });
        const [draftId, queuedId] = feedback.items.map((item) => item.id);
        feedback = await queueFeedback(source, { revision: feedback.revision, ids: [queuedId] });
        feedback = await markTarget(source, { revision: feedback.revision, target, kind: 'bookmark', value: true });
        await updateContext(captured, state.revision, { reasons: null });
        const page = await refresh(source);
        assert.equal(page.feedback.items.length, 2);
        assert.equal(page.feedback.bookmarks.length, 1);
        feedback = await unqueueFeedback(source, { revision: feedback.revision, ids: [queuedId] });
        await assert.rejects(queueFeedback(source, { revision: feedback.revision, ids: [draftId] }), /no longer in this review/);
        feedback = await dismissFeedback(source, { revision: feedback.revision, ids: [draftId] });
        assert.equal((await readFeedback(source)).items[0].status, 'dismissed');
        assert.deepEqual((await takeFeedback(source)).items, []);
    });

    it('restores a dismissed unsent item as a draft when it can no longer be queued', async (t) => {
        const { captured, source } = await fixture(t);
        const reasons = [{ id: 'R1', title: 'Call the result helper', why: 'The agent reads the selection as a new call.', fileIds: ['file-1'], hunkIds: [] }];
        const state = await updateContext(captured, 0, { reasons });
        await refresh(source);
        const target = { kind: 'reason', id: 'R1', snapshotId: source.state.snapshotId };
        let feedback = await editFeedback(source, { revision: 0, kind: 'comment', target, text: 'About the reason.' });
        const itemId = feedback.items[0].id;
        feedback = await queueFeedback(source, { revision: feedback.revision, ids: [itemId] });
        feedback = await dismissFeedback(source, { revision: feedback.revision, ids: [itemId] });
        await updateContext(captured, state.revision, { reasons: null });
        await restoreFeedback(source, { revision: feedback.revision, ids: [itemId] });
        assert.deepEqual(await statuses(source), [['draft', null]]);
    });
});

describe('adding reviewers', () => {
    const scope = { profile: 'standard', depth: 'standard', mode: 'sweep', rationale: 'Fixture scope.' };

    it('queues one request per reviewer and refuses reviewers that run, are requested, or are unknown', async (t) => {
        const { captured, source } = await fixture(t);
        await schedule(captured, 0, { perspectives: ['functional'], scope });
        await refresh(source);
        let feedback = await requestReviewer(source, { revision: 0, perspective: 'privacy', text: 'Add the Privacy reviewer to this review.' });
        assert.deepEqual(feedback.items.map((item) => [item.kind, item.status, item.target.kind, item.target.id]), [['add-reviewer', 'queued', 'perspective', 'privacy']]);
        await assert.rejects(requestReviewer(source, { revision: feedback.revision, perspective: 'privacy' }), /already requested/);
        await assert.rejects(requestReviewer(source, { revision: feedback.revision, perspective: 'functional' }), /already reviews this change/);
        await assert.rejects(requestReviewer(source, { revision: feedback.revision, perspective: 'telemetry' }), /Unknown reviewer/);
        const review = { kind: 'review', id: source.state.reviewId, snapshotId: source.state.snapshotId };
        await assert.rejects(editFeedback(source, { revision: feedback.revision, kind: 'add-reviewer', target: review, text: 'Add one.' }), /Choose the reviewer/);
        const security = { kind: 'perspective', id: 'security', snapshotId: source.state.snapshotId };
        feedback = await editFeedback(source, { revision: feedback.revision, kind: 'explain', target: security, text: 'Why is security not running?' });
        const collected = await takeFeedback(source);
        assert.deepEqual(collected.items.map((item) => [item.kind, item.target.id]), [['add-reviewer', 'privacy']]);
        feedback = await requestReviewer(source, { revision: collected.revision, perspective: 'performance' });
        assert.equal(feedback.items.at(-1).text, 'Add the performance reviewer to this review.');
        feedback = await dismissFeedback(source, { revision: feedback.revision, ids: [feedback.items.at(-1).id] });
        feedback = await requestReviewer(source, { revision: feedback.revision, perspective: 'performance' });
        assert.equal(feedback.items.filter((item) => item.target.id === 'performance' && item.status === 'queued').length, 1);
    });
});
