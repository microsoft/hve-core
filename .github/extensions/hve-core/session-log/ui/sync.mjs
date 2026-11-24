// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Live-update bookkeeping for the page, kept free of the DOM so it can be tested directly.
 */

/**
 * Advances the poll cursor after a poll answer that carries changes.
 *
 * At the tail of the log the cursor counts only the entries the answer delivered, and while more
 * pages wait it keeps the previous version, so the next poll returns them instead of reporting the
 * log unchanged. Away from the tail nothing is appended, so the cursor takes the advertised total.
 *
 * @param {{ total: number, version: number }} cursor Entries the page accounts for, and the index version it last applied.
 * @param {{ total: number, version: number, next?: number, more?: boolean }} answer Poll answer with changes.
 * @param {boolean} atTail Whether the page showed the newest entry when the answer arrived.
 * @returns {{ total: number, version: number }}
 */
export function advanceCursor(cursor, answer, atTail) {
    if (!atTail) {
        return { total: Math.max(answer.total, cursor.total), version: answer.version };
    }
    const delivered = Number.isInteger(answer.next) ? answer.next : answer.total;
    return { total: Math.max(delivered, cursor.total), version: answer.more ? cursor.version : answer.version };
}

/**
 * @param {number} attempt Failed attempts so far, starting at 1.
 * @returns {number} Milliseconds before the next attempt: two seconds, doubling to at most thirty.
 */
export function retryDelay(attempt) {
    return Math.min(30000, 2000 * 2 ** Math.max(0, attempt - 1));
}
