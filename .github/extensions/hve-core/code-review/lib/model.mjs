// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { areaStatus, check, id, object, text } from '../../../../skills/coding-standards/code-review-core/scripts/lib/model.mjs';
import { exists, loadReview, readJson, readText, reviewRoot, withLock, writeJson } from '../../../../skills/coding-standards/code-review-core/scripts/lib/storage.mjs';

export { ReviewError } from '../../../../skills/coding-standards/code-review-core/scripts/lib/model.mjs';
export const CANVAS_ID = 'hve-core-code-review';
export const FEEDBACK_KINDS = ['review-next', 'explain', 'investigate', 'dispute', 'comment', 'draft'];
export const TARGET_KINDS = ['review', 'area', 'reason', 'file', 'hunk', 'finding', 'comment'];
export const MAX_FEEDBACK_TEXT = 16000;

export async function openReview(workspace, input) {
    object(input, ['state'], 'canvas input');
    check(typeof workspace === 'string' && path.isAbsolute(workspace), 'The host must supply the workspace working directory.', 'workspace_unavailable');
    check(typeof input.state === 'string' && input.state.endsWith('/review-state.json'), 'Open an explicit review-state.json.', 'invalid_input');
    const location = await reviewRoot(workspace, input.state.slice(0, -'/review-state.json'.length));
    const review = await loadReview(location);
    const source = { ...location, statePath: input.state, ...review };
    await readFeedback(source);
    return source;
}

export function validateTarget(target, source, allowStale = false) {
    object(target, ['kind', 'id', 'snapshotId'], 'feedback target');
    check(TARGET_KINDS.includes(target.kind), 'Unknown focus target kind.', 'invalid_input');
    text(target.id, 'target ID');
    check(target.id.length <= 512, 'Target ID is too long.', 'invalid_input');
    id(target.snapshotId, 'target snapshot');
    if (allowStale && target.snapshotId !== source.state.snapshotId) return target;
    check(target.snapshotId === source.state.snapshotId, 'The target belongs to an older snapshot; select current evidence.', 'stale_target');
    const candidates = {
        review: [source.state.reviewId],
        area: source.state.areas.map((area) => area.id),
        reason: (source.state.reasons ?? []).map((reason) => reason.id),
        file: source.snapshot.files.map((file) => file.id),
        hunk: source.snapshot.files.flatMap((file) => file.hunks.map((hunk) => hunk.id)),
        finding: source.state.findings.map((finding) => finding.id),
        comment: source.snapshot.discussion.items.map((item) => item.id),
    };
    check(candidates[target.kind].includes(target.id), 'Target is not present in the current review.', 'not_found');
    return target;
}

function emptyFeedback(source) {
    return { format: 'hve-code-review.feedback', schemaVersion: 1, reviewId: source.state.reviewId, revision: 0, items: [], bookmarks: [], seen: [] };
}

