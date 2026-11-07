// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { check, object } from '../../../../skills/coding-standards/code-review-core/scripts/lib/model.mjs';
import { openReview, recordInterpretation, takeFeedback, TARGET_KINDS, validateTarget } from './model.mjs';

const schema = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });
export const OPEN_SCHEMA = schema({ state: { type: 'string', description: 'Workspace-relative path to this review\'s review-state.json.' } }, ['state']);
export const ACTIONS = [
    { name: 'get_state', description: 'Summarize review identity, actual coverage, source warnings, and feedback awaiting the agent; private drafts are not returned.', inputSchema: schema({}) },
    { name: 'show_review', description: 'Connect this panel to an explicit review state in its workspace; existing review data is preserved.', inputSchema: OPEN_SCHEMA },
    { name: 'focus_item', description: 'Show an area, captured file/hunk, finding, or provider comment without changing coverage or disposition.', inputSchema: schema({ kind: { type: 'string', enum: TARGET_KINDS }, id: { type: 'string' } }, ['kind', 'id']) },
    { name: 'take_feedback', description: 'Collect explicitly queued feedback and return sent items awaiting read-back. Deduplicate by review and item ID. Unsent drafts remain private.', inputSchema: schema({ checkpoint: { type: 'boolean', description: 'True at dispatch, completion, and decision checkpoints.' } }) },
    { name: 'record_interpretation', description: 'Read back a sent item after applying it, or use applied=false while the change is still pending. This never updates review coverage or human sign-off.', inputSchema: schema({ feedbackId: { type: 'string' }, text: { type: 'string' }, effect: { type: 'string' }, applied: { type: 'boolean' } }, ['feedbackId', 'text', 'effect']) },
];

export async function invokeAction(registry, context) {
    const record = registry.get(context.instanceId);
    check(record, 'Open this canvas instance before invoking actions.', 'not_found');
    const input = context.input ?? {};
    if (context.actionName === 'show_review') {
        const next = await openReview(context.session?.workingDirectory ?? record.source.repository, input);
        record.source = next;
        record.focus = null;
        await record.server.reset();
    } else if (context.actionName === 'focus_item') {
        object(input, ['kind', 'id'], 'focus');
        const state = await record.server.state();
        check(!state.stale, 'Refresh the invalid source before focusing evidence.', 'stale_target');
        record.focus = validateTarget({ ...input, snapshotId: state.snapshotId }, record.source);
        record.focusRevision = (record.focusRevision ?? 0) + 1;
        record.server.notify();
    } else if (context.actionName === 'take_feedback') {
        object(input, [], 'feedback checkpoint', ['checkpoint']);
        if (input.checkpoint !== undefined) check(typeof input.checkpoint === 'boolean', 'checkpoint must be boolean.', 'invalid_input');
        const result = await takeFeedback(record.source);
        record.server.notify();
        return { reviewId: record.source.state.reviewId, snapshotId: record.source.state.snapshotId, ...result };
    } else if (context.actionName === 'record_interpretation') {
        const feedback = await recordInterpretation(record.source, input);
        record.server.notify();
        return { reviewId: record.source.state.reviewId, revision: feedback.revision, feedbackId: input.feedbackId, applied: input.applied !== false };
    } else {
        check(context.actionName === 'get_state', 'Unknown canvas action.', 'invalid_input');
        object(input, [], 'state request');
    }
    const state = await record.server.state();
    return {
        instanceId: context.instanceId, reviewId: state.reviewId, snapshotId: state.snapshotId, revision: state.revision,
        state: state.statePath, status: state.status, outcome: state.outcome, stale: state.stale, warning: state.warning, focus: record.focus,
        areas: state.areas.map((area) => ({ id: area.id, title: area.title, status: area.status, perspectives: area.work.map((work) => ({ id: work.id, perspective: work.perspective, status: work.status })) })),
        files: state.files.slice(0, 50).map((file) => ({ id: file.id, path: file.newPath ?? file.oldPath, status: file.status })),
        findings: state.findings.slice(0, 50).map((finding) => ({ id: finding.id, severity: finding.severity, disposition: finding.disposition })),
        totals: { files: state.files.length, findings: state.findings.length, summaryLimit: 50 },
        feedback: { revision: state.feedback.revision, queued: state.feedback.items.filter((item) => item.status === 'queued').length, awaitingInterpretation: state.feedback.items.filter((item) => item.status === 'sent').map((item) => item.id) },
    };
}
