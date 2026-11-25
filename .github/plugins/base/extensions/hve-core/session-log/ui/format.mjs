// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Formats a token count as 950, 12.4k, 968k, or 1.4M.
 *
 * @param {number | null | undefined} value
 * @returns {string}
 */
export function formatTokens(value) {
    if (!Number.isFinite(value)) {
        return 'Not recorded';
    }
    const abs = Math.abs(value);
    if (abs < 1000) {
        return String(Math.round(value));
    }
    if (abs < 100000) {
        return `${trim(value / 1000, 1)}k`;
    }
    if (abs < 1000000) {
        return `${Math.round(value / 1000)}k`;
    }
    return `${trim(value / 1000000, 1)}M`;
}

/**
 * Formats a duration as 850 ms, 12.4 s, or 3 m 05 s.
 *
 * @param {number | null | undefined} ms
 * @returns {string}
 */
export function formatDuration(ms) {
    if (!Number.isFinite(ms)) {
        return '';
    }
    if (ms < 1000) {
        return `${Math.round(ms)} ms`;
    }
    if (ms < 60000) {
        return `${trim(ms / 1000, 1)} s`;
    }
    const totalSeconds = Math.round(ms / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    if (hours > 0) {
        return `${hours} h ${String(minutes).padStart(2, '0')} m`;
    }
    return `${minutes} m ${String(seconds).padStart(2, '0')} s`;
}

/**
 * Formats a character count as an approximate size.
 *
 * @param {number | null | undefined} chars
 * @returns {string}
 */
export function formatSize(chars) {
    if (!Number.isFinite(chars)) {
        return '';
    }
    if (chars < 1024) {
        return `${chars} chars`;
    }
    if (chars < 1024 * 1024) {
        return `${trim(chars / 1024, chars < 10240 ? 1 : 0)} KB`;
    }
    return `${trim(chars / (1024 * 1024), 1)} MB`;
}

/**
 * Formats an ISO timestamp as local HH:MM:SS.
 *
 * @param {string | null | undefined} iso
 * @returns {string}
 */
export function formatTime(iso) {
    const date = toDate(iso);
    if (!date) {
        return '';
    }
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
}

/**
 * Formats an ISO timestamp as "Today 14:02" or "Oct 19".
 *
 * @param {string | null | undefined} iso
 * @param {Date} [now]
 * @returns {string}
 */
export function formatRelativeDate(iso, now = new Date()) {
    const date = toDate(iso);
    if (!date) {
        return '';
    }
    const sameDay = date.toDateString() === now.toDateString();
    if (sameDay) {
        return `Today ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })}`;
    }
    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    if (date.toDateString() === yesterday.toDateString()) {
        return `Yesterday ${date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })}`;
    }
    const sameYear = date.getFullYear() === now.getFullYear();
    return date.toLocaleDateString([], sameYear ? { month: 'short', day: 'numeric' } : { year: 'numeric', month: 'short', day: 'numeric' });
}

/**
 * @param {number | null | undefined} part
 * @param {number | null | undefined} whole
 * @returns {number | null}
 */
export function percent(part, whole) {
    if (!Number.isFinite(part) || !Number.isFinite(whole) || whole <= 0) {
        return null;
    }
    return Math.max(0, Math.min(100, (part / whole) * 100));
}

function trim(value, digits) {
    return Number(value.toFixed(digits)).toString();
}

function toDate(iso) {
    if (typeof iso !== 'string') {
        return null;
    }
    const time = Date.parse(iso);
    return Number.isFinite(time) ? new Date(time) : null;
}
