// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { hasLiveProcess } from './inbox.mjs';
import { deriveView } from './model.mjs';
import { currentLinkedState, legacyDocumentFor, storeIdFor } from './source/workspace.mjs';

/**
 * The store documents of a session: the shown task's document first, then the documents
 * of the other tasks in its session tree that exist in the store, in tree order. A related
 * task whose document is not keyed to this workspace yet is read from its earlier document
 * when that came from the same workspace, so its feedback stays listed until it is imported.
 * A task that another Copilot session holds is left out: its feedback belongs to that session's
 * own canvas. A canvas that shows the sample, or any source other than RPI files, has only its own document.
 *
 * @param {ReturnType<typeof import('./store.mjs').createStore>} store
 * @param {any} shown The shown task's document.
 * @param {{ kind?: string, workspace?: { root: string } } | undefined} source
 * @returns {Promise<{ id: string, taskId: string, session: any, task: any | null }[]>}
 */
export async function loadSessionDocs(store, shown, source) {
    const docs = [{ id: shown.id, taskId: shown.task.id, session: shown, task: null }];
    if (source?.kind !== 'rpi') return docs;
    const root = source.workspace?.root ?? '';
    const seen = new Set([shown.id]);
    for (const task of shown.followUps?.tree?.tasks ?? []) {
        if (task.shown) {
            docs[0].task = task;
            continue;
        }
        if (task.sessionId) continue;
        const id = storeIdFor(task.id, root);
        if (seen.has(id)) continue;
        seen.add(id);
        const session = (await store.load(id).catch(() => undefined)) ?? (await legacyDocumentFor(store, task.id, root));
        if (session) docs.push({ id: session.id, taskId: task.id, session, task });
    }
    return docs;
}

/** The decisions a document shows as needing the user, or null when the document cannot be read. */
function decisionsWaitingOf(session) {
    try {
        return deriveView(session).needsYou.map((item) => ({ id: item.id, title: item.title }));
    } catch {
        return null;
    }
}

/**
 * The tasks of the shown session's tree that another Copilot session holds and that the canvas can
 * read from that session's workspace: each has a session ID and the workspace root it names.
 *
 * @param {any} shown The shown task's document.
 * @returns {any[]}
 */
export function linkedTasksOf(shown) {
    return (shown.followUps?.tree?.tasks ?? []).filter((task) => task.sessionId && task.root);
}

/**
 * The tasks of a session's tree that another Copilot session holds, each with its session, its phase
 * and status as the task's state file records them now (or as the tree recorded them when that file
 * cannot be read), the decisions waiting from its store document, and whether a canvas process of that
 * session is live. The document is the one keyed to the task's own workspace, so a task of the same ID
 * in another workspace is not read. `decisionsWaiting` is null when no canvas has read the task yet.
 *
 * @param {ReturnType<typeof import('./store.mjs').createStore>} store
 * @param {any} shown The shown task's document.
 * @param {{ at?: number }} [options] `at` is the time liveness is judged at, in milliseconds; the current time by default.
 * @returns {Promise<{ taskId: string, sessionId: string, sessionName: string | null, statePath: string, phase: string | null, status: string, decisionsWaiting: { id: string, title: string }[] | null, live: boolean }[]>}
 */
export async function loadLinkedSessions(store, shown, options = {}) {
    const at = options.at ?? Date.now();
    const linked = [];
    for (const task of linkedTasksOf(shown)) {
        const session = (await store.load(storeIdFor(task.id, task.root)).catch(() => undefined)) ?? (await legacyDocumentFor(store, task.id, task.root));
        const presence = await store.loadPresence(task.sessionId).catch(() => null);
        const current = await currentLinkedState(task.root, task.id, task.statePath);
        linked.push({
            taskId: task.id,
            sessionId: task.sessionId,
            sessionName: task.sessionName ?? null,
            statePath: task.statePath,
            phase: current ? current.phase : (task.phase ?? null),
            status: current ? current.status : task.status,
            decisionsWaiting: session ? decisionsWaitingOf(session) : null,
            live: hasLiveProcess(presence, at),
        });
    }
    return linked;
}
