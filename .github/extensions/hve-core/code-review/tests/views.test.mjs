// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
    arrivals, boardLanes, DISPOSITION, feedbackState, fileAnnotations, fileLabel, fileStats, findingGroups, findingsFor, hidingNarrowing, hunkAnnotations, needsYou, NOT_EXPLAINED,
    perspectiveProgress,
    reasonCoverage, reasonFiles, resolveFocus, safeWebUrl, stageFor, stages, targetSummary,
} from '../ui/views.mjs';

function fixture() {
    return {
        snapshotId: 'snapshot-one', target: { head: 'a'.repeat(40) },
        areas: [{ id: 'area-one', title: 'Changes', status: 'pending', fileIds: ['file-one'] }],
        files: [{ id: 'file-one', status: 'R', oldPath: 'old.js', newPath: 'new.js', hunks: [{ id: 'hunk-one', oldStart: 2, oldCount: 1, newStart: 2, newCount: 1 }] }],
        findings: [{ id: 'finding-one', anchors: [{ fileId: 'file-one', hunkId: 'hunk-one' }] }],
        discussion: { items: [
            { id: 'current', path: 'new.js', line: 2, side: 'new', commit: 'a'.repeat(40), outdated: false },
            { id: 'old', path: 'old.js', line: 2, side: 'old', commit: 'b'.repeat(40), outdated: true },
            { id: 'timeline', path: null, line: null, side: null, commit: null },
        ] },
    };
}

describe('review view joins', () => {
    it('shows one card per lane and keeps areas that need attention in progress, outside reviewed coverage', () => {
        const view = fixture();
        view.areas = ['pending', 'in_progress', 'reviewed', 'blocked', 'stale', 'unavailable', 'skipped', 'pending-2', 'reviewed-2']
            .map((id) => ({ id, status: id.replace(/-2$/, '') }));
        const lanes = boardLanes(view);
        assert.deepEqual(lanes.map((lane) => lane.id), ['pending', 'active', 'reviewed']);
        const lane = (id, options) => boardLanes(view, options).find((entry) => entry.id === id);
        assert.deepEqual(lane('active').areas.map((area) => area.id), ['in_progress', 'blocked', 'stale', 'unavailable', 'skipped']);
        assert.equal(lane('active').card.id, 'blocked');
        assert.equal(lane('active').hidden, 3);
        assert.equal(lane('active', { agentAreaId: 'in_progress' }).card.id, 'in_progress');
        assert.equal(lane('active', { agentAreaId: 'in_progress' }).hidden, 4);
        assert.equal(lane('pending').card.id, 'pending');
        assert.equal(lane('reviewed').card.id, 'reviewed-2');
        assert.equal(lane('reviewed', { selectedAreaId: 'reviewed' }).card.id, 'reviewed');
        assert.deepEqual(lane('reviewed').areas.map((area) => area.id), ['reviewed', 'reviewed-2']);
        assert.equal(boardLanes({ areas: [] }).every((entry) => entry.card === null && entry.hidden === 0), true);
    });

    it('joins areas, files, hunks, and finding anchors deterministically', () => {
        const view = fixture();
        for (const [kind, id] of [['area', 'area-one'], ['file', 'file-one'], ['hunk', 'hunk-one'], ['finding', 'finding-one']]) {
            const focus = resolveFocus(view, { kind, id, snapshotId: view.snapshotId });
            assert.equal(focus.areaId, 'area-one');
            assert.equal(focus.fileId, 'file-one');
        }
        assert.equal(fileLabel(view.files[0]), 'old.js -> new.js');
        assert.equal(fileLabel({ status: 'D', oldPath: 'deleted.js', newPath: null }), 'deleted.js (deleted)');
    });

    it('keeps an omitted non-text file navigable without inventing line counts', () => {
        const view = fixture();
        view.files.push({ id: 'file-binary', status: 'M', oldPath: 'logo.png', newPath: 'logo.png', omission: 'Binary or non-text content.', hunks: [] });
        view.areas[0].fileIds.push('file-binary');
        const binary = view.files[1];
        assert.deepEqual(fileStats(binary), { additions: 0, deletions: 0 });
        assert.equal(fileLabel(binary), 'logo.png');
        const focus = resolveFocus(view, { kind: 'file', id: 'file-binary', snapshotId: view.snapshotId });
        assert.equal(focus.fileId, 'file-binary');
        assert.equal(focus.hunkId, null);
        assert.equal(focus.mapped, true);
    });

    it('keeps old/unmapped comments available without inventing current anchors', () => {
        const view = fixture();
        assert.equal(resolveFocus(view, { kind: 'comment', id: 'current', snapshotId: view.snapshotId }).hunkId, 'hunk-one');
        for (const id of ['old', 'timeline']) {
            const focus = resolveFocus(view, { kind: 'comment', id, snapshotId: view.snapshotId });
            assert.equal(focus.commentId, id);
            assert.equal(focus.hunkId, null);
            assert.equal(focus.mapped, false);
        }
        const stale = resolveFocus(view, { kind: 'file', id: 'file-one', snapshotId: 'earlier' });
        assert.equal(stale.stale, true);
        assert.equal(stale.fileId, null);
    });

    it('keeps metadata findings separate from source locations and permits only public web schemes', () => {
        const view = fixture();
        view.findings.push({ id: 'metadata', anchors: [{ fileId: null, hunkId: null, field: 'body' }] });
        const focus = resolveFocus(view, { kind: 'finding', id: 'metadata', snapshotId: view.snapshotId });
        assert.equal(focus.metadataField, 'body');
        assert.equal(focus.fileId, null);
        assert.equal(safeWebUrl('https://example.invalid/reference'), 'https://example.invalid/reference');
        assert.equal(safeWebUrl('custom:example'), null);
        assert.equal(safeWebUrl('file:///example'), null);
    });
});

