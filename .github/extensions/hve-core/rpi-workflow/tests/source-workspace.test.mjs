// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { createFeedback } from '../lib/model.mjs';
import {
    createFollower,
    documentName,
    importIntoStore,
    inspectContained,
    inspectState,
    listSessions,
    listStates,
    loadState,
    loadTask,
    MAX_FILE_BYTES,
    readContained,
    readGit,
    resolveState,
    resolveTask,
    resolveWorkspace,
    scanStates,
    sessionOf,
    sessionTreeOf,
    sourceSignature,
    storeIdFor,
} from '../lib/source/workspace.mjs';
import { createStore } from '../lib/store.mjs';
import { CHANGES, CHILD_STATE, CHILD_TASK, CRITIQUE, PATHS, PLAN, REVIEW, ROOT_STATE, ROOT_TASK, SESSION_KEY, STALE_TASK, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

const EARLY_RESEARCH = `# Task Research: Offline trail maps, first look

## Executive Summary

* Bottom line: Trails need maps that work without signal.

## Findings

### Hikers lose signal on most trails

Most trails have no signal past the trailhead.

* Questions: Q10
* Evidence state: Evidence-backed finding
* Evidence: C10
* Confidence and limits: High.

### Phones keep about a gigabyte free

Most phones in the survey keep a gigabyte free.

* Questions: Q10
* Evidence state: Evidence-backed finding
* Evidence: W10
* Confidence and limits: Medium.

### Tiles come from one vendor

One vendor serves every tile the app shows.

* Questions: Q11
* Evidence state: Evidence-backed finding
* Evidence: W10
* Confidence and limits: High.

## Scope and Questions

| ID | Question | Source | Status |
|----|----------|--------|--------|
| Q10 | Do hikers lose signal? | Inferred | answered |
| Q11 | Where do tiles come from? | Inferred | answered |

## Decisions and Feedback

| Group | Decision or feedback item | Status | Owner | Rationale or input needed | Evidence | Impact of answer |
|-------|---------------------------|--------|-------|---------------------------|----------|------------------|
| D10 | Plan for offline maps | confirmed | agent | Signal drops | C10 | Starts the work |

## Research Record

### Evidence Log

| ID | Claim or finding | Source or location | Retrieved and version | Tool | Confidence | Notes |
|----|------------------|--------------------|-----------------------|------|------------|-------|
| C10 | Trails lack signal | src/map/coverage.ts | not applicable | read | High | |
| W10 | Vendor tiles | [Tile vendor](https://example.com/tiles) | 2026-01-14 | external_research | High | |
`;

const SESSION_DIR = `.copilot-tracking/rpi-sessions/${SESSION_KEY}`;
const writeJson = async (dir, relative, value) => {
    await fs.mkdir(path.dirname(path.join(dir, relative)), { recursive: true });
    await fs.writeFile(path.join(dir, relative), JSON.stringify(value));
};

const NOW = '2026-01-15T12:00:00.000Z';
let tmp;
let root;
let workspace;

before(async () => {
    tmp = await fs.realpath(await fs.mkdtemp(path.join(os.tmpdir(), 'rpi-workflow-source-')));
    root = path.join(tmp, 'repo');
    await writeFixtureWorkspace(root);
    workspace = await resolveWorkspace([undefined, root]);
});
after(async () => {
    await fs.rm(tmp, { recursive: true, force: true });
});

describe('workspace and contained reads', () => {
    it('finds the tracking folder from the first usable candidate', async () => {
        assert.deepEqual(workspace, { root, tracking: path.join(root, '.copilot-tracking') });
        await assert.rejects(resolveWorkspace([path.join(tmp, 'nowhere'), 'relative/path']), { code: 'source_unavailable' });
        const linked = path.join(tmp, 'linked');
        await fs.mkdir(linked);
        await fs.symlink(path.join(root, '.copilot-tracking'), path.join(linked, '.copilot-tracking'));
        await assert.rejects(resolveWorkspace([linked]), { code: 'source_unavailable' }, 'a linked tracking folder is refused');
    });

    it('reads only regular Markdown and JSON files inside the tracking folder', async () => {
        const plan = await readContained(workspace, PATHS.plan);
        assert.equal(plan.path, PATHS.plan);
        assert.match(plan.text, /^<!-- markdownlint/);
        await fs.writeFile(path.join(tmp, 'outside.md'), '# Outside');
        await fs.writeFile(path.join(root, 'README.md'), '# Root readme');
        await assert.rejects(inspectContained(workspace, '../outside.md'), { code: 'source_outside' });
        await assert.rejects(inspectContained(workspace, path.join(tmp, 'outside.md')), { code: 'source_outside' });
        await assert.rejects(inspectContained(workspace, 'README.md'), { code: 'source_outside' });
        await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/missing.md'), { code: 'source_not_found' });
        await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/notes.txt'), { code: 'source_invalid' });
        await fs.symlink(path.join(tmp, 'outside.md'), path.join(root, '.copilot-tracking/plans/2026-01-15/linked.md'));
        await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/linked.md'), { code: 'source_invalid' });
        await fs.writeFile(path.join(root, '.copilot-tracking/plans/2026-01-15/huge.md'), Buffer.alloc(MAX_FILE_BYTES + 1, 'a'));
        await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/huge.md'), { code: 'source_too_large' });
    });
});

describe('sessions in the workspace', () => {
    it('lists states in session folders newest first and resolves current to the newest task whose session runs', async () => {
        const states = await listStates(workspace);
        assert.equal(states.length, 3);
        assert.equal(states.at(-1).path, PATHS.staleState, 'the stale session is oldest');
        assert.deepEqual(states.map((entry) => entry.session).sort(), [SESSION_KEY, SESSION_KEY, '2026-01-10/old-task'].sort());
        assert.deepEqual(await resolveTask(workspace, 'current'), { statePath: PATHS.rootState, taskId: ROOT_TASK, warnings: [] });
        assert.equal((await resolveTask(workspace, CHILD_TASK)).statePath, PATHS.childState);
        await assert.rejects(resolveTask(workspace, 'no-such-task'), { code: 'source_not_found' });
        assert.deepEqual(await resolveState(workspace, PATHS.childState), { statePath: PATHS.childState, taskId: CHILD_TASK, warnings: [] });
        assert.deepEqual(sessionOf(PATHS.childState), { key: SESSION_KEY, date: '2026-01-15', folder: ROOT_TASK });
        assert.equal(sessionOf('.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'), null);
    });

    it('resolves current to a running child rather than climbing to its root', async () => {
        const dir = path.join(tmp, 'running-child');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, PATHS.childState, { ...CHILD_STATE, session_status: 'running', status: 'active' });
        const old = new Date(Date.now() - 3600 * 1000);
        await fs.utimes(path.join(dir, PATHS.rootState), old, old);
        const resolved = await resolveTask(await resolveWorkspace([dir]), 'current');
        assert.equal(resolved.taskId, CHILD_TASK);
    });

    it('accepts only state files in a session folder, for input and for links', async () => {
        const dir = path.join(tmp, 'contain');
        await writeFixtureWorkspace(dir);
        const ws = await resolveWorkspace([dir]);
        await writeJson(dir, '.copilot-tracking/plans/2026-01-15/stray-state.json', { task_id: 'stray' });
        await writeJson(dir, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json', { task_id: 'flat' });
        await writeJson(dir, '.copilot-tracking/rpi-sessions/2026-01-15/s/deep/too-deep-state.json', { task_id: 'deep' });
        await fs.writeFile(path.join(tmp, 'outside-state.json'), JSON.stringify({ task_id: 'outside' }));
        await fs.symlink(path.join(tmp, 'outside-state.json'), path.join(dir, `${SESSION_DIR}/linked-state.json`));
        await assert.rejects(inspectState(ws, '.copilot-tracking/plans/2026-01-15/stray-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'), { code: 'source_outside' }, 'the layout before session folders');
        await assert.rejects(inspectState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/s/deep/too-deep-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, '../outside-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, `${SESSION_DIR}/linked-state.json`), { code: 'source_invalid' }, 'a symlink');
        await assert.rejects(inspectState(ws, PATHS.plan), { code: 'source_invalid' }, 'not a state file');
        await assert.rejects(resolveState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'), { code: 'source_outside' });

        await writeJson(dir, `${SESSION_DIR}/linked-child-state.json`, { task_id: 'linked-child', parent_task: { task_id: 'elsewhere', state_path: `${SESSION_DIR}/linked-state.json` } });
        await writeJson(dir, `${SESSION_DIR}/stray-child-state.json`, { task_id: 'stray-child', parent_task: { task_id: 'stray', state_path: '.copilot-tracking/plans/2026-01-15/stray-state.json' } });
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, child_tasks: [...ROOT_STATE.child_tasks, { task_id: 'outside', state_path: '../outside-state.json' }] });
        const tree = await sessionTreeOf(ws, await loadState(ws, PATHS.rootState));
        assert.deepEqual(tree.tasks.map((task) => task.id).sort(), [CHILD_TASK, 'linked-child', 'stray-child', ROOT_TASK].sort(), 'every readable member appears once, and the linked file is not one');
        assert.deepEqual([...tree.warnings].sort(), [
            `linked-child continues elsewhere, which could not be read: ${SESSION_DIR}/linked-state.json is not a regular file.`,
            'stray-child continues stray, which could not be read: .copilot-tracking/plans/2026-01-15/stray-state.json is outside .copilot-tracking/rpi-sessions.',
            'trail-maps lists child outside, whose state file is missing.',
        ]);
        assert.ok(tree.warnings.some((text) => /trail-maps lists child outside, whose state file is missing/.test(text)), tree.warnings.join('\n'));
    });

    it('builds the session tree from the links, with the shown task marked', async () => {
        const fromRoot = await sessionTreeOf(workspace, await loadState(workspace, PATHS.rootState));
        assert.equal(fromRoot.key, SESSION_KEY);
        assert.equal(fromRoot.name, 'Offline trail maps');
        assert.deepEqual(fromRoot.tasks.map((task) => [task.id, task.depth, task.status, task.title, task.shown, task.parent]), [
            [ROOT_TASK, 0, 'completed', 'Offline trail maps', true, null],
            [CHILD_TASK, 1, 'completed', 'Offline trail maps review fixes', false, PATHS.rootState],
        ]);
        assert.deepEqual(fromRoot.warnings, []);
        const fromChild = await sessionTreeOf(workspace, await loadState(workspace, PATHS.childState));
        assert.deepEqual(fromChild.tasks.map((task) => [task.id, task.shown]), [[ROOT_TASK, false], [CHILD_TASK, true]]);
    });

    it('orders siblings as the parent lists them and shows a parent from another session as context', async () => {
        const dir = path.join(tmp, 'fan');
        await writeFixtureWorkspace(dir);
        const ws = await resolveWorkspace([dir]);
        const child = (id) => ({ task_id: id, task_slug: id, state_path: `${SESSION_DIR}/${id}-state.json` });
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, child_tasks: [child(CHILD_TASK), child('second'), child('third')] });
        await writeJson(dir, `${SESSION_DIR}/third-state.json`, { task_id: 'third', status: 'active', session_status: 'running', parent_task: { task_id: ROOT_TASK, state_path: PATHS.rootState } });
        await writeJson(dir, `${SESSION_DIR}/second-state.json`, { task_id: 'second', status: 'active', session_status: 'running', parent_task: { task_id: ROOT_TASK, state_path: PATHS.rootState }, child_tasks: [child('grandchild')] });
        await writeJson(dir, `${SESSION_DIR}/grandchild-state.json`, { task_id: 'grandchild', parent_task: { task_id: 'second', state_path: `${SESSION_DIR}/second-state.json` } });
        await writeJson(dir, `${SESSION_DIR}/unlisted-state.json`, { task_id: 'unlisted', parent_task: { task_id: ROOT_TASK } });
        const later = new Date(Date.now() + 60000);
        await fs.utimes(path.join(dir, `${SESSION_DIR}/third-state.json`), later, later);
        const tree = await sessionTreeOf(ws, await loadState(ws, `${SESSION_DIR}/second-state.json`));
        assert.deepEqual(tree.tasks.map((task) => [task.id, task.depth]), [[ROOT_TASK, 0], [CHILD_TASK, 1], ['second', 1], ['grandchild', 2], ['third', 1], ['unlisted', 1]]);
        assert.deepEqual(tree.warnings, ['trail-maps does not list its child unlisted in child_tasks.']);

        await writeJson(dir, `.copilot-tracking/rpi-sessions/2026-02-01/next-session/continued-state.json`, { task_id: 'continued', session_name: 'Next session', parent_task: { task_id: ROOT_TASK, state_path: PATHS.rootState } });
        const next = await sessionTreeOf(ws, await loadState(ws, '.copilot-tracking/rpi-sessions/2026-02-01/next-session/continued-state.json'));
        assert.equal(next.name, 'Next session');
        assert.deepEqual(next.tasks.map((task) => [task.id, task.continues?.id, task.continues?.session]), [['continued', ROOT_TASK, SESSION_KEY]]);
        assert.deepEqual(next.warnings, []);
    });

    it('lists sessions with their names, running task, and the files it skips', async () => {
        const dir = path.join(tmp, 'sessions');
        await writeFixtureWorkspace(dir);
        await writeJson(dir, '.copilot-tracking/rpi-sessions/2026-01-15/old-flat-state.json', { task_id: 'old-flat' });
        const listed = await listSessions(await resolveWorkspace([dir]));
        assert.deepEqual(listed.skipped, ['.copilot-tracking/rpi-sessions/2026-01-15/old-flat-state.json']);
        assert.deepEqual(listed.sessions.map((session) => [session.key, session.name, session.tasks, session.running?.taskId ?? null]), [
            [SESSION_KEY, 'Offline trail maps', 2, null],
            ['2026-01-10/old-task', 'Old task', 1, STALE_TASK],
        ]);
        const scan = await scanStates(await resolveWorkspace([dir]));
        assert.equal(scan.states.length, 3);
    });

    it('reads the branch and repository when the git files are there', async () => {
        assert.equal(await readGit(root), null);
        await fs.mkdir(path.join(root, '.git'));
        await fs.writeFile(path.join(root, '.git', 'HEAD'), 'ref: refs/heads/feat/offline-maps\n');
        await fs.writeFile(path.join(root, '.git', 'config'), '[core]\n\tbare = false\n[remote "origin"]\n\turl = git@github.com:contoso/trails.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n');
        assert.deepEqual(await readGit(root), { repository: 'contoso/trails', branch: 'feat/offline-maps' });
    });

    it('derives store IDs that fit the store pattern and never match the sample', () => {
        assert.equal(storeIdFor('trail-maps'), 'rpi-trail-maps');
        const odd = storeIdFor('Task_With Spaces');
        assert.match(odd, /^rpi-task-with-spaces-[0-9a-f]{8}$/);
        assert.ok(storeIdFor('x'.repeat(120)).length <= 80);
    });
});

