// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { captureReview, gitCommand } from '../scripts/lib/snapshot.mjs';
import { exists, loadReview, readJson, readText, updateState } from '../scripts/lib/storage.mjs';
import { mergeStoredResult, renderReport, schedule, updateContext, writeResult } from '../scripts/lib/operations.mjs';

async function repository(t) {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'hve-code-review-'));
    t.after(() => fs.rm(root, { recursive: true, force: true }));
    await gitCommand(root, ['init', '-q']);
    await gitCommand(root, ['config', 'user.name', 'Fixture']);
    await gitCommand(root, ['config', 'user.email', 'fixture@example.invalid']);
    await fs.writeFile(path.join(root, 'app.txt'), 'before\nkeep\n');
    await gitCommand(root, ['add', '--', 'app.txt']);
    await gitCommand(root, ['-c', 'commit.gpgsign=false', 'commit', '-qm', 'base']);
    const base = (await gitCommand(root, ['rev-parse', 'HEAD'])).trim();
    return { root, base };
}

async function changedCommit(root) {
    await fs.writeFile(path.join(root, 'app.txt'), 'after\nkeep\n');
    await gitCommand(root, ['add', '--', 'app.txt']);
    await gitCommand(root, ['-c', 'commit.gpgsign=false', 'commit', '-qm', 'change']);
    return (await gitCommand(root, ['rev-parse', 'HEAD'])).trim();
}

const scope = { profile: 'basic', depth: 'standard', mode: 'sweep', rationale: 'Explicit fixture scope.' };

describe('area scheduling', () => {
    it('refuses areas that leave a captured file unassigned and covers every file by default', async (t) => {
        const { root } = await repository(t);
        await fs.writeFile(path.join(root, 'app.txt'), 'after\nkeep\n');
        await fs.writeFile(path.join(root, 'notes.txt'), 'new\n');
        const captured = await captureReview(root, { kind: 'local', localMode: 'combined' });
        assert.equal(captured.snapshot.files.length, 2);
        const partial = { id: 'partial', title: 'Partial', fileIds: [captured.snapshot.files[0].id], summary: '', before: '', after: '', impact: [] };
        await assert.rejects(schedule(captured, 0, { perspectives: ['functional'], scope, areas: [partial] }),
            (error) => error.code === 'invalid_input' && /every captured file/.test(error.message));
        const state = await schedule(captured, 0, { perspectives: ['functional'], scope });
        assert.deepEqual(state.areas[0].fileIds, captured.snapshot.files.map((file) => file.id));
    });
});

