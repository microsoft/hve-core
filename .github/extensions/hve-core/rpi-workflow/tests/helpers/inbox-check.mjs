// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Test helper: runs one inbox check in a separate process, recording each send in a log file.
import { appendFileSync } from 'node:fs';

import { createInboxRunner } from '../../lib/inbox.mjs';
import { createStore } from '../../lib/store.mjs';

const [root, sessionId, pidText, sendLog] = process.argv.slice(2);
const store = createStore({ root, lockWaitMs: 15000 });
const runner = createInboxRunner({
    store,
    sessionId,
    pid: Number(pidText),
    deliver: async (request) => {
        appendFileSync(sendLog, `${request.ids.join(',')}\n`);
        return { messageId: `message-${pidText}` };
    },
});
await runner.checkInbox();
store.close();
