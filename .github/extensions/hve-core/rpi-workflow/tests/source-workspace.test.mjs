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
    importIntoStore,
    inspectContained,
    lineageOf,
    listStates,
    loadState,
    loadTask,
    MAX_FILE_BYTES,
    readContained,
    readGit,
    resolveTask,
    resolveWorkspace,
    sourceSignature,
    storeIdFor,
} from '../lib/source/workspace.mjs';
import { createStore } from '../lib/store.mjs';
import { CHILD_TASK, PATHS, ROOT_TASK, writeFixtureWorkspace } from './helpers/rpi-fixture.mjs';

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
    it('lists states newest first and resolves current to the root of the newest running session', async () => {
        const states = await listStates(workspace);
        assert.equal(states.length, 3);
        assert.equal(states.at(-1).path, PATHS.staleState, 'the stale session is oldest');
        assert.deepEqual(await resolveTask(workspace, 'current'), { statePath: PATHS.rootState, taskId: ROOT_TASK, warnings: [] });
        assert.equal((await resolveTask(workspace, CHILD_TASK)).statePath, PATHS.childState);
        await assert.rejects(resolveTask(workspace, 'no-such-task'), { code: 'source_not_found' });
    });

    it('walks from a running child up to its root', async () => {
        const child = JSON.parse(await fs.readFile(path.join(root, PATHS.childState), 'utf8'));
        const childRoot = path.join(tmp, 'running-child');
        await writeFixtureWorkspace(childRoot);
        await fs.writeFile(path.join(childRoot, PATHS.childState), JSON.stringify({ ...child, session_status: 'running', status: 'active' }));
        const old = new Date(Date.now() - 3600 * 1000);
        await fs.utimes(path.join(childRoot, PATHS.rootState), old, old);
        const resolved = await resolveTask(await resolveWorkspace([childRoot]), 'current');
        assert.equal(resolved.taskId, ROOT_TASK);
    });

    it('builds lineage in both directions', async () => {
        const rootLineage = await lineageOf(workspace, await loadState(workspace, PATHS.rootState));
        assert.deepEqual(rootLineage.map((item) => [item.taskId, item.relation, item.status, item.title]), [
            [ROOT_TASK, 'this', 'completed', 'Offline trail maps'],
            [CHILD_TASK, 'child', 'completed', 'Offline trail maps review fixes'],
        ]);
        const childLineage = await lineageOf(workspace, await loadState(workspace, PATHS.childState));
        assert.deepEqual(childLineage.map((item) => [item.taskId, item.relation]), [[ROOT_TASK, 'parent'], [CHILD_TASK, 'this']]);
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
    it('loads a task with its artifacts, lineage, and watched files', async () => {
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        assert.equal(loaded.session.id, 'rpi-trail-maps');
        assert.equal(loaded.session.task.title, 'Offline trail maps');
        assert.equal(loaded.session.task.branch, 'feat/offline-maps');
        assert.equal(loaded.session.followUps.lineage.length, 2);
        assert.deepEqual(loaded.warnings, []);
        assert.equal(loaded.watched.length, 6);
        assert.equal(loaded.session.source.root, root);
        const child = await loadTask(workspace, PATHS.childState, NOW);
        assert.equal(child.session.phases.research.status, 'skipped');
        assert.deepEqual(child.warnings, [], 'reused research is not a problem');
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

    it('changes the signature when a watched file or the set of states changes', async () => {
        const loaded = await loadTask(workspace, PATHS.rootState, NOW);
        const first = await sourceSignature(workspace, loaded.watched);
        assert.equal(await sourceSignature(workspace, loaded.watched), first);
        const later = new Date(Date.now() + 5000);
        await fs.utimes(path.join(root, PATHS.plan), later, later);
        const second = await sourceSignature(workspace, loaded.watched);
        assert.notEqual(second, first);
        await fs.writeFile(path.join(root, '.copilot-tracking/rpi-sessions/2026-01-15/another-state.json'), JSON.stringify({ task_id: 'another', parent_task: { task_id: ROOT_TASK } }));
        assert.notEqual(await sourceSignature(workspace, loaded.watched), second);
        await fs.rm(path.join(root, '.copilot-tracking/rpi-sessions/2026-01-15/another-state.json'));
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