describe('immutable capture and ownership', () => {
    it('captures PR, branch, and commit evidence from immutable objects despite dirty files', async (t) => {
        const { root, base } = await repository(t);
        const head = await changedCommit(root);
        await fs.writeFile(path.join(root, 'app.txt'), 'dirty\n');
        for (const kind of ['pr', 'branch', 'commit']) {
            const captured = await captureReview(root, { kind, base, head, ...(kind === 'pr' ? { provider: { name: 'github', repository: 'example/repo', id: '1' } } : {}) });
            const evidence = await readJson(captured.root, captured.snapshot.files[0].evidencePath);
            assert.equal(evidence.lines.some((line) => line.text === 'dirty'), false);
            assert.equal(evidence.lines.some((line) => line.text === 'after'), true);
            assert.equal(captured.snapshot.target.head, head);
        }
        await assert.rejects(captureReview(root, { kind: 'pr', base, head }), /provider metadata/);
    });

    it('distinguishes staged, unstaged, and combined changes without counting staged edits twice', async (t) => {
        const { root } = await repository(t);
        await fs.writeFile(path.join(root, 'app.txt'), 'staged\nkeep\n');
        await gitCommand(root, ['add', '--', 'app.txt']);
        await fs.writeFile(path.join(root, 'app.txt'), 'working\nkeep\n');
        for (const [localMode, before, after] of [['staged', 'before', 'staged'], ['unstaged', 'staged', 'working'], ['combined', 'before', 'working']]) {
            const captured = await captureReview(root, { kind: 'local', localMode });
            assert.equal(captured.snapshot.files.length, 1);
            const { lines } = await readJson(captured.root, captured.snapshot.files[0].evidencePath);
            assert.deepEqual(lines.filter((line) => line.kind !== 'context').map((line) => line.text), [before, after]);
        }
    });

    it('keeps renames, deletions, binary omissions, private paths, and unusual names in inventory', async (t) => {
        const { root, base } = await repository(t);
        await gitCommand(root, ['mv', '--', 'app.txt', 'renamed space.txt']);
        await fs.writeFile(path.join(root, 'tab\tname.txt'), 'new text\n');
        await fs.writeFile(path.join(root, '.env'), 'private fixture\n');
        await fs.writeFile(path.join(root, 'image.bin'), Buffer.from([0, 1, 2]));
        await gitCommand(root, ['add', '--all']);
        await gitCommand(root, ['-c', 'commit.gpgsign=false', 'commit', '-qm', 'rename and files']);
        const head = (await gitCommand(root, ['rev-parse', 'HEAD'])).trim();
        const captured = await captureReview(root, { kind: 'branch', base, head });
        assert.ok(captured.snapshot.files.some((file) => file.status === 'R' && file.oldPath === 'app.txt'));
        assert.ok(captured.snapshot.files.some((file) => file.newPath === 'tab\tname.txt' && file.hunks.length === 1));
        assert.equal(captured.snapshot.files.filter((file) => file.omission).length, 2);
        await fs.unlink(path.join(root, 'renamed space.txt'));
        const deleted = await captureReview(root, { kind: 'local', localMode: 'combined' });
        assert.ok(deleted.snapshot.files.some((file) => file.status === 'D' && file.hunks[0].oldLines.length === 2));
    });

    it('captures selected code and rejects traversal and symlink previews', async (t) => {
        const { root } = await repository(t);
        const selected = await captureReview(root, { kind: 'selected', selection: [{ path: 'app.txt', startLine: 2, endLine: 2 }] });
        assert.equal(selected.snapshot.files[0].hunks[0].newLines[0], 2);
        await assert.rejects(captureReview(root, { kind: 'selected', selection: [{ path: '../outside', startLine: 1, endLine: 1 }] }), /contained relative path/);
        await fs.symlink(path.join(root, 'app.txt'), path.join(root, 'linked.txt'));
        const linked = await captureReview(root, { kind: 'selected', selection: [{ path: 'linked.txt', startLine: 1, endLine: 1 }] });
        assert.ok(linked.snapshot.files[0].omission);
        assert.equal(linked.snapshot.files[0].evidencePath, null);
    });

    it('fails instead of sealing a mixed local snapshot', async (t) => {
        const { root } = await repository(t);
        await fs.writeFile(path.join(root, 'app.txt'), 'first\n');
        const mutatingGit = async (directory, args) => {
            const output = await gitCommand(directory, args);
            if (args.includes('--unified=3')) await fs.writeFile(path.join(root, 'app.txt'), 'second\n');
            return output;
        };
        await assert.rejects(captureReview(root, { kind: 'local', localMode: 'combined' }, undefined, undefined, mutatingGit), /changed during capture/);
    });

    it('reuses an identity-matched supplied diff without another diff capture', async (t) => {
        const { root, base } = await repository(t);
        const head = await changedCommit(root);
        const patch = await gitCommand(root, ['diff', '--no-ext-diff', '--no-textconv', base, head, '--', 'app.txt']);
        const noDiff = async (directory, args) => {
            assert.notEqual(args[0], 'diff');
            return gitCommand(directory, args);
        };
        const request = { kind: 'branch', base, head, supplied: { base, head, files: [{ status: 'M', oldPath: 'app.txt', newPath: 'app.txt', patch }] } };
        const captured = await captureReview(root, request, undefined, undefined, noDiff);
        assert.equal(captured.snapshot.files[0].hunks.length, 1);
        await assert.rejects(captureReview(root, { ...request, supplied: { ...request.supplied, head: base } }), /identity does not match/);
    });

    it('handles a root commit and records missing discussion rather than claiming it was read', async (t) => {
        const { root, base } = await repository(t);
        const captured = await captureReview(root, { kind: 'commit', head: base });
        assert.equal(captured.snapshot.files[0].status, 'A');
        const head = await changedCommit(root);
        const pr = await captureReview(root, { kind: 'pr', base, head, provider: { name: 'gitlab', repository: 'example/repo', id: '2' } });
        assert.equal(pr.snapshot.discussion.status, 'unavailable');
        assert.equal(pr.snapshot.discussion.limitations.length, 1);
    });

    it('preserves human edits, rejects stale revisions, and merges an assigned result only once', async (t) => {
        const { root } = await repository(t);
        const captured = await captureReview(root, { kind: 'selected', selection: [{ path: 'app.txt', startLine: 1, endLine: 1 }] });
        const state = await schedule(captured, 0, { perspectives: ['functional'], scope });
        const work = state.workItems[0];
        const result = {
            schemaVersion: 1, reviewId: state.reviewId, snapshotId: state.snapshotId, workItemId: work.id,
            execution: 'completed', summary: 'Assigned evidence reviewed.',
            coverage: { fileIds: work.fileIds, hunkIds: work.hunkIds, notApplicable: null }, findings: [], observations: [], limitations: [],
        };
        await writeResult(captured, result);
        const merged = await mergeStoredResult(captured, 1, { workItemId: work.id });
        assert.equal(merged.outcome, 'approve');
        const replay = await mergeStoredResult(captured, merged.revision, { workItemId: work.id });
        assert.equal(replay.revision, merged.revision);
        const rendered = await renderReport(captured, replay.revision);
        const original = await readText(captured.root, 'review.md');
        assert.match(original, /All code-review findings/);
        assert.match(original, /- \[ \] Reviewed and validated/);
        assert.match(original, /## Why these changes\n\nThe agent recorded no reasons for these changes\./);
        await fs.appendFile(path.join(captured.root, 'review.md'), '\nHuman draft text.\n');
        await assert.rejects(renderReport(captured, rendered.revision), /human-editable report changed/);
        assert.match(await readText(captured.root, 'review.md'), /Human draft text/);
        await assert.rejects(updateState(captured, 0, (value) => value), /State changed/);
        assert.equal(await exists(captured.root, 'review-state.json.lock'), false);
        const newer = await captureReview(root, { kind: 'selected', selection: [{ path: 'app.txt', startLine: 2, endLine: 2 }] }, captured.relative, rendered.revision);
        assert.equal(newer.state.workItems.length, 0);
        assert.match(await readText(captured.root, 'review.md'), /Human draft text/);
        assert.equal((await loadReview(newer)).state.snapshotId, newer.snapshot.snapshotId);
    });
});

describe('reasons and the change map through the helper', () => {
    it('stores both records, refuses an invalid update without writing, and removes a record set to null', async (t) => {
        const { root, base } = await repository(t);
        const head = await changedCommit(root);
        const captured = await captureReview(root, { kind: 'branch', base, head });
        const state = await schedule(captured, 0, { perspectives: ['functional'], scope });
        const file = captured.snapshot.files[0];
        const reasons = [{ id: 'R1', title: 'Reword the first line', why: 'The agent reads the edit as a wording update.', fileIds: [file.id], hunkIds: [] }];
        const changeMap = {
            title: 'After: app.txt opens with after', description: 'One changed text file.', boxes: [],
            parts: [{ id: 'app', label: 'app.txt', box: null, change: 'changed', before: 'Opened with before', after: 'Opens with after', fileIds: [file.id], reasonIds: ['R1'] }],
            links: [],
        };
        const updated = await updateContext(captured, state.revision, { reasons, changeMap });
        assert.deepEqual(updated.reasons, reasons);
        assert.deepEqual(updated.changeMap, changeMap);
        await assert.rejects(updateContext(captured, updated.revision, { reasons: [{ ...reasons[0], hunkIds: ['missing-hunk'] }] }), /unknown ID/);
        assert.equal((await loadReview(captured)).state.revision, updated.revision);
        const cleared = await updateContext(captured, updated.revision, { changeMap: null });
        assert.equal(Object.hasOwn(cleared, 'changeMap'), false);
        assert.deepEqual(cleared.reasons, reasons);
        await assert.rejects(updateContext(captured, cleared.revision, { reasons: null, changeMap }), /unknown ID/);
    });

    it('lists the reasons in the report as the agent\'s reading, escaped, with what no reason explains', async (t) => {
        const { root, base } = await repository(t);
        await fs.writeFile(path.join(root, 'notes.txt'), 'first\n');
        await gitCommand(root, ['add', '--', 'notes.txt']);
        const head = await changedCommit(root);
        const captured = await captureReview(root, { kind: 'branch', base, head });
        const state = await schedule(captured, 0, { perspectives: ['functional'], scope });
        const app = captured.snapshot.files.find((file) => file.newPath === 'app.txt');
        const reasons = [{ id: 'R1', title: 'Reword *the* first line', why: 'The agent reads <this> as a wording update.', fileIds: [app.id], hunkIds: [] }];
        const updated = await updateContext(captured, state.revision, { reasons });
        await renderReport(captured, updated.revision);
        const report = await readText(captured.root, 'review.md');
        assert.match(report, /## Why these changes\n\nThe agent's reading of why these changes were made\.\n\n\* R1: Reword \\\*the\\\* first line \(1 file, 1 hunk\)\. The agent reads \\<this\\> as a wording update\./);
        assert.match(report, /Not explained yet: 1 file \(1 hunk\)\./);
        assert.ok(report.indexOf('## Why these changes') < report.indexOf('## Findings'));
    });
});
