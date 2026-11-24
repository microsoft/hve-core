// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createFeedback } from '../../lib/model.mjs';
import { buildScenario } from '../../lib/scenario.mjs';

/** The store ID of the document `taskDoc` builds. */
export const TASK_DOC = 'rpi-report-export-csv-0123456789';

/**
 * A task document of one RPI task with three queued comments, FB-001 to FB-003, made at `now`.
 *
 * @param {string} now an ISO time
 */
export function taskDoc(now) {
    const sample = buildScenario('research', Date.parse(now));
    let session = {
        ...sample,
        id: TASK_DOC,
        feedback: [],
        task: { ...sample.task, id: 'report-export-csv', title: 'Export the report as CSV' },
        source: {
            kind: 'rpi',
            statePath: 'workspace/rpi-sessions/2026-11-09/report/report-export-csv-state.json',
            artifacts: { research: 'workspace/research/2026-11-09/report-export-csv-research.md' },
        },
    };
    for (const text of ['Keep the header row.', 'Quote the commas.', 'Ship it on Friday.']) {
        session = createFeedback(session, { kind: 'comment', text, target: { id: 'F1' } }, now).session;
    }
    return session;
}
