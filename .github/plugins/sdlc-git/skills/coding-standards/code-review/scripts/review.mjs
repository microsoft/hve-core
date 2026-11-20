// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { parseArgs } from 'node:util';
import { check } from './lib/model.mjs';
import { captureReview } from './lib/snapshot.mjs';
import { loadReview, MAX_RECORD_BYTES, reviewRoot } from './lib/storage.mjs';
import { assessFindings, decideFindings, mergeStoredResult, renderReport, schedule, setWork, updateContext, writeResult } from './lib/operations.mjs';

async function input() {
    const chunks = [];
    let size = 0;
    for await (const chunk of process.stdin) {
        size += chunk.length;
        check(size <= MAX_RECORD_BYTES, 'Input exceeds the record budget.', 'invalid_input');
        chunks.push(chunk);
    }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

try {
    const { values, positionals } = parseArgs({
        allowPositionals: true,
        options: { repo: { type: 'string' }, root: { type: 'string' }, revision: { type: 'string' } },
    });
    check(positionals.length === 1 && values.repo, 'Usage: node review.mjs <capture|status|schedule|work|result|merge|assess|decide|context|render> --repo <repository> [--root <review-root>] [--revision <expected>] < request.json', 'invalid_input');
    const [command] = positionals;
    const revision = values.revision === undefined ? undefined : Number(values.revision);
    let result;
    if (command === 'capture') {
        const captured = await captureReview(values.repo, await input(), values.root, revision);
        result = { root: captured.relative, reviewId: captured.state.reviewId, snapshotId: captured.snapshot.snapshotId, revision: captured.state.revision };
    } else {
        const location = await reviewRoot(values.repo, values.root);
        if (command === 'status') result = await loadReview(location);
        else if (command === 'render') result = await renderReport(location, revision);
        else if (command === 'result') result = await writeResult(location, await input());
        else {
            const operation = { schedule, work: setWork, merge: mergeStoredResult, assess: assessFindings, decide: decideFindings, context: updateContext }[command];
            check(operation, 'Unknown command.', 'invalid_input');
            result = await operation(location, revision, await input());
        }
    }
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
} catch (error) {
    process.stderr.write(`${JSON.stringify({ error: error.code ?? 'operation_failed', message: error.message })}\n`);
    process.exitCode = 1;
}
