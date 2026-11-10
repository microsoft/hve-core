// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { symlinkOrSkip } from '../../session-log/tests/helpers.mjs';
import { createFeedback } from '../lib/model.mjs';
import { loadSessionDocs } from '../lib/session-docs.mjs';
import { parseWorkspaceYaml, resolveSessionStateRoot, resolveSessionWorkspace } from '../lib/source/sessions.mjs';
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
import { scratchFolder } from './helpers/scratch.mjs';
import { CHILD_STATE, CHILD_TASK, EARLY, PATHS, PLAN, ROOT_STATE, ROOT_TASK, SESSION_KEY, STALE_TASK, writeEarlierWork, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

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
    it('finds the tracking folder from the first usable candidate', async (t) => {
        assert.deepEqual(workspace, { root, tracking: path.join(root, '.copilot-tracking') });
        await assert.rejects(resolveWorkspace([path.join(tmp, 'nowhere'), 'relative/path']), { code: 'source_unavailable' });
        await t.test('refuses a linked tracking folder', async (t) => {
            const linked = path.join(tmp, 'linked');
            await fs.mkdir(linked);
            if (!(await symlinkOrSkip(t, path.join(root, '.copilot-tracking'), path.join(linked, '.copilot-tracking'), 'dir'))) return;
            await assert.rejects(resolveWorkspace([linked]), { code: 'source_unavailable' });
        });
    });

    it('reads only regular Markdown and JSON files inside the tracking folder', async (t) => {
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
        await fs.writeFile(path.join(root, '.copilot-tracking/plans/2026-01-15/huge.md'), Buffer.alloc(MAX_FILE_BYTES + 1, 'a'));
        await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/huge.md'), { code: 'source_too_large' });
        await t.test('refuses a linked document', async (t) => {
            if (!(await symlinkOrSkip(t, path.join(tmp, 'outside.md'), path.join(root, '.copilot-tracking/plans/2026-01-15/linked.md'), 'file'))) return;
            await assert.rejects(inspectContained(workspace, '.copilot-tracking/plans/2026-01-15/linked.md'), { code: 'source_invalid' });
        });
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

    it('accepts only state files in a session folder, for input and for links', async (t) => {
        const dir = path.join(tmp, 'contain');
        await writeFixtureWorkspace(dir);
        const ws = await resolveWorkspace([dir]);
        await writeJson(dir, '.copilot-tracking/plans/2026-01-15/stray-state.json', { task_id: 'stray' });
        await writeJson(dir, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json', { task_id: 'flat' });
        await writeJson(dir, '.copilot-tracking/rpi-sessions/2026-01-15/s/deep/too-deep-state.json', { task_id: 'deep' });
        await fs.writeFile(path.join(tmp, 'outside-state.json'), JSON.stringify({ task_id: 'outside' }));
        await assert.rejects(inspectState(ws, '.copilot-tracking/plans/2026-01-15/stray-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'), { code: 'source_outside' }, 'the layout before session folders');
        await assert.rejects(inspectState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/s/deep/too-deep-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, '../outside-state.json'), { code: 'source_outside' });
        await assert.rejects(inspectState(ws, PATHS.plan), { code: 'source_invalid' }, 'not a state file');
        await assert.rejects(resolveState(ws, '.copilot-tracking/rpi-sessions/2026-01-15/flat-state.json'), { code: 'source_outside' });

        await writeJson(dir, `${SESSION_DIR}/stray-child-state.json`, { task_id: 'stray-child', parent_task: { task_id: 'stray', state_path: '.copilot-tracking/plans/2026-01-15/stray-state.json' } });
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, child_tasks: [...ROOT_STATE.child_tasks, { task_id: 'outside', state_path: '../outside-state.json' }] });
        const tree = await sessionTreeOf(ws, await loadState(ws, PATHS.rootState));
        assert.deepEqual(tree.tasks.map((task) => task.id).sort(), [CHILD_TASK, 'stray-child', ROOT_TASK].sort(), 'every readable member appears once');
        assert.deepEqual([...tree.warnings].sort(), [
            'stray-child continues stray, which could not be read: .copilot-tracking/plans/2026-01-15/stray-state.json is outside .copilot-tracking/rpi-sessions.',
            'trail-maps lists child outside, whose state file is missing.',
        ]);
        await t.test('refuses linked state files and reports linked parents', async (t) => {
            if (!(await symlinkOrSkip(t, path.join(tmp, 'outside-state.json'), path.join(dir, `${SESSION_DIR}/linked-state.json`), 'file'))) return;
            await assert.rejects(inspectState(ws, `${SESSION_DIR}/linked-state.json`), { code: 'source_invalid' });
            await writeJson(dir, `${SESSION_DIR}/linked-child-state.json`, { task_id: 'linked-child', parent_task: { task_id: 'elsewhere', state_path: `${SESSION_DIR}/linked-state.json` } });
            const linkedTree = await sessionTreeOf(ws, await loadState(ws, PATHS.rootState));
            assert.deepEqual(linkedTree.tasks.map((task) => task.id).sort(), [CHILD_TASK, 'linked-child', 'stray-child', ROOT_TASK].sort(), 'the linked file is not a member');
            assert.deepEqual([...linkedTree.warnings].sort(), [
                `linked-child continues elsewhere, which could not be read: ${SESSION_DIR}/linked-state.json is not a regular file.`,
                ...tree.warnings,
            ].sort());
        });
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

    it('reads the branch and repository when the git files are there', async (t) => {
        assert.equal(await readGit(root), null);
        await fs.mkdir(path.join(root, '.git'));
        await fs.writeFile(path.join(root, '.git', 'HEAD'), 'ref: refs/heads/feat/offline-maps\n');
        await fs.writeFile(path.join(root, '.git', 'config'), '[core]\n\tbare = false\n[remote "origin"]\n\turl = git@github.com:contoso/trails.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n');
        assert.deepEqual(await readGit(root), { repository: 'contoso/trails', branch: 'feat/offline-maps' });
        await t.test('does not read a linked HEAD', async (t) => {
            const linkedRoot = path.join(tmp, 'linked-git-root');
            await fs.mkdir(path.join(linkedRoot, '.git'), { recursive: true });
            await fs.writeFile(path.join(tmp, 'outside-head'), 'ref: refs/heads/elsewhere\n');
            if (!(await symlinkOrSkip(t, path.join(tmp, 'outside-head'), path.join(linkedRoot, '.git', 'HEAD'), 'file'))) return;
            assert.equal(await readGit(linkedRoot), null);
        });
    });

    it('derives store IDs per workspace that fit the store pattern and never match the sample', () => {
        const here = storeIdFor('trail-maps', '/work/one');
        assert.match(here, /^rpi-trail-maps-[0-9a-f]{10}$/);
        assert.equal(storeIdFor('trail-maps', '/work/one'), here, 'the same workspace gives the same ID');
        assert.notEqual(here, storeIdFor('trail-maps', '/work/two'), 'one task ID in two workspaces keeps two documents');
        assert.match(storeIdFor('Task_With Spaces', '/work/one'), /^rpi-task-with-spaces-[0-9a-f]{8}-[0-9a-f]{10}$/);
        for (const taskId of ['x'.repeat(120), 'y'.repeat(60), 'Task_With Spaces', 'trail-maps']) {
            const id = storeIdFor(taskId, '/work/one');
            assert.match(id, /^rpi-[a-z0-9-]+$/);
            assert.ok(id.length <= 80, id);
        }
        assert.notEqual(storeIdFor('x'.repeat(120), '/work/one'), storeIdFor('x'.repeat(121), '/work/one'), 'long task IDs stay distinct');
    });
});

describe('loading and importing a task', () => {
    it('loads a task with its artifacts, session tree, and watched files', async () => {
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        assert.equal(loaded.session.id, storeIdFor(ROOT_TASK, root));
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
        assert.ok(loaded.warnings.some((text) => planNames.test(text) && /Inside a plan, links go to its own IDs first; elsewhere, to the current plan when it holds the ID, else to the newer one\.$/.test(text)), loaded.warnings.join(' | '));

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
        const documents = await writeEarlierWork(pairs, { research: EARLY_RESEARCH });
        // The agent implements the current work, with a blocker of its own.
        await writeJson(pairs, PATHS.rootState, {
            ...ROOT_STATE,
            active_phase: 'Implement',
            status: 'active',
            blockers: [{ id: 'B1', summary: 'P02-T02 waits on the tile server', resolution: null }],
            documents,
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

        for (const target of Object.values(EARLY)) assert.ok(loaded.watched.includes(target), `${target} is watched`);
        assert.ok(!loaded.warnings.some((text) => /\b(?:CH|DS|AL|RV|RD)-\d{3}\b/.test(text)), loaded.warnings.join(' | '));
    });

    it('keeps the current work\'s Provided research out of an earlier research document', async () => {
        const provided = path.join(tmp, 'provided-earlier');
        await writeFixtureWorkspace(provided);
        const documents = await writeEarlierWork(provided, { research: EARLY_RESEARCH });
        await writeJson(provided, PATHS.rootState, {
            ...ROOT_STATE,
            active_phase: 'Plan',
            status: 'active',
            confirmed_decisions: [
                ...ROOT_STATE.confirmed_decisions.filter((item) => item.decision !== 'Research disposition'),
                { decision: 'Research disposition', status: 'provided', evidence: `Copied from session 3fa85f64-5717-4562-b3fc-2c963f66afa6; path ${EARLY.research}; content hash 9f2c4e1a` },
            ],
            documents,
        });
        const loaded = await loadTask(await resolveWorkspace([provided]), PATHS.rootState, NOW);
        const [earlier, current] = loaded.session.documents.research;
        assert.equal(current.current, true);
        assert.notEqual(earlier.snapshot.record.status, 'provided', 'an earlier document keeps its own status');
        assert.equal(earlier.snapshot.sections['research-source'], undefined, 'and its own sections');
        assert.equal(loaded.session.phases.research.status, 'provided');
        assert.match(loaded.session.sections['research-source'].markdown, /^Research came from session 3fa85f64\./);
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

    it('watches only the shown task\'s files, so a linked task in another session never moves an import', async (t) => {
        const OTHER = '8c9d0e1f-2a3b-4c4d-8e5f-6a7b8c9d0e1f';
        const dir = path.join(tmp, 'follow-linked');
        const elsewhere = path.join(tmp, 'follow-linked-elsewhere');
        const sessions = path.join(tmp, 'follow-linked-sessions');
        await writeFixtureWorkspace(dir);
        await writeFixtureWorkspace(elsewhere);
        await fs.rm(path.join(dir, PATHS.childState));
        await writeJson(dir, PATHS.rootState, { ...ROOT_STATE, child_tasks: [{ task_id: CHILD_TASK, task_slug: CHILD_TASK, state_path: PATHS.childState, session_id: OTHER }] });
        await fs.mkdir(path.join(sessions, OTHER), { recursive: true });
        await fs.writeFile(path.join(sessions, OTHER, 'workspace.yaml'), `cwd: ${elsewhere}\n`);
        const store = createStore({ root: path.join(tmp, 'follow-linked-store') });
        t.after(() => store.close());
        const follower = createFollower({ store, workspace: await resolveWorkspace([dir]), statePath: PATHS.rootState, intervalMs: 10000, resolveSession: (id) => resolveSessionWorkspace(id, { root: sessions }) });
        await follower.importNow();
        const doc = await store.load(follower.documentId);
        assert.deepEqual(doc.followUps.tree.tasks.map((task) => [task.id, task.sessionId]), [[ROOT_TASK, null], [CHILD_TASK, OTHER]]);
        const revision = doc.revision;
        await writeJson(elsewhere, PATHS.childState, { ...CHILD_STATE, status: 'active' });
        assert.equal(await follower.tick(), false, 'the linked task\'s file is not watched');
        assert.equal(await follower.tick(), false);
        assert.equal((await store.load(follower.documentId)).revision, revision);
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

describe('sessions resolve to their workspaces', () => {
    const SESSION = '3f2a6c1e-8d4b-4f7a-9c2e-1a2b3c4d5e6f';
    const OTHER = '7b9e1d2c-4a6f-4e8b-8c3d-2f1e0a9b8c7d';
    const UNKNOWN = '00000000-0000-4000-8000-000000000000';
    const NO_YAML = '11111111-2222-4333-8444-555555555555';
    const EMPTY = '22222222-3333-4444-8555-666666666666';
    const RELATIVE = '33333333-4444-4555-8666-777777777777';
    const NO_TRACKING = '44444444-5555-4666-8777-888888888888';
    const LINKED_TRACKING = '55555555-6666-4777-8888-999999999999';
    const ESCAPES = '66666666-7777-4888-8999-aaaaaaaaaaaa';
    const LINKED_YAML = '77777777-8888-4999-8aaa-bbbbbbbbbbbb';
    const DENIED = '88888888-9999-4aaa-8bbb-cccccccccccc';
    let scratch;
    let stateRoot;

    before(async () => {
        scratch = await scratchFolder('sessions');
        stateRoot = path.join(scratch, 'session-state');
        await fs.mkdir(stateRoot);
    });
    after(() => fs.rm(scratch, { recursive: true, force: true }));

    /** A workspace root in the scratch folder, with a tracking folder unless `tracking` is false. */
    async function workspaceAt(name, tracking = true) {
        const dir = path.join(scratch, name);
        await fs.mkdir(tracking ? path.join(dir, '.copilot-tracking') : dir, { recursive: true });
        return dir;
    }

    /** A session folder whose `workspace.yaml` holds `lines`, or no file when `lines` is null. */
    async function sessionAt(id, lines) {
        const folder = path.join(stateRoot, id);
        await fs.mkdir(folder, { recursive: true });
        if (lines !== null) await fs.writeFile(path.join(folder, 'workspace.yaml'), `${lines.join('\n')}\n`);
        return folder;
    }

    const resolveAt = (id) => resolveSessionWorkspace(id, { root: stateRoot });

    it('takes the workspace from git_root, then cwd, and reads the session ID in any letter case', async () => {
        const gitRoot = await workspaceAt('git-root');
        const cwd = await workspaceAt('cwd');
        await sessionAt(SESSION, [`git_root: ${gitRoot}`, `cwd: ${cwd}`]);
        const expected = { root: await fs.realpath(gitRoot), tracking: await fs.realpath(path.join(gitRoot, '.copilot-tracking')) };
        assert.deepEqual(await resolveAt(SESSION), expected);
        assert.deepEqual(await resolveAt(SESSION.toUpperCase()), expected);

        const bare = await workspaceAt('bare', false);
        await sessionAt(OTHER, [`git_root: ${bare}`, `cwd: ${cwd}`]);
        assert.equal((await resolveAt(OTHER)).root, await fs.realpath(cwd), 'cwd is the candidate when git_root has no tracking folder');
    });

    it('takes only absolute workspace paths', async () => {
        const dir = await workspaceAt('absolute-only');
        await sessionAt(EMPTY, ['git_root: relative/repo', `cwd: ${dir}`]);
        assert.equal((await resolveAt(EMPTY)).root, await fs.realpath(dir));
        await sessionAt(RELATIVE, ['git_root: relative/repo', 'cwd: also/relative']);
        await assert.rejects(resolveAt(RELATIVE), { code: 'session_no_workspace' });
    });

    it('refuses an ID that is not a session ID, in any form', async () => {
        for (const bad of ['', 'not-a-session', `../${SESSION}`, `${SESSION}/..`, `${SESSION}\u0000`, `${SESSION}-x`, '../../etc', 42, null]) {
            await assert.rejects(resolveAt(bad), { code: 'session_invalid' }, JSON.stringify(bad));
        }
    });

    it('names the path for an unknown session, a session with no workspace, and a workspace with no tracking folder', async () => {
        await assert.rejects(resolveAt(UNKNOWN), (error) => error.code === 'session_not_found' && error.message.includes(stateRoot));
        await sessionAt(NO_YAML, null);
        await assert.rejects(resolveAt(NO_YAML), (error) => error.code === 'session_no_workspace' && error.message.includes(path.join(stateRoot, NO_YAML)));
        await sessionAt(RELATIVE, ['name: nothing here']);
        await assert.rejects(resolveAt(RELATIVE), { code: 'session_no_workspace' }, 'a file with no workspace path');
        const bare = await workspaceAt('no-tracking', false);
        await sessionAt(NO_TRACKING, [`cwd: ${bare}`]);
        await assert.rejects(resolveAt(NO_TRACKING), (error) => error.code === 'session_no_tracking' && error.detail === path.join(bare, '.copilot-tracking') && error.message.includes(path.join(bare, '.copilot-tracking')));
    });

    it('refuses a tracking folder that is a symbolic link', async (t) => {
        const real = await workspaceAt('real-tracking');
        const linked = await workspaceAt('linked-tracking', false);
        await sessionAt(LINKED_TRACKING, [`cwd: ${linked}`]);
        if (!(await symlinkOrSkip(t, path.join(real, '.copilot-tracking'), path.join(linked, '.copilot-tracking'), 'dir'))) return;
        await assert.rejects(resolveAt(LINKED_TRACKING), { code: 'session_no_tracking' });
    });

    it('refuses a session folder that leads outside the session-state root', async (t) => {
        const outside = path.join(scratch, 'outside-session');
        await fs.mkdir(outside, { recursive: true });
        await fs.writeFile(path.join(outside, 'workspace.yaml'), `cwd: ${await workspaceAt('escape-target')}\n`);
        if (!(await symlinkOrSkip(t, outside, path.join(stateRoot, ESCAPES), 'dir'))) return;
        await assert.rejects(resolveAt(ESCAPES), { code: 'session_invalid' });
    });

    it('refuses a workspace file that is a symbolic link', async (t) => {
        const target = path.join(scratch, 'real-workspace.yaml');
        await fs.writeFile(target, `cwd: ${await workspaceAt('linked-yaml-target')}\n`);
        await fs.mkdir(path.join(stateRoot, LINKED_YAML));
        if (!(await symlinkOrSkip(t, target, path.join(stateRoot, LINKED_YAML, 'workspace.yaml'), 'file'))) return;
        await assert.rejects(resolveAt(LINKED_YAML), { code: 'session_no_workspace' });
    });

    it('reads through the file functions it is given', async () => {
        const dir = await workspaceAt('injected');
        await sessionAt(DENIED, [`cwd: ${dir}`]);
        const denied = { readFile: async () => { throw Object.assign(new Error('denied'), { code: 'EACCES' }); } };
        await assert.rejects(resolveSessionWorkspace(DENIED, { root: stateRoot, fs: denied }), { code: 'session_no_workspace' });
        assert.equal((await resolveAt(DENIED)).root, await fs.realpath(dir));
    });

    it('finds the session-state folder from the joined workspace, then COPILOT_HOME, then the home folder', () => {
        const joined = path.join(scratch, 'copilot-a', 'session-state');
        assert.deepEqual(resolveSessionStateRoot({ workspacePath: path.join(joined, SESSION), env: {}, homedir: '/unused' }), { root: joined, source: 'workspace' });
        assert.deepEqual(resolveSessionStateRoot({ workspacePath: path.join(scratch, 'elsewhere'), env: { COPILOT_HOME: '/copilot-home' }, homedir: '/unused' }), { root: path.join('/copilot-home', 'session-state'), source: 'COPILOT_HOME' });
        assert.deepEqual(resolveSessionStateRoot({ workspacePath: '/nowhere/not-a-session', env: { COPILOT_HOME: '' }, homedir: '/home/me' }), { root: path.join('/home/me', '.copilot', 'session-state'), source: 'home' });
    });

    it('reads the top-level keys of workspace.yaml, unquoting values and skipping nested content', () => {
        const parsed = parseWorkspaceYaml([
            'id: 3f2a',
            'cwd: /work/app: beta',
            "git_root: '/work/it''s'",
            'name: "Trail \\"maps\\""',
            'empty:',
            'summary: |',
            '  cwd: /not/this',
            'nested:',
            '  cwd: /not/this/either',
        ].join('\n'));
        assert.deepEqual([parsed.id, parsed.cwd, parsed.git_root, parsed.name, parsed.empty], ['3f2a', '/work/app: beta', "/work/it's", 'Trail "maps"', null]);
    });
});

describe('documents keyed by workspace', () => {
    let scratch;
    let workspaceA;
    let workspaceB;
    const LEGACY_ID = `rpi-${ROOT_TASK}`;

    before(async () => {
        scratch = await scratchFolder('keys');
        await writeFixtureWorkspace(path.join(scratch, 'repo-a'));
        await writeFixtureWorkspace(path.join(scratch, 'repo-b'));
        workspaceA = await resolveWorkspace([path.join(scratch, 'repo-a')]);
        workspaceB = await resolveWorkspace([path.join(scratch, 'repo-b')]);
    });
    after(() => fs.rm(scratch, { recursive: true, force: true }));

    const comment = (text) => (session) => createFeedback(session, { kind: 'comment', text }, NOW);

    it('keeps one task in two workspaces apart, and gives one workspace one document', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-apart') });
        t.after(() => store.close());
        const first = await importIntoStore(store, await loadTask(workspaceA, PATHS.rootState, NOW), NOW);
        const second = await importIntoStore(store, await loadTask(workspaceB, PATHS.rootState, NOW), NOW);
        assert.equal(first.session.id, storeIdFor(ROOT_TASK, workspaceA.root));
        assert.notEqual(first.session.id, second.session.id);
        assert.equal((await importIntoStore(store, await loadTask(workspaceA, PATHS.rootState, NOW), NOW)).changed, false);
    });

    it('starts a workspace document from the matching earlier one once, and keeps the earlier one', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-migrate') });
        t.after(() => store.close());
        const loaded = await loadTask(workspaceA, PATHS.rootState, NOW);
        await store.create({ ...loaded.session, id: LEGACY_ID });
        await store.update(LEGACY_ID, comment('Kept from before'), { by: 'user' });
        const migrated = await importIntoStore(store, loaded, NOW);
        assert.equal(migrated.session.id, loaded.session.id);
        assert.deepEqual(migrated.session.feedback.map((item) => item.text), ['Kept from before']);
        assert.equal(migrated.session.scenario.userChanges, 1, 'the migrated changes keep their count');
        assert.equal((await store.load(LEGACY_ID)).feedback.length, 1, 'the earlier document stays');

        await store.update(LEGACY_ID, comment('Added to the old document'), { by: 'user' });
        const again = await importIntoStore(store, await loadTask(workspaceA, PATHS.rootState, NOW), NOW);
        assert.deepEqual(again.session.feedback.map((item) => item.text), ['Kept from before'], 'the migration copies once');
    });

    it('leaves an earlier document from another workspace alone', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-other-root') });
        t.after(() => store.close());
        const loaded = await loadTask(workspaceA, PATHS.rootState, NOW);
        await store.create({ ...loaded.session, id: LEGACY_ID, source: { ...loaded.session.source, root: workspaceB.root } });
        await store.update(LEGACY_ID, comment('Belongs to the other workspace'), { by: 'user' });
        const fresh = await importIntoStore(store, loaded, NOW);
        assert.deepEqual(fresh.session.feedback, [], 'nothing moves across workspaces');
        assert.equal((await store.load(LEGACY_ID)).feedback.length, 1);
        assert.equal((await store.load(LEGACY_ID)).source.root, workspaceB.root);
    });

    it('lists a related task from its earlier document in the same workspace, and not from another', async (t) => {
        const store = createStore({ root: path.join(scratch, 'store-related') });
        t.after(() => store.close());
        const shown = await importIntoStore(store, await loadTask(workspaceA, PATHS.rootState, NOW), NOW);
        const child = await loadTask(workspaceA, PATHS.childState, NOW);
        await store.create({ ...child.session, id: `rpi-${CHILD_TASK}` });
        await store.update(`rpi-${CHILD_TASK}`, comment('Earlier child note'), { by: 'user' });
        const source = { kind: 'rpi', workspace: workspaceA };
        const listed = await loadSessionDocs(store, shown.session, source);
        assert.deepEqual(listed.map((doc) => [doc.taskId, doc.id, doc.session.feedback.length]), [[ROOT_TASK, shown.session.id, 0], [CHILD_TASK, `rpi-${CHILD_TASK}`, 1]]);
        const otherStore = createStore({ root: path.join(scratch, 'store-related-other') });
        t.after(() => otherStore.close());
        await otherStore.create({ ...child.session, id: `rpi-${CHILD_TASK}`, source: { ...child.session.source, root: workspaceB.root } });
        const unlisted = await loadSessionDocs(otherStore, shown.session, source);
        assert.deepEqual(unlisted.map((doc) => doc.taskId), [ROOT_TASK], 'a document from another workspace is not listed');
    });
});

describe('git worktrees', () => {
    let scratch;

    before(async () => {
        scratch = await scratchFolder('git');
    });
    after(() => fs.rm(scratch, { recursive: true, force: true }));

    const ORIGIN = '[remote "origin"]\n\turl = git@github.com:contoso/trails.git\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n';

    /**
     * A main checkout with a linked worktree named `feature`, laid out as git writes them. The
     * worktree's `.git` file points at `pointer` (its git directory by default).
     */
    async function worktree(name, { pointer, config = `[core]\n\tbare = false\n${ORIGIN}` } = {}) {
        const main = path.join(scratch, name, 'main');
        const gitdir = path.join(main, '.git', 'worktrees', 'feature');
        await fs.mkdir(gitdir, { recursive: true });
        await fs.writeFile(path.join(main, '.git', 'HEAD'), 'ref: refs/heads/main\n');
        await fs.writeFile(path.join(main, '.git', 'config'), config);
        await fs.writeFile(path.join(gitdir, 'HEAD'), 'ref: refs/heads/feat/offline-maps\n');
        await fs.writeFile(path.join(gitdir, 'commondir'), '../..\n');
        const root = path.join(scratch, name, 'feature');
        await fs.mkdir(root, { recursive: true });
        await fs.writeFile(path.join(root, '.git'), `gitdir: ${pointer ?? gitdir}\n`);
        return { main, gitdir, root };
    }

    it('reads the branch from the worktree and the repository from the common config', async () => {
        const { root } = await worktree('absolute');
        assert.deepEqual(await readGit(root), { repository: 'contoso/trails', branch: 'feat/offline-maps' });
    });

    it('reads a relative gitdir pointer the same way', async () => {
        const { root } = await worktree('relative', { pointer: '../main/.git/worktrees/feature' });
        assert.deepEqual(await readGit(root), { repository: 'contoso/trails', branch: 'feat/offline-maps' });
    });

    it('leaves the header empty for a pointer that names no git directory or has no pointer line', async () => {
        const missing = await worktree('missing', { pointer: path.join(scratch, 'nowhere', 'gitdir') });
        assert.equal(await readGit(missing.root), null);
        const plain = path.join(scratch, 'plain-file');
        await fs.mkdir(plain, { recursive: true });
        await fs.writeFile(path.join(plain, '.git'), 'not a pointer\n');
        assert.equal(await readGit(plain), null);
    });

    it('reads the config from the git directory itself when there is no common directory', async () => {
        const gitdir = path.join(scratch, 'standalone', 'gitdir');
        await fs.mkdir(gitdir, { recursive: true });
        await fs.writeFile(path.join(gitdir, 'HEAD'), 'ref: refs/heads/topic\n');
        await fs.writeFile(path.join(gitdir, 'config'), ORIGIN);
        const root = path.join(scratch, 'standalone', 'checkout');
        await fs.mkdir(root, { recursive: true });
        await fs.writeFile(path.join(root, '.git'), `gitdir: ${gitdir}\n`);
        assert.deepEqual(await readGit(root), { repository: 'contoso/trails', branch: 'topic' });
    });

    it('keeps the branch when the common config is too large to read', async () => {
        const { root } = await worktree('large', { config: `${ORIGIN}${'# filler\n'.repeat(9000)}` });
        assert.deepEqual(await readGit(root), { repository: null, branch: 'feat/offline-maps' });
    });

    it('does not read a pointer file that is a symbolic link', async (t) => {
        const { root } = await worktree('linked-pointer');
        const linked = path.join(scratch, 'linked-pointer', 'alias');
        await fs.mkdir(linked, { recursive: true });
        await fs.writeFile(path.join(scratch, 'linked-pointer', 'real-pointer'), `gitdir: ${path.join(root, '..', 'main', '.git', 'worktrees', 'feature')}\n`);
        if (!(await symlinkOrSkip(t, path.join(scratch, 'linked-pointer', 'real-pointer'), path.join(linked, '.git'), 'file'))) return;
        assert.equal(await readGit(linked), null);
    });
});