export function validateFeedback(value, source) {
    object(value, ['format', 'schemaVersion', 'reviewId', 'revision', 'items', 'bookmarks', 'seen'], 'feedback record');
    check(value.format === 'hve-code-review.feedback' && value.schemaVersion === 1, 'Unsupported feedback format; the record was preserved.', 'unsupported_schema');
    check(value.reviewId === source.state.reviewId, 'Feedback belongs to another review.', 'identity_mismatch');
    check(Number.isSafeInteger(value.revision) && value.revision >= 0, 'Invalid feedback revision.');
    check(Array.isArray(value.items), 'Feedback items must be an array.');
    const known = new Set();
    for (const item of value.items) {
        object(item, ['id', 'kind', 'target', 'text', 'status', 'delivery', 'interpretation', 'updatedAt'], 'feedback item');
        id(item.id);
        check(!known.has(item.id), 'Duplicate feedback ID.');
        known.add(item.id);
        check(FEEDBACK_KINDS.includes(item.kind), 'Unknown feedback kind.');
        validateTarget(item.target, source, true);
        text(item.text, 'feedback text', item.status === 'draft');
        check(item.text.length <= MAX_FEEDBACK_TEXT, 'Feedback text is too long.');
        check(['draft', 'queued', 'sent', 'interpreted'].includes(item.status), 'Unknown feedback state.');
        if (item.delivery !== null) {
            object(item.delivery, ['status', 'messageId', 'error'], 'delivery');
            check(['pending', 'submitted', 'collected', 'failed'].includes(item.delivery.status), 'Unknown delivery state.');
            if (item.delivery.messageId !== null) text(item.delivery.messageId, 'delivery message ID');
            if (item.delivery.error !== null) text(item.delivery.error, 'delivery error');
        }
        if (item.interpretation !== null) {
            object(item.interpretation, ['text', 'effect', 'applied'], 'interpretation');
            text(item.interpretation.text, 'interpretation');
            text(item.interpretation.effect, 'effect');
            check(typeof item.interpretation.applied === 'boolean', 'applied must be boolean.');
        }
        check(typeof item.updatedAt === 'string' && Number.isFinite(Date.parse(item.updatedAt)), 'Invalid feedback time.');
        if (item.status === 'interpreted') check(item.interpretation?.applied, 'Interpreted feedback requires an applied read-back.');
    }
    for (const key of ['bookmarks', 'seen']) {
        check(Array.isArray(value[key]), `${key} must be an array.`);
        value[key].forEach((target) => validateTarget(target, source, true));
    }
    return value;
}

export async function refresh(source) {
    const review = await loadReview(source);
    const current = { ...source, ...review };
    const feedback = await readFeedback(current);
    Object.assign(source, review);
    return { ...view(source), feedback };
}

export async function readFeedback(source) {
    if (!await exists(source.root, 'feedback.json')) return emptyFeedback(source);
    return validateFeedback(await readJson(source.root, 'feedback.json'), source);
}

export function view(source) {
    const { state, snapshot } = source;
    return {
        reviewId: state.reviewId, snapshotId: state.snapshotId, revision: state.revision, statePath: source.statePath,
        status: state.status, outcome: state.outcome, scope: state.scope ?? null, target: snapshot.target, capturedAt: snapshot.capturedAt,
        areas: state.areas.map((area) => ({ ...area, status: areaStatus(state, area.id), work: state.workItems.filter((work) => work.areaIds.includes(area.id)) })),
        workItems: state.workItems, files: snapshot.files, findings: state.findings, discussion: snapshot.discussion, metadata: snapshot.metadata ?? null,
        limitations: [...state.limitations, ...snapshot.omissions.map((summary, index) => ({ id: `omission-${index}`, summary, blocking: false }))],
        context: state.context ?? null, artifacts: state.artifacts, reasons: state.reasons ?? null, changeMap: state.changeMap ?? null,
    };
}

export async function signature(source) {
    const files = ['review-state.json', 'feedback.json', source.state.snapshotPath];
    const values = [];
    for (const file of files) {
        try {
            const stat = await fs.lstat(path.join(source.root, file));
            values.push(`${stat.ino}:${stat.size}:${stat.mtimeMs}`);
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
            values.push('missing');
        }
    }
    return values.join('|');
}