describe('loading and importing a task', () => {
    it('loads a task with its artifacts, session tree, and watched files', async () => {
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        assert.equal(loaded.session.id, 'rpi-trail-maps');
        assert.equal(loaded.session.task.title, 'Offline trail maps');
        assert.equal(loaded.session.task.branch, 'feat/offline-maps');
        assert.deepEqual(loaded.session.followUps.tree.tasks.map((task) => task.id), [ROOT_TASK, CHILD_TASK]);
        assert.equal(loaded.tree.key, SESSION_KEY);
        assert.deepEqual(loaded.warnings, []);
        assert.equal(loaded.watched.length, 6);
        assert.equal(loaded.session.source.root, root);
        const child = await loadTask(workspace, PATHS.childState, NOW);
        assert.equal(child.session.phases.research.status, 'skipped');
        assert.deepEqual(child.warnings, [], 'reused research is not a problem');
    });

    it('names a document by its file name without the folder, .md, and its kind suffix', () => {
        assert.equal(documentName('.copilot-tracking/research/2026-10-28/task-board-polish-research.md', 'research'), 'task-board-polish');
        assert.equal(documentName('.copilot-tracking/plans/2026-10-28/task-board-polish-plan.md', 'plan'), 'task-board-polish');
        assert.equal(documentName('.copilot-tracking/reviews/plans/2026-10-28/task-board-polish-plan-critique.md', 'critique'), 'task-board-polish');
        assert.equal(documentName('.copilot-tracking/reviews/plans/2026-10-28/task-board-polish-plan-critique-2.md', 'critique'), 'task-board-polish', 'a follow-up critique names its plan\'s work');
        assert.equal(documentName('.copilot-tracking/changes/2026-10-28/task-board-polish-changes.md', 'changes'), 'task-board-polish');
        assert.equal(documentName('.copilot-tracking/reviews/logs/2026-10-28/task-board-polish-review-3.md', 'review'), 'task-board-polish', 'a new review of the same work names it');
        assert.equal(documentName('.copilot-tracking/research/2026-10-27/old-work-research-2.md', 'research'), 'old-work-research-2', 'a trailing number stays in the name');
        assert.equal(documentName('notes/plan.md', 'plan'), 'plan');
    });

    it('reads earlier research documents and plans, numbers findings on across them, and names repeated IDs', async () => {
        const many = path.join(tmp, 'many');
        await writeFixtureWorkspace(many);
        const firstResearch = '.copilot-tracking/research/2026-01-14/trail-maps-research.md';
        const firstPlan = '.copilot-tracking/plans/2026-01-14/trail-maps-plan.md';
        for (const [target, text] of [[firstResearch, EARLY_RESEARCH], [firstPlan, PLAN]]) {
            await fs.mkdir(path.dirname(path.join(many, target)), { recursive: true });
            await fs.writeFile(path.join(many, target), text);
        }
        await writeJson(many, PATHS.rootState, { ...ROOT_STATE, documents: { research: [firstResearch, PATHS.research], plan: [firstPlan, PATHS.plan] } });
        const loaded = await loadTask(await resolveWorkspace([many]), PATHS.rootState, NOW);
        const { research, plan } = loaded.session.documents;
        assert.deepEqual(research.map((doc) => [doc.n, doc.current, Boolean(doc.snapshot)]), [[1, false, true], [2, true, false]]);
        assert.deepEqual(research.map((doc) => doc.name), ['trail-maps', ROOT_TASK], 'each document is named for its work');
        assert.equal(research[0].title, 'Offline trail maps, first look');
        assert.equal(research[0].path, firstResearch);
        assert.deepEqual(research[0].snapshot.research.findings.map((finding) => finding.id), ['F1', 'F2', 'F3']);
        assert.ok(research[0].snapshot.sections['finding-f1'] && research[0].snapshot.sections['research-summary']);
        assert.ok(Object.values(research[0].snapshot.sections).every((section) => section.doc === 'research'));
        assert.deepEqual(research[0].snapshot.decisions.map((decision) => decision.id), ['D10']);
        assert.deepEqual(loaded.session.research.findings.map((finding) => finding.id), ['F4', 'F5'], 'the newest numbers its findings on from the earlier one');
        assert.ok(loaded.session.sections['finding-f4'] && !loaded.session.sections['finding-f1']);
        assert.deepEqual(plan.map((doc) => [doc.n, doc.current]), [[1, false], [2, true]]);
        assert.ok(loaded.watched.includes(firstResearch) && loaded.watched.includes(firstPlan), 'earlier documents are watched');
        assert.ok(!loaded.warnings.some((text) => /more than one research document/.test(text)), 'continuing IDs do not repeat');
        const planNames = new RegExp(`^Plan: \\d+ IDs appear in more than one plan: P01 \\(trail-maps and ${ROOT_TASK}\\)`);
        assert.ok(loaded.warnings.some((text) => planNames.test(text) && /Links go to the current plan when it holds the ID, else to the newer one\.$/.test(text)), loaded.warnings.join(' | '));

        // New work with research of its own and no plan yet: the earlier plan stays listed, and none is current.
        await writeJson(many, PATHS.rootState, { ...ROOT_STATE, artifact_paths: { ...ROOT_STATE.artifact_paths, plan: null, critique: null, changes: null, review: null }, documents: { research: [firstResearch, PATHS.research], plan: [firstPlan], critique: [PATHS.critique], changes: [PATHS.changes], review: [PATHS.review] } });
        const fresh = await loadTask(await resolveWorkspace([many]), PATHS.rootState, NOW);
        assert.deepEqual(fresh.session.documents.plan.map((doc) => [doc.n, doc.current, Boolean(doc.snapshot)]), [[1, false, true]]);
        assert.equal(fresh.session.plan.phases.length, 0, 'the current work has no plan');
        assert.ok(fresh.session.documents.plan[0].snapshot.plan.phases.length > 0, 'the earlier plan still reads');
        assert.equal(fresh.session.plan.critique, null, 'no earlier critique pairs with the current work');
        assert.deepEqual(fresh.session.implementation.changes, [], 'no earlier changes record pairs with the current work');
        assert.deepEqual(fresh.session.review.findings, [], 'no earlier review pairs with the current work');
        assert.ok(!fresh.warnings.some((text) => /does not list artifact_paths/.test(text)), fresh.warnings.join(' | '));

        // Current work that reuses research listed before another: findings still number in list order.
        await writeJson(many, PATHS.rootState, { ...ROOT_STATE, documents: { research: [PATHS.research, firstResearch], plan: [PATHS.plan] } });
        const reused = await loadTask(await resolveWorkspace([many]), PATHS.rootState, NOW);
        assert.deepEqual(reused.session.documents.research.map((doc) => [doc.n, doc.current]), [[1, true], [2, false]]);
        assert.deepEqual(reused.session.research.findings.map((finding) => finding.id), ['F1', 'F2']);
        assert.deepEqual(reused.session.documents.research[1].snapshot.research.findings.map((finding) => finding.id), ['F3', 'F4', 'F5'], 'a document listed after the current one numbers on from it');
        await writeJson(many, PATHS.rootState, { ...ROOT_STATE, documents: { research: ['.copilot-tracking/research/2026-01-13/gone-research.md', PATHS.research] } });
        const missing = await loadTask(await resolveWorkspace([many]), PATHS.rootState, NOW);
        assert.deepEqual(missing.session.documents.research.map((doc) => [doc.n, Boolean(doc.missing)]), [[1, true], [2, false]]);
        assert.ok(missing.warnings.some((text) => /gone-research\.md/.test(text)) && missing.warnings.some((text) => /finding numbers after it may not match/.test(text)), missing.warnings.join(' | '));
    });

    it('pairs earlier changes records, reviews, and critiques with their work by name, as finished work', async () => {
        const pairs = path.join(tmp, 'pairs');
        await writeFixtureWorkspace(pairs);
        const early = {
            research: '.copilot-tracking/research/2026-01-14/early-look-research.md',
            plan: '.copilot-tracking/plans/2026-01-14/early-look-plan.md',
            critique: '.copilot-tracking/reviews/plans/2026-01-14/early-look-plan-critique.md',
            critique2: '.copilot-tracking/reviews/plans/2026-01-14/early-look-plan-critique-2.md',
            changes: '.copilot-tracking/changes/2026-01-14/early-look-changes.md',
            review: '.copilot-tracking/reviews/logs/2026-01-14/early-look-review.md',
            review2: '.copilot-tracking/reviews/logs/2026-01-14/early-look-review-2.md',
            lonely: '.copilot-tracking/changes/2026-01-13/lonely-changes.md',
        };
        const retitle = (text, title) => text.replace(/^# ([^:\n]+): .*$/m, `# $1: ${title}`);
        const texts = [
            [early.research, EARLY_RESEARCH],
            [early.plan, retitle(PLAN, 'An early look')],
            [early.critique, retitle(CRITIQUE, 'An early look')],
            [early.critique2, retitle(CRITIQUE, 'An early look').replace('Downloads cannot resume', 'Downloads restart from zero')],
            [early.changes, `${retitle(CHANGES, 'An early look')}\n## Early notes\n\nOnly the early record has these.\n`],
            [early.review, retitle(REVIEW, 'The first look')],
            [early.review2, `${retitle(REVIEW, 'The second look')}\n## Second look notes\n\nOnly the second review has these.\n`],
            [early.lonely, retitle(CHANGES, 'A record without a plan')],
        ];
        for (const [target, text] of texts) {
            await fs.mkdir(path.dirname(path.join(pairs, target)), { recursive: true });
            await fs.writeFile(path.join(pairs, target), text);
        }
        // The agent implements the current work, with a blocker of its own.
        await writeJson(pairs, PATHS.rootState, {
            ...ROOT_STATE,
            active_phase: 'Implement',
            status: 'active',
            blockers: [{ id: 'B1', summary: 'P02-T02 waits on the tile server', resolution: null }],
            documents: {
                research: [early.research, PATHS.research],
                plan: [early.plan, PATHS.plan],
                critique: [early.critique, early.critique2, PATHS.critique],
                changes: [early.lonely, early.changes, PATHS.changes],
                review: [early.review, early.review2, PATHS.review],
            },
        });
        const loaded = await loadTask(await resolveWorkspace([pairs]), PATHS.rootState, NOW);
        const { plan, implement, review } = loaded.session.documents;
        assert.deepEqual(implement.map((doc) => [doc.n, doc.name, doc.title, doc.current, Boolean(doc.snapshot)]), [[1, 'lonely', 'A record without a plan', false, true], [2, 'early-look', 'An early look', false, true], [3, ROOT_TASK, 'Offline trail maps', true, false]]);
        assert.deepEqual(review.map((doc) => [doc.name, doc.title, doc.workTitle, doc.current]), [['early-look', 'The first look', 'An early look', false], ['early-look', 'The second look', 'An early look', false], [ROOT_TASK, 'Offline trail maps', 'Offline trail maps', true]]);

        // An earlier changes record names its plan's place and reads as finished.
        const record = implement[1].snapshot;
        assert.equal(record.pairedPlan, 1, 'the early record pairs with the plan of its name');
        assert.equal(implement[0].snapshot.pairedPlan, null, 'no plan carries the lonely record\'s name');
        assert.equal(record.implementation.current, null);
        assert.deepEqual(record.implementation.blockers, [], 'the live state\'s blocker stays with the current work');
        assert.ok(loaded.session.implementation.blockers.some((blocker) => /tile server/.test(blocker.text)), 'the current work keeps its blocker');
        assert.deepEqual(record.implementation.changes.map((change) => change.id), loaded.session.implementation.changes.map((change) => change.id), 'changes number from CH-001 in each record');
        assert.equal(record.record.status, 'done');
        assert.ok(record.records.some((item) => item.heading === 'Early notes'), 'its other sections are its own');
        assert.ok(!loaded.session.records.implement.some((item) => item.heading === 'Early notes'));
        assert.ok(Object.values(record.sections).every((section) => section.doc === 'implement'));
        assert.ok(record.traces['P02-T01']?.includes('CH-002'), 'its plan\'s tasks carry their traces');
        assert.ok(!('plan' in record), 'it names its plan instead of copying it');

        // An earlier plan reads as finished and pairs with the last critique of its name.
        const earlyPlan = plan[0].snapshot;
        assert.ok(earlyPlan.plan.phases.flatMap((phase) => phase.tasks).every((task) => task.status !== 'in-progress'));
        assert.ok(loaded.session.plan.phases.flatMap((phase) => phase.tasks).some((task) => task.status === 'in-progress'), 'the current plan\'s next task is in progress');
        assert.deepEqual(earlyPlan.plan.critique.findings.map((finding) => finding.title), ['Downloads restart from zero', 'Eviction is not discussed']);
        assert.equal(earlyPlan.plan.critique.findings[0].disposition, 'resolved');
        assert.deepEqual(loaded.session.plan.critique.findings.map((finding) => finding.title), ['Downloads cannot resume', 'Eviction is not discussed']);

        // Each review is its own, with traces through its work's changes record and plan.
        assert.ok(review[1].snapshot.records.some((item) => item.heading === 'Second look notes'));
        assert.ok(!review[0].snapshot.records.some((item) => item.heading === 'Second look notes'));
        assert.deepEqual(review[0].snapshot.review.findings.map((finding) => finding.id), ['RV-001', 'RV-002']);
        const trace = review[0].snapshot.traces['RV-002'];
        assert.ok(trace && trace.indexOf('P02-T01') < trace.indexOf('CH-002') && trace.indexOf('CH-002') < trace.indexOf('RV-002'), JSON.stringify(trace));

        for (const target of Object.values(early)) assert.ok(loaded.watched.includes(target), `${target} is watched`);
        assert.ok(!loaded.warnings.some((text) => /\b(?:CH|DS|AL|RV|RD)-\d{3}\b/.test(text)), loaded.warnings.join(' | '));
    });

    it('reports an unreadable artifact as a warning and fails on an unreadable state', async () => {
        const broken = path.join(tmp, 'broken');
        await writeFixtureWorkspace(broken);
        await fs.rm(path.join(broken, PATHS.critique));
        const brokenWorkspace = await resolveWorkspace([broken]);
        const loaded = await loadTask(brokenWorkspace, PATHS.rootState, NOW);
        assert.equal(loaded.warnings.length, 1);
        assert.match(loaded.warnings[0], /plan-critique\.md/);
        await fs.writeFile(path.join(broken, PATHS.rootState), '{ not json');
        await assert.rejects(loadTask(brokenWorkspace, PATHS.rootState, NOW), { code: 'source_invalid' });
    });

    it('changes the signature when a watched file, a state in the session, or a skipped file changes', async () => {
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        const first = await sourceSignature(workspace, loaded.watched, SESSION_KEY);
        assert.equal(await sourceSignature(workspace, loaded.watched, SESSION_KEY), first);
        const later = new Date(Date.now() + 5000);
        await fs.utimes(path.join(root, PATHS.plan), later, later);
        const second = await sourceSignature(workspace, loaded.watched, SESSION_KEY);
        assert.notEqual(second, first);
        await writeJson(root, '.copilot-tracking/rpi-sessions/2026-03-01/elsewhere/other-state.json', { task_id: 'other' });
        assert.equal(await sourceSignature(workspace, loaded.watched, SESSION_KEY), second, 'another session does not count');
        await writeJson(root, `${SESSION_DIR}/another-state.json`, { task_id: 'another', parent_task: { task_id: ROOT_TASK } });
        const third = await sourceSignature(workspace, loaded.watched, SESSION_KEY);
        assert.notEqual(third, second);
        await writeJson(root, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json', { task_id: 'flat' });
        assert.notEqual(await sourceSignature(workspace, loaded.watched, SESSION_KEY), third, 'a new skipped file counts');
        const warned = await loadTask(workspace, PATHS.rootState, NOW);
        assert.ok(warned.warnings.some((text) => /not in a session folder, so the canvas skips it: .copilot-tracking\/rpi-sessions\/2026-01-15\/flat-state\.json/.test(text)), warned.warnings.join('\n'));
        assert.ok(warned.warnings.some((text) => /trail-maps does not list its child another/.test(text)));
        await fs.rm(path.join(root, `${SESSION_DIR}/another-state.json`));
        await fs.rm(path.join(root, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'));
        await fs.rm(path.join(root, '.copilot-tracking/rpi-sessions/2026-03-01'), { recursive: true });
    });

    it('creates the document once, then merges without counting as a user change', async () => {
        const store = createStore({ root: path.join(tmp, 'store') });
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        const first = await importIntoStore(store, loaded, NOW);
        assert.equal(first.changed, true);
        const again = await importIntoStore(store, await loadTask(workspace, PATHS.rootState, NOW), NOW);
        assert.equal(again.changed, false);
        await store.update(loaded.session.id, (s) => createFeedback(s, { kind: 'comment', text: 'Keep this', target: { id: 'F1', type: 'finding', phase: 'research' } }, NOW), { by: 'user' });
        const planFile = path.join(root, PATHS.plan);
        await fs.writeFile(planFile, (await fs.readFile(planFile, 'utf8')).replace('Tiles expire after 30 days.', 'Tiles expire after 45 days.'));
        const merged = await importIntoStore(store, await loadTask(workspace, PATHS.rootState, NOW), NOW);
        assert.equal(merged.changed, true);
        assert.equal(merged.session.feedback.length, 1);
        assert.equal(merged.session.scenario.userChanges, 1, 'the source update is not a user change');
        assert.match(merged.session.sections['plan-unknowns'].markdown, /45 days/);
        store.close();
    });
});

describe('following the files', () => {
    const later = (ms) => new Date(Date.now() + ms);

    it('imports a change only after it holds for two polls, and writes nothing otherwise', async () => {
        const dir = path.join(tmp, 'follow');
        await writeFixtureWorkspace(dir);
        const store = createStore({ root: path.join(tmp, 'follow-store') });
        const follower = createFollower({ store, workspace: await resolveWorkspace([dir]), statePath: PATHS.rootState, intervalMs: 10000 });
        const opened = await follower.importNow();
        assert.equal(opened.changed, true);
        const id = follower.documentId;
        const revision = (await store.load(id)).revision;
        assert.equal(await follower.tick(), false, 'unchanged files import nothing');
        assert.equal((await store.load(id)).revision, revision);

        const planFile = path.join(dir, PATHS.plan);
        await fs.writeFile(planFile, (await fs.readFile(planFile, 'utf8')).replace('Tiles expire after 30 days.', 'Tiles expire after 60 days.'));
        await fs.utimes(planFile, later(1000), later(1000));
        assert.equal(await follower.tick(), false, 'a new signature waits one poll');
        await fs.writeFile(planFile, (await fs.readFile(planFile, 'utf8')).replace('60 days', '90 days'));
        await fs.utimes(planFile, later(2000), later(2000));
        assert.equal(await follower.tick(), false, 'a file still changing keeps waiting');
        assert.equal(await follower.tick(), true, 'a settled change imports');
        const updated = await store.load(id);
        assert.match(updated.sections['plan-unknowns'].markdown, /90 days/);
        assert.equal(updated.revision, revision + 1);
        store.close();
    });

    it('keeps the last good document and reports a failure, then recovers', async () => {
        const dir = path.join(tmp, 'follow-broken');
        await writeFixtureWorkspace(dir);
        const store = createStore({ root: path.join(tmp, 'follow-broken-store') });
        const messages = [];
        const follower = createFollower({ store, workspace: await resolveWorkspace([dir]), statePath: PATHS.rootState, log: (message) => messages.push(message) });
        await follower.importNow();
        const id = follower.documentId;
        const stateFile = path.join(dir, PATHS.rootState);
        const good = await fs.readFile(stateFile, 'utf8');
        await fs.writeFile(stateFile, '{ "task_id": "trail-maps", ');
        await fs.utimes(stateFile, later(3000), later(3000));
        await follower.tick();
        assert.equal(await follower.tick(), false);
        const kept = await store.load(id);
        assert.equal(kept.plan.phases.length, 2, 'content stays');
        assert.match(kept.source.warnings[0], /could not be read; showing the last good version/);
        assert.equal(messages.length, 1);
        await fs.writeFile(stateFile, good);
        await fs.utimes(stateFile, later(4000), later(4000));
        await follower.tick();
        assert.equal(await follower.tick(), true);
        assert.deepEqual((await store.load(id)).source.warnings, []);
        store.close();
    });

    it('tells the caller after each import, including the session tree', async () => {
        const dir = path.join(tmp, 'follow-hook');
        await writeFixtureWorkspace(dir);
        const store = createStore({ root: path.join(tmp, 'follow-hook-store') });
        const seen = [];
        const follower = createFollower({ store, workspace: await resolveWorkspace([dir]), statePath: PATHS.rootState, intervalMs: 10000, onImport: (loaded) => seen.push(loaded.tree.tasks.map((task) => task.id)) });
        await follower.importNow();
        assert.deepEqual(seen, [[ROOT_TASK, CHILD_TASK]]);
        await writeJson(dir, `${SESSION_DIR}/third-state.json`, { task_id: 'third', parent_task: { task_id: ROOT_TASK, state_path: PATHS.rootState } });
        await follower.tick();
        assert.equal(await follower.tick(), true, 'a new state in the session imports');
        assert.deepEqual(seen.at(-1), [ROOT_TASK, CHILD_TASK, 'third']);
        store.close();
    });

    it('starts and stops polling', async () => {
        const store = createStore({ root: path.join(tmp, 'follow-timer-store') });
        const follower = createFollower({ store, workspace, statePath: PATHS.rootState, intervalMs: 5 });
        follower.start();
        follower.start();
        assert.equal(follower.running, true);
        follower.stop();
        assert.equal(follower.running, false);
        store.close();
    });
});
