// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Test helper: appends N tagged activity lines to a stored session from a separate process.
import { recordActivity } from '../../lib/model.mjs';
import { createStore } from '../../lib/store.mjs';

const [root, id, tag, countText] = process.argv.slice(2);
const store = createStore({ root, lockWaitMs: 15000 });
const count = Number(countText);
for (let i = 0; i < count; i += 1) {
    await store.update(id, (session) => recordActivity(session, { text: `${tag} ${i}`, kind: 'run' }, new Date().toISOString()));
}
store.close();