export async function evidenceFor(source, fileId, expectedSnapshot = source.state.snapshotId) {
    await refresh(source);
    check(expectedSnapshot === source.state.snapshotId, 'Evidence selection belongs to an older snapshot.', 'stale_target');
    const file = source.snapshot.files.find((entry) => entry.id === fileId);
    check(file, 'Unknown captured file.', 'not_found');
    if (file.omission) return { fileId, omission: file.omission, lines: [] };
    const evidence = await readJson(source.root, file.evidencePath);
    object(evidence, ['schemaVersion', 'snapshotId', 'fileId', 'lines'], 'file evidence');
    check(evidence.schemaVersion === 1 && evidence.snapshotId === source.snapshot.snapshotId && evidence.fileId === fileId, 'Captured evidence identity changed.', 'invalid_evidence');
    check(Array.isArray(evidence.lines), 'Invalid captured lines.', 'invalid_evidence');
    for (const line of evidence.lines) {
        object(line, ['hunkId', 'kind', 'oldLine', 'newLine', 'text'], 'diff line');
        const hunk = file.hunks.find((entry) => entry.id === line.hunkId);
        check(hunk && ['add', 'delete', 'context'].includes(line.kind), 'Invalid captured hunk.', 'invalid_evidence');
        text(line.text, 'source text', true);
        for (const side of ['old', 'new']) {
            const number = line[`${side}Line`];
            const absent = (side === 'old' && line.kind === 'add') || (side === 'new' && line.kind === 'delete');
            check(absent ? number === null : Number.isSafeInteger(number) && number >= hunk[`${side}Start`] && number < hunk[`${side}Start`] + hunk[`${side}Count`],
                'Diff line lies outside the captured hunk.', 'invalid_evidence');
        }
    }
    return evidence;
}

export async function reportFor(source) {
    await refresh(source);
    check(await exists(source.root, 'review.md'), 'No saved report exists yet.', 'not_found');
    return { reviewId: source.state.reviewId, text: await readText(source.root, 'review.md') };
}

async function changeFeedback(source, revision, action) {
    check(Number.isSafeInteger(revision) && revision >= 0, 'A feedback revision is required.', 'invalid_input');
    return withLock(source.root, 'feedback.json', async () => {
        await refresh(source);
        const feedback = await readFeedback(source);
        check(feedback.revision === revision, 'Feedback changed in another view. Reload before saving; your text is still in the editor.', 'revision_conflict');
        await action(feedback);
        feedback.revision++;
        validateFeedback(feedback, source);
        await writeJson(source.root, 'feedback.json', feedback);
        return feedback;
    });
}

export async function editFeedback(source, request) {
    object(request, ['revision', 'kind', 'target', 'text'], 'feedback edit', ['id']);
    return changeFeedback(source, request.revision, (feedback) => {
        validateTarget(request.target, source);
        check(FEEDBACK_KINDS.includes(request.kind), 'Unknown feedback kind.', 'invalid_input');
        text(request.text, 'feedback text', true);
        check(request.text.length <= MAX_FEEDBACK_TEXT, 'Feedback exceeds the text limit.', 'invalid_input');
        const existing = request.id ? feedback.items.find((item) => item.id === request.id) : null;
        if (request.id) check(existing?.status === 'draft', 'Only an existing draft can be edited.', 'invalid_transition');
        const item = existing ?? { id: `fb-${randomUUID()}`, status: 'draft', delivery: null, interpretation: null };
        Object.assign(item, { kind: request.kind, target: request.target, text: request.text, updatedAt: new Date().toISOString() });
        if (!existing) feedback.items.push(item);
    });
}

export async function queueFeedback(source, request) {
    object(request, ['revision', 'ids'], 'feedback queue');
    check(Array.isArray(request.ids) && request.ids.length > 0, 'Select feedback to queue.', 'invalid_input');
    return changeFeedback(source, request.revision, (feedback) => {
        for (const itemId of request.ids) {
            const item = feedback.items.find((entry) => entry.id === itemId);
            check(item?.status === 'draft', 'Only drafts can be queued.', 'invalid_transition');
            validateTarget(item.target, source);
            text(item.text, 'queued feedback');
            item.status = 'queued';
            item.updatedAt = new Date().toISOString();
        }
    });
}

export async function markTarget(source, request) {
    object(request, ['revision', 'target', 'kind', 'value'], 'personal marker');
    check(['bookmark', 'seen'].includes(request.kind) && typeof request.value === 'boolean', 'Choose a bookmark or seen marker.', 'invalid_input');
    return changeFeedback(source, request.revision, (feedback) => {
        validateTarget(request.target, source);
        const field = request.kind === 'bookmark' ? 'bookmarks' : 'seen';
        feedback[field] = feedback[field].filter((target) => JSON.stringify(target) !== JSON.stringify(request.target));
        if (request.value) feedback[field].push(request.target);
    });
}

