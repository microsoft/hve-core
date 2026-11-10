// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { legacyDocumentFor, storeIdFor } from './source/workspace.mjs';

/**
 * The store documents of a session: the shown task's document first, then the documents
 * of the other tasks in its session tree that exist in the store, in tree order. A related
 * task whose document is not keyed to this workspace yet is read from its earlier document
 * when that came from the same workspace, so its feedback stays listed until it is imported.
 * A canvas that shows the sample, or any source other than RPI files, has only its own document.
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
        const id = storeIdFor(task.id, root);
        if (seen.has(id)) continue;
        seen.add(id);
        const session = (await store.load(id).catch(() => undefined)) ?? (await legacyDocumentFor(store, task.id, root));
        if (session) docs.push({ id: session.id, taskId: task.id, session, task });
    }
    return docs;
}
