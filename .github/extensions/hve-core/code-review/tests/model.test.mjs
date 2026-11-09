// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { captureReview } from '../../../../skills/coding-standards/code-review-core/scripts/lib/snapshot.mjs';
import { updateContext } from '../../../../skills/coding-standards/code-review-core/scripts/lib/operations.mjs';
import { editFeedback, markTarget, openReview, queueFeedback, readFeedback, recordInterpretation, refresh, sendFeedback, takeFeedback } from '../lib/model.mjs';

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
        await assert.rejects(editFeedback(source, { revision: draft.revision, kind: 'comment', target: { ...target, id: 'R2' }, text: 'Unknown reason.' }), /not present/);
    });
});
