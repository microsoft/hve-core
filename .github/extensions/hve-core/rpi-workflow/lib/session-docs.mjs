// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { storeIdFor } from './source/workspace.mjs';

/**
 * The store documents of a session: the shown task's document first, then the documents
 * of the other tasks in its session tree that exist in the store, in tree order. A canvas
 * that shows the sample, or any source other than RPI files, has only its own document.
 *
 * @param {ReturnType<typeof import('./store.mjs').createStore>} store
 * @param {any} shown The shown task's document.
 * @param {{ kind?: string } | undefined} source
 * @returns {Promise<{ id: string, taskId: string, session: any, task: any | null }[]>}
 */
export async function loadSessionDocs(store, shown, source) {
    const docs = [{ id: shown.id, taskId: shown.task.id, session: shown, task: null }];
    if (source?.kind !== 'rpi') return docs;
    const seen = new Set([shown.id]);
    for (const task of shown.followUps?.tree?.tasks ?? []) {
        if (task.shown) {
            docs[0].task = task;
            continue;
        }
        const id = storeIdFor(task.id);
        if (seen.has(id)) continue;
        seen.add(id);
        const session = await store.load(id).catch(() => undefined);
        if (session) docs.push({ id, taskId: task.id, session, task });
    }
    return docs;
}