describe('stage rail, attention, and steering views', () => {
    function review(overrides = {}) {
        const view = fixture();
        return Object.assign(view, {
            reviewId: 'review-one', status: 'in_progress', outcome: null, stale: false, metadata: null,
            workItems: [{ id: 'functional-1', perspective: 'functional', required: true, status: 'completed' }],
            feedback: { items: [], bookmarks: [], seen: [] },
            findings: [
                { id: 'low', severity: 'Low', disposition: 'proposed', anchors: [] },
                { id: 'high', severity: 'High', disposition: 'accepted', anchors: [] },
                { id: 'gone', severity: 'Critical', disposition: 'rejected', anchors: [] },
            ],
        }, overrides);
    }
    const status = (view) => Object.fromEntries(stages(view).map((stage) => [stage.id, stage.status]));

    it('derives three stages from recorded work, findings, and outcome only', () => {
        assert.deepEqual(status(review()), { capture: 'done', review: 'active', outcome: 'upcoming' });
        assert.match(stages(review()).find((stage) => stage.id === 'review').detail, /1 being checked/);
        assert.equal(status(review({ workItems: [{ id: 'w', required: true, status: 'blocked' }] })).review, 'blocked');
        assert.equal(status(review({ workItems: [], findings: [] })).review, 'upcoming');
        assert.equal(status(review({ workItems: [] })).review, 'active');
        assert.equal(status(review({ status: 'incomplete' })).outcome, 'blocked');
        assert.deepEqual(status(review({ findings: [], outcome: 'approve', status: 'completed' })), { capture: 'done', review: 'done', outcome: 'done' });
        assert.equal(status(review({ outcome: 'approve', stale: true })).outcome, 'upcoming');
        assert.equal(stageFor({ kind: 'finding', id: 'high' }), 'review');
        assert.equal(stageFor({ kind: 'comment', id: 'current' }), 'review');
    });

    it('asks for unseen retained High and Critical findings in Review', () => {
        const view = review();
        assert.deepEqual(needsYou(view).map((item) => [item.id, item.stage]), [['high', 'review']]);
        view.feedback.seen.push({ kind: 'finding', id: 'high', snapshotId: view.snapshotId });
        assert.deepEqual(needsYou(view), []);
    });

    it('groups findings by severity, sets rejected ones aside, and keeps ID order while they are checked', () => {
        const view = review();
        view.findings.push({ id: 'high-a', severity: 'High', disposition: 'proposed', anchors: [] }, { id: 'medium', severity: 'Medium', disposition: 'deferred', anchors: [] });
        const groups = findingGroups(view.findings);
        assert.deepEqual(groups.map((group) => [group.id, group.open, group.findings.map((finding) => finding.id)]), [
            ['high', true, ['high', 'high-a']], ['medium', false, ['medium']], ['low', false, ['low']], ['set-aside', false, ['gone']],
        ]);
        assert.equal(DISPOSITION.proposed.label, 'Being checked');
        view.findings.find((finding) => finding.id === 'high-a').disposition = 'accepted';
        assert.deepEqual(findingGroups(view.findings)[0].findings.map((finding) => finding.id), ['high', 'high-a']);
        assert.deepEqual(findingGroups([]), []);
    });

    it('counts checked areas per perspective and holds new findings behind a severity summary', () => {
        const view = review({ workItems: [
            { id: 'functional-1', perspective: 'functional', required: true, status: 'completed', areaIds: ['a'] },
            { id: 'functional-2', perspective: 'functional', required: true, status: 'in_progress', areaIds: ['b'] },
            { id: 'security-3', perspective: 'security', required: true, status: 'blocked', areaIds: ['a'] },
            { id: 'context-4', perspective: 'context', required: false, status: 'pending', areaIds: ['a'] },
        ] });
        assert.deepEqual(perspectiveProgress(view), [
            { perspective: 'functional', total: 2, done: 1, active: 1, attention: 0 },
            { perspective: 'security', total: 1, done: 0, active: 0, attention: 1 },
        ]);
        const shown = new Set(['low']);
        assert.deepEqual(arrivals(view.findings, shown), { ids: ['high', 'gone'], count: 2, summary: '1 High', fresh: ['high', 'gone'] });
        view.findings.push({ id: 'critical', severity: 'Critical', disposition: 'proposed', anchors: [] });
        assert.equal(arrivals(view.findings, shown).summary, '1 Critical, 1 High');
        shown.add('high');
        assert.deepEqual(arrivals(view.findings, shown, new Set(['high', 'gone'])).fresh, ['critical'], 'revealing one held finding does not hide the next arrival');
        assert.deepEqual(arrivals(view.findings, shown, new Set(['gone', 'critical'])).fresh, []);
        assert.equal(arrivals(view.findings, new Set(view.findings.map((finding) => finding.id))).count, 0);
    });

    it('explains hunks by reason, counts what no reason explains, and narrows findings to a reason or area', () => {
        const view = review();
        view.files.push(
            { id: 'file-two', status: 'M', oldPath: 'b.js', newPath: 'b.js', hunks: [{ id: 'hunk-two' }, { id: 'hunk-three' }] },
            { id: 'file-binary', status: 'A', oldPath: null, newPath: 'logo.png', omission: 'Binary.', hunks: [] },
        );
        view.areas = [{ id: 'area-one', fileIds: ['file-one'] }, { id: 'area-two', fileIds: ['file-two', 'file-binary'] }];
        view.reasons = [
            { id: 'R1', fileIds: ['file-one'], hunkIds: ['hunk-two'] },
            { id: 'R2', fileIds: [], hunkIds: ['hunk-three'] },
        ];
        const coverage = reasonCoverage(view);
        assert.deepEqual(coverage.reasons, [{ id: 'R1', files: 2, hunks: 2 }, { id: 'R2', files: 1, hunks: 1 }]);
        assert.deepEqual(coverage.unexplained, { files: 1, hunks: 0, fileIds: ['file-binary'] });
        assert.deepEqual(coverage.byFile['file-two'], [{ reasonId: 'R1', hunks: 1 }, { reasonId: 'R2', hunks: 1 }]);
        assert.equal(coverage.byHunk['hunk-three'], 'R2');
        view.findings = [
            { id: 'line', anchors: [{ fileId: 'file-two', hunkId: 'hunk-three' }] },
            { id: 'file', anchors: [{ fileId: 'file-two', hunkId: null }] },
            { id: 'meta', anchors: [{ fileId: null, hunkId: null, field: 'body' }] },
            { id: 'first', anchors: [{ fileId: 'file-one', hunkId: 'hunk-one' }] },
        ];
        assert.deepEqual(findingsFor(view, { reasonId: 'R2' }).map((finding) => finding.id), ['line', 'file']);
        assert.deepEqual(findingsFor(view, { reasonId: 'R1' }).map((finding) => finding.id), ['file', 'first']);
        assert.deepEqual(findingsFor(view, { areaId: 'area-one' }).map((finding) => finding.id), ['first']);
        assert.equal(findingsFor(view, {}).length, 4);
        assert.deepEqual(reasonCoverage({ files: view.files }).unexplained, { files: 3, hunks: 3, fileIds: ['file-one', 'file-two', 'file-binary'] });
        assert.deepEqual(reasonFiles(view, 'R1'), ['file-one', 'file-two']);
        assert.deepEqual(reasonFiles(view, NOT_EXPLAINED), ['file-binary']);
        view.reasons[1].hunkIds = [];
        assert.deepEqual(reasonFiles(view, NOT_EXPLAINED), ['file-two', 'file-binary']);
        assert.deepEqual(findingsFor(view, { reasonId: NOT_EXPLAINED }).map((finding) => finding.id), ['line', 'file']);
        assert.deepEqual(hidingNarrowing(view, ['line', 'first'], { reasonId: NOT_EXPLAINED, areaId: 'area-two' }), { reason: true, area: true });
        assert.deepEqual(hidingNarrowing(view, ['line', 'file'], { reasonId: NOT_EXPLAINED, areaId: 'area-two' }), { reason: false, area: false });
        assert.deepEqual(hidingNarrowing(view, ['first'], { areaId: 'area-two' }), { reason: false, area: true });
        assert.deepEqual(hidingNarrowing(view, ['meta'], {}), { reason: false, area: false });
        const focus = (id) => resolveFocus(view, { kind: 'reason', id, snapshotId: view.snapshotId });
        assert.deepEqual([focus('R1').fileId, focus('R1').areaId, focus('R1').mapped], ['file-one', 'area-one', true]);
        assert.deepEqual([focus('R9').fileId, focus('R9').mapped], [null, false]);
    });

    it('labels each feedback lifecycle state without claiming the agent acted', () => {
        const label = (item) => feedbackState(item).label;
        assert.equal(label({ status: 'draft', delivery: null }), 'Draft');
        assert.equal(label({ status: 'queued', delivery: null }), 'Not sent');
        assert.equal(label({ status: 'sent', delivery: { status: 'submitted' } }), 'Sent');
        assert.equal(label({ status: 'sent', delivery: { status: 'collected' } }), 'The agent has it');
        assert.equal(label({ status: 'sent', delivery: { status: 'failed' } }), 'Not delivered');
        assert.equal(label({ status: 'interpreted', delivery: { status: 'collected' } }), 'Read back');
    });

    it('places only current, mapped comments and anchored findings beside a hunk', () => {
        const view = review();
        view.findings.push({ id: 'anchored', severity: 'Medium', disposition: 'accepted', anchors: [{ fileId: 'file-one', hunkId: 'hunk-one' }] });
        const notes = hunkAnnotations(view, view.files[0], view.files[0].hunks[0]);
        assert.deepEqual(notes.findings.map((finding) => finding.id), ['anchored']);
        assert.deepEqual(notes.comments.map((comment) => comment.id), ['current']);
    });

    it('keeps findings the reader has not been shown out of hunk and file notes', () => {
        const view = review();
        const anchors = [{ fileId: 'file-one', hunkId: 'hunk-one' }];
        view.findings.push({ id: 'seen', severity: 'Medium', disposition: 'accepted', anchors }, { id: 'held', severity: 'High', disposition: 'accepted', anchors });
        const shown = new Set(['seen']);
        const [file] = view.files;
        assert.deepEqual(hunkAnnotations(view, file, file.hunks[0], shown).findings.map((finding) => finding.id), ['seen']);
        assert.deepEqual(fileAnnotations(view, file, shown).findings.map((finding) => finding.id), ['seen']);
        assert.deepEqual(fileAnnotations(view, file).findings.map((finding) => finding.id), ['seen', 'held']);
        assert.equal(hunkAnnotations(view, file, file.hunks[0], new Set()).findings.length, 0);
    });

    it('titles a review from captured metadata, then from its target kind', () => {
        const view = review({ target: { kind: 'pr', provider: { name: 'example', repository: 'org/repo', id: '7' }, base: 'a'.repeat(40), head: 'b'.repeat(40) } });
        assert.equal(targetSummary(view).title, 'Pull request org/repo#7');
        view.metadata = { status: 'complete', fields: [{ name: 'title', value: 'Add export', source: 'provider' }] };
        assert.equal(targetSummary(view).title, 'Add export');
        assert.equal(targetSummary(review({ target: { kind: 'local', localMode: 'staged' } })).title, 'Local changes (staged)');
    });
});