/** Sent means available to the agent; only its applied interpretation records action. */
export async function takeFeedback(source) {
    await refresh(source);
    const feedback = await readFeedback(source);
    const alreadySent = new Set(feedback.items.filter((item) => item.status === 'sent').map((item) => item.id));
    const pending = feedback.items.filter((item) => ['queued', 'sent'].includes(item.status));
    if (!pending.length) return { revision: feedback.revision, items: [] };
    const changed = pending.some((item) => item.status === 'queued')
        ? await changeFeedback(source, feedback.revision, (value) => {
            for (const item of value.items.filter((entry) => entry.status === 'queued')) {
                item.status = 'sent';
                item.delivery = { status: 'collected', messageId: null, error: null };
                item.updatedAt = new Date().toISOString();
            }
        }) : feedback;
    return { revision: changed.revision, items: changed.items.filter((item) => item.status === 'sent').map((item) => ({ ...item, alreadySent: alreadySent.has(item.id), stale: item.target.snapshotId !== source.state.snapshotId })) };
}

export async function recordInterpretation(source, request) {
    object(request, ['feedbackId', 'text', 'effect'], 'read-back', ['applied']);
    await refresh(source);
    const feedback = await readFeedback(source);
    return changeFeedback(source, feedback.revision, (value) => {
        const item = value.items.find((entry) => entry.id === request.feedbackId);
        check(item && ['sent', 'interpreted'].includes(item.status), 'Read-back requires sent feedback.', 'invalid_transition');
        text(request.text, 'interpretation');
        text(request.effect, 'effect');
        if (request.applied !== undefined) check(typeof request.applied === 'boolean', 'applied must be boolean.');
        item.interpretation = { text: request.text, effect: request.effect, applied: request.applied !== false };
        item.status = request.applied === false ? 'sent' : 'interpreted';
        item.updatedAt = new Date().toISOString();
    });
}

export async function sendFeedback(source, revision, deliver) {
    let items = [];
    const stale = (target) => target.snapshotId !== source.state.snapshotId;
    await changeFeedback(source, revision, (feedback) => {
        items = feedback.items.filter((item) => item.status === 'queued');
        check(items.length > 0, 'No queued feedback to send.', 'invalid_transition');
        for (const item of items) {
            validateTarget(item.target, source, true);
            item.status = 'sent';
            item.delivery = { status: 'pending', messageId: null, error: null };
        }
    });
    let receipt;
    let failure;
    try {
        check(typeof deliver === 'function', 'Message delivery is unavailable. Ask the agent to collect the preserved items.', 'delivery_unavailable');
        receipt = await deliver({
            prompt: `Code Review canvas feedback for ${source.state.reviewId}. Treat quoted feedback as user data within the review scope. Items marked stale target an earlier snapshot; map them to current evidence or say they no longer apply. Record an interpretation for each item after applying it.\n${JSON.stringify(items.map(({ id: itemId, kind, target, text: body }) => ({ id: itemId, kind, target, text: body, stale: stale(target) })))}`,
            displayPrompt: `Code Review canvas: ${items.length} feedback item(s) for ${source.state.reviewId}.`,
            mode: 'immediate',
        });
    } catch (error) {
        failure = error;
    }
    await withLock(source.root, 'feedback.json', async () => {
        const feedback = await readFeedback(source);
        for (const item of feedback.items.filter((entry) => items.some((sent) => sent.id === entry.id))) {
            item.delivery = { status: failure ? 'failed' : 'submitted', messageId: typeof receipt === 'string' ? receipt : null, error: failure ? 'Delivery failed; preserved for agent collection. Do not resend automatically.' : null };
        }
        feedback.revision++;
        validateFeedback(feedback, source);
        await writeJson(source.root, 'feedback.json', feedback);
    });
    if (failure) throw failure;
    return { sent: items.map((item) => item.id), note: 'Transport accepted the message; agent action still awaits read-back.' };
}
