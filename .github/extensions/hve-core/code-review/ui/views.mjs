// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Pure view logic for the Code Review canvas. Vocabularies mirror the RPI Workflow
// canvas style guide: every status pairs an icon and a word with its tone.

export const EXECUTION = {
    pending: { label: 'Not started', icon: 'circle', tone: 'muted' },
    in_progress: { label: 'In progress', icon: 'active', tone: 'accent' },
    completed: { label: 'Done', icon: 'check-circle', tone: 'success' },
    reviewed: { label: 'Reviewed', icon: 'check-circle', tone: 'success' },
    blocked: { label: 'Blocked', icon: 'alert', tone: 'danger' },
    unavailable: { label: 'Unavailable', icon: 'slash-circle', tone: 'muted' },
    skipped: { label: 'Skipped', icon: 'dash-circle', tone: 'muted' },
    stale: { label: 'Stale', icon: 'clock', tone: 'attention' },
};

export const STAGE_STATUS = {
    done: { label: 'Done', icon: 'check-circle', tone: 'success' },
    active: { label: 'In progress', icon: 'active', tone: 'accent' },
    upcoming: { label: 'Not started', icon: 'circle', tone: 'muted' },
    blocked: { label: 'Needs attention', icon: 'alert', tone: 'danger' },
};

export const SEVERITY = {
    Critical: { label: 'Critical', icon: 'alert-fill', tone: 'danger', rank: 0 },
    High: { label: 'High', icon: 'alert', tone: 'danger', rank: 1 },
    Medium: { label: 'Medium', icon: 'alert', tone: 'severe', rank: 2 },
    Low: { label: 'Low', icon: 'info', tone: 'muted', rank: 3 },
};

export const DISPOSITION = {
    proposed: { label: 'Being checked', icon: 'active', tone: 'accent' },
    accepted: { label: 'Accepted', icon: 'shield-check', tone: 'success' },
    disputed: { label: 'Disputed', icon: 'half', tone: 'attention' },
    deferred: { label: 'Deferred', icon: 'clock', tone: 'muted' },
    rejected: { label: 'Rejected', icon: 'x-circle', tone: 'muted' },
};

export const OUTCOME = {
    approve: { label: 'Approve', icon: 'check-circle', tone: 'success' },
    approve_with_comments: { label: 'Approve with comments', icon: 'info', tone: 'attention' },
    request_changes: { label: 'Request changes', icon: 'x-circle', tone: 'danger' },
    none: { label: 'No outcome yet', icon: 'dash-circle', tone: 'muted' },
};

export const FILE_STATUS = {
    A: { label: 'Added', icon: 'plus', tone: 'success' },
    M: { label: 'Modified', icon: 'diff', tone: 'accent' },
    D: { label: 'Deleted', icon: 'dash', tone: 'danger' },
    R: { label: 'Renamed', icon: 'arrow-right', tone: 'accent' },
    C: { label: 'Copied', icon: 'copy', tone: 'accent' },
    T: { label: 'Type changed', icon: 'info', tone: 'muted' },
};

export const TARGET_KIND = {
    pr: 'Pull request', branch: 'Branch comparison', local: 'Local changes', commit: 'Commit', selected: 'Selected code',
};

export const PERSPECTIVE = {
    functional: 'Functional', standards: 'Standards', accessibility: 'Accessibility', security: 'Security',
    readiness: 'Readiness', context: 'Context', investigation: 'Investigation',
};

export const FEEDBACK_KIND = {
    comment: 'Comment', 'review-next': 'Review next', explain: 'Explain', investigate: 'Investigate',
    dispute: 'Dispute finding', draft: 'Comment draft',
};

const ATTENTION = new Set(['blocked', 'unavailable', 'skipped', 'stale']);
const RETAINED = new Set(['proposed', 'accepted', 'disputed', 'deferred']);

export function fileLabel(file) {
    if (file.status === 'R' || file.status === 'C') return `${file.oldPath} -> ${file.newPath}`;
    return `${file.newPath ?? file.oldPath}${file.status === 'D' ? ' (deleted)' : ''}`;
}

export function splitPath(value) {
    const text = String(value ?? '');
    const at = text.lastIndexOf('/');
    return at < 0 ? { dir: '', name: text } : { dir: text.slice(0, at + 1), name: text.slice(at + 1) };
}

export function fileStatus(file) {
    return FILE_STATUS[file.status] ?? { label: file.status, icon: 'info', tone: 'muted' };
}

export function fileStats(file) {
    let additions = 0;
    let deletions = 0;
    for (const hunk of file.hunks ?? []) {
        additions += hunk.newLines?.length ?? 0;
        deletions += hunk.oldLines?.length ?? 0;
    }
    return { additions, deletions };
}

/** Derives the stage rail from recorded state only; nothing infers where the agent is. */
export function stages(view) {
    const required = (view.workItems ?? []).filter((item) => item.required);
    const proposed = view.findings.filter((finding) => finding.disposition === 'proposed').length;
    let review = 'upcoming';
    if (required.some((item) => ATTENTION.has(item.status))) review = 'blocked';
    else if (required.length && required.every((item) => item.status === 'completed') && proposed === 0) review = 'done';
    else if (required.length || view.findings.length) review = 'active';
    let outcome = 'upcoming';
    if (view.outcome && !view.stale) outcome = 'done';
    else if (view.status === 'incomplete') outcome = 'blocked';
    const reviewed = view.areas.filter((area) => area.status === 'reviewed').length;
    const checking = proposed ? `, ${proposed} being checked` : '';
    return [
        { id: 'capture', label: 'Capture', icon: 'file', status: view.stale ? 'blocked' : 'done', detail: `${view.files.length} ${view.files.length === 1 ? 'file' : 'files'}` },
        { id: 'review', label: 'Review', icon: 'code', status: review, detail: view.areas.length ? `${reviewed} of ${view.areas.length} areas reviewed${checking}` : 'Not scheduled' },
        { id: 'outcome', label: 'Outcome', icon: 'flag', status: outcome, detail: (OUTCOME[view.stale ? 'none' : view.outcome ?? 'none'] ?? OUTCOME.none).label },
    ];
}

/**
 * The board's lanes, in order. In progress also holds areas whose required work is blocked,
 * unavailable, skipped, or stale; those cards carry a marker instead of a lane of their own.
 */
export const LANES = Object.freeze([
    Object.freeze({ id: 'pending', title: 'Needs review', icon: 'circle', tone: 'muted', statuses: Object.freeze(['pending']) }),
    Object.freeze({ id: 'active', title: 'In progress', icon: 'active', tone: 'accent', statuses: Object.freeze(['in_progress', 'blocked', 'unavailable', 'skipped', 'stale']) }),
    Object.freeze({ id: 'reviewed', title: 'Reviewed', icon: 'check-circle', tone: 'success', statuses: Object.freeze(['reviewed']) }),
]);

/** True for an area whose required work cannot finish as recorded. */
export function needsAttention(area) {
    return ATTENTION.has(area.status);
}

/**
 * Each lane with its areas in review order, the one card it shows, and how many hidden cards
 * need attention. Needs review shows the next area; In progress shows the area the agent points
 * into, else the first that needs attention, else the first; Reviewed shows the selected area,
 * else the last.
 *
 * @param {{ areas: any[] }} view
 * @param {{ agentAreaId?: string | null, selectedAreaId?: string | null }} [options]
 */
export function boardLanes(view, { agentAreaId = null, selectedAreaId = null } = {}) {
    return LANES.map((lane) => {
        const areas = view.areas.filter((area) => lane.statuses.includes(area.status));
        let card = null;
        if (lane.id === 'pending') card = areas[0] ?? null;
        else if (lane.id === 'active') card = areas.find((area) => area.id === agentAreaId) ?? areas.find(needsAttention) ?? areas[0] ?? null;
        else card = areas.find((area) => area.id === selectedAreaId) ?? areas.at(-1) ?? null;
        const hidden = areas.filter((area) => area !== card && needsAttention(area)).length;
        return { ...lane, areas, card, hidden };
    });
}

/**
 * Findings grouped for the Review stage: one group per severity holding retained findings,
 * then Set aside for rejected ones. Critical and High start open. Each group keeps ID order, so a
 * finding stays put while the agent checks it.
 */
export function findingGroups(findings) {
    const byId = (left, right) => String(left.id).localeCompare(String(right.id));
    const groups = Object.keys(SEVERITY).map((severity) => ({
        id: severity.toLowerCase(), label: severity, severity, open: ['Critical', 'High'].includes(severity),
        findings: findings.filter((finding) => finding.disposition !== 'rejected' && finding.severity === severity).sort(byId),
    }));
    groups.push({ id: 'set-aside', label: 'Set aside', severity: null, open: false, findings: findings.filter((finding) => finding.disposition === 'rejected').sort(bySeverity) });
    return groups.filter((group) => group.findings.length);
}

/** Required work per perspective: areas checked, areas in progress, and areas that need attention. */
export function perspectiveProgress(view) {
    const required = (view.workItems ?? []).filter((item) => item.required);
    return [...new Set(required.map((item) => item.perspective))].map((perspective) => {
        const items = required.filter((item) => item.perspective === perspective);
        const areaIds = [...new Set(items.flatMap((item) => item.areaIds))];
        const state = (areaId) => {
            const covering = items.filter((item) => item.areaIds.includes(areaId));
            if (covering.some((item) => ATTENTION.has(item.status))) return 'attention';
            if (covering.every((item) => item.status === 'completed')) return 'done';
            return covering.some((item) => item.status !== 'pending') ? 'active' : 'pending';
        };
        const states = areaIds.map(state);
        return {
            perspective, total: areaIds.length,
            done: states.filter((value) => value === 'done').length,
            active: states.filter((value) => value === 'active').length,
            attention: states.filter((value) => value === 'attention').length,
        };
    });
}

/**
 * Findings the reader has not been shown yet, against the IDs already shown, with a severity
 * summary such as "1 Critical, 2 High" for the button that reveals them. `fresh` lists the held IDs
 * that were not held before, so an arrival is announced once even after the reader revealed
 * another finding.
 *
 * @param {any[]} findings
 * @param {Set<string>} shown
 * @param {Set<string>} [before] IDs held at the previous check; every held ID is fresh without it
 */
export function arrivals(findings, shown, before = new Set()) {
    const held = findings.filter((finding) => !shown.has(finding.id));
    const serious = ['Critical', 'High'].map((severity) => [severity, held.filter((finding) => finding.severity === severity && finding.disposition !== 'rejected').length])
        .filter(([, count]) => count).map(([severity, count]) => `${count} ${severity}`);
    const ids = held.map((finding) => finding.id);
    return { ids, count: held.length, summary: serious.join(', '), fresh: ids.filter((id) => !before.has(id)) };
}

/**
 * Which narrowing would hide any of the given findings: the reason lens, the area scope, both, or
 * neither. Revealing findings clears only the narrowing that hides them.
 *
 * @param {{ findings: any[], areas: any[], files: any[], reasons?: any[] }} view
 * @param {string[]} ids
 * @param {{ reasonId?: string | null, areaId?: string | null }} [narrowing]
 * @returns {{ reason: boolean, area: boolean }}
 */
export function hidingNarrowing(view, ids, { reasonId = null, areaId = null } = {}) {
    const hides = (options) => {
        const kept = new Set(findingsFor(view, options).map((finding) => finding.id));
        return ids.some((id) => !kept.has(id));
    };
    return { reason: Boolean(reasonId) && hides({ reasonId }), area: Boolean(areaId) && hides({ areaId }) };
}

/**
 * What each reason explains, mirroring the report: a hunk belongs to the reason that claims it,
 * else to the reason that claims its file; a file without hunks counts by file. `byFile` lists each
 * file's reasons in first-hunk order with their hunk counts, using `null` for unexplained hunks.
 */
export function reasonCoverage(view) {
    const claimedHunk = new Map();
    const claimedFile = new Map();
    for (const reason of view.reasons ?? []) {
        for (const fileId of reason.fileIds) claimedFile.set(fileId, reason.id);
        for (const hunkId of reason.hunkIds) claimedHunk.set(hunkId, reason.id);
    }
    const totals = new Map((view.reasons ?? []).map((reason) => [reason.id, { files: new Set(), hunks: 0 }]));
    const byFile = {};
    const byHunk = {};
    const open = { files: [], hunks: 0 };
    for (const file of view.files) {
        const segments = new Map();
        if (!file.hunks.length) {
            const reasonId = claimedFile.get(file.id) ?? null;
            segments.set(reasonId, 0);
            if (reasonId) totals.get(reasonId).files.add(file.id);
            else open.files.push(file.id);
        }
        for (const hunk of file.hunks) {
            const reasonId = claimedHunk.get(hunk.id) ?? claimedFile.get(file.id) ?? null;
            byHunk[hunk.id] = reasonId;
            segments.set(reasonId, (segments.get(reasonId) ?? 0) + 1);
            if (reasonId) {
                totals.get(reasonId).files.add(file.id);
                totals.get(reasonId).hunks += 1;
            } else open.hunks += 1;
        }
        if (file.hunks.length && segments.has(null)) open.files.push(file.id);
        byFile[file.id] = [...segments].map(([reasonId, hunks]) => ({ reasonId, hunks }));
    }
    return {
        reasons: (view.reasons ?? []).map((reason) => ({ id: reason.id, files: totals.get(reason.id).files.size, hunks: totals.get(reason.id).hunks })),
        unexplained: { files: open.files.length, hunks: open.hunks, fileIds: open.files },
        byFile, byHunk,
    };
}

/** The reason selection that stands for changes no reason explains. */
export const NOT_EXPLAINED = 'not-explained';

/**
 * Files a reason explains in whole or in part, in snapshot order. `NOT_EXPLAINED` gives the files
 * with any change no reason explains.
 *
 * @param {any} view
 * @param {string} reasonId
 * @param {ReturnType<typeof reasonCoverage>} [coverage]
 * @returns {string[]}
 */
export function reasonFiles(view, reasonId, coverage = reasonCoverage(view)) {
    const want = reasonId === NOT_EXPLAINED ? null : reasonId;
    return view.files.filter((file) => (coverage.byFile[file.id] ?? []).some((segment) => segment.reasonId === want)).map((file) => file.id);
}

/**
 * Findings narrowed to a reason or an area. A line anchor belongs to its hunk's reason; a file
 * anchor belongs to every reason that explains part of the file. Metadata anchors match neither.
 * `NOT_EXPLAINED` narrows to findings on changes no reason explains.
 *
 * @param {any} view
 * @param {{ reasonId?: string | null, areaId?: string | null }} filter
 */
export function findingsFor(view, { reasonId = null, areaId = null } = {}) {
    if (!reasonId && !areaId) return view.findings;
    const area = areaId ? view.areas.find((entry) => entry.id === areaId) : null;
    const coverage = reasonId ? reasonCoverage(view) : null;
    const want = reasonId === NOT_EXPLAINED ? null : reasonId;
    const matchesReason = (anchor) => {
        if (!anchor.fileId) return false;
        if (anchor.hunkId) return coverage.byHunk[anchor.hunkId] === want;
        return (coverage.byFile[anchor.fileId] ?? []).some((segment) => segment.reasonId === want);
    };
    return view.findings.filter((finding) => finding.anchors.some((anchor) =>
        (!area || area.fileIds.includes(anchor.fileId)) && (!reasonId || matchesReason(anchor))));
}

export function isRetained(finding) {
    return RETAINED.has(finding.disposition);
}

export function isMarked(feedback, field, target) {
    return (feedback?.[field] ?? []).some((entry) => entry.kind === target.kind && entry.id === target.id && entry.snapshotId === target.snapshotId);
}

/** Retained Critical and High findings you have not marked seen, highest severity first. */
export function needsYou(view) {
    return view.findings
        .filter((finding) => isRetained(finding) && ['Critical', 'High'].includes(finding.severity)
            && !isMarked(view.feedback, 'seen', { kind: 'finding', id: finding.id, snapshotId: view.snapshotId }))
        .sort(bySeverity)
        .map((finding) => ({ kind: 'finding', id: finding.id, stage: 'review', label: finding.claim, severity: finding.severity }));
}

export function bySeverity(left, right) {
    return (SEVERITY[left.severity]?.rank ?? 9) - (SEVERITY[right.severity]?.rank ?? 9) || String(left.id).localeCompare(String(right.id));
}

export function feedbackState(item) {
    if (item.status === 'draft') return { label: 'Draft', icon: 'pencil', tone: 'muted' };
    if (item.status === 'queued') return { label: 'Not sent', icon: 'inbox', tone: 'accent' };
    if (item.status === 'interpreted') return { label: 'Read back', icon: 'check', tone: 'success' };
    if (item.delivery?.status === 'failed') return { label: 'Not delivered', icon: 'alert', tone: 'danger' };
    if (item.delivery?.status === 'collected') return { label: 'The agent has it', icon: 'sparkle', tone: 'agent' };
    return { label: 'Sent', icon: 'send', tone: 'accent' };
}

export function targetSummary(view) {
    const target = view.target ?? {};
    const title = view.metadata?.fields?.find((field) => field.name === 'title')?.value;
    const provider = target.provider ? `${target.provider.repository}#${target.provider.id}` : null;
    let fallback = TARGET_KIND[target.kind] ?? 'Code review';
    if (target.kind === 'commit' && target.head) fallback = `Commit ${target.head.slice(0, 7)}`;
    else if (target.kind === 'local' && target.localMode) fallback = `Local changes (${target.localMode})`;
    else if (target.kind === 'pr' && provider) fallback = `Pull request ${provider}`;
    return { title: title || fallback, kind: TARGET_KIND[target.kind] ?? target.kind ?? 'Review', provider, base: target.base ?? null, head: target.head ?? null };
}

export function anchorLabel(view, anchor) {
    if (anchor.side === 'metadata' || anchor.field) return `${anchor.field} (PR details)`;
    const file = view.files.find((entry) => entry.id === anchor.fileId);
    const name = file ? splitPath(file.newPath ?? file.oldPath).name : anchor.fileId;
    if (anchor.startLine === null || anchor.startLine === undefined) return name;
    return `${name}:${anchor.startLine}${anchor.endLine && anchor.endLine !== anchor.startLine ? `-${anchor.endLine}` : ''}`;
}

export function perspectiveOf(view, workId) {
    return (view.workItems ?? []).find((item) => item.id === workId)?.perspective ?? null;
}

export function matches(query, ...values) {
    const needle = String(query ?? '').trim().toLowerCase();
    return !needle || values.some((value) => String(value ?? '').toLowerCase().includes(needle));
}

/** Plain label text for compact lists: Markdown-style links keep only their words. */
export function plainText(value) {
    return String(value ?? '').replace(/\[([^\]\n]+)\]\(([^)\s]+)\)/g, '$1');
}

/** Findings and comments anchored to one hunk, for the diff margin. */
/**
 * Findings and comments beside one hunk. With `shown`, findings the reader has not been shown yet
 * stay out, so an arrival never adds a note or a margin column to the diff being read.
 *
 * @param {Set<string> | null} [shown] IDs of findings already shown; null keeps every finding
 */
export function hunkAnnotations(view, file, hunk, shown = null) {
    const findings = view.findings.filter((finding) => (!shown || shown.has(finding.id)) && finding.anchors.some((anchor) => anchor.hunkId === hunk.id));
    const comments = view.discussion.items.filter((comment) => {
        if (comment.outdated || !comment.commit || comment.commit !== view.target.head || comment.line === null) return false;
        if (comment.path !== file.newPath && comment.path !== file.oldPath) return false;
        const side = comment.side;
        return ['old', 'new'].includes(side) && comment.line >= hunk[`${side}Start`] && comment.line < hunk[`${side}Start`] + hunk[`${side}Count`];
    });
    return { findings: findings.sort(bySeverity), comments };
}

/** Findings and comments on one file; `shown` leaves out findings the reader has not been shown yet. */
export function fileAnnotations(view, file, shown = null) {
    return {
        findings: view.findings.filter((finding) => (!shown || shown.has(finding.id)) && finding.anchors.some((anchor) => anchor.fileId === file.id)),
        comments: view.discussion.items.filter((comment) => comment.path && (comment.path === file.newPath || comment.path === file.oldPath)),
    };
}

export function resolveFocus(view, target) {
    const selected = { areaId: null, fileId: null, hunkId: null, findingId: null, commentId: null, metadataField: null, mapped: true, stale: false };
    if (target && target.snapshotId !== view.snapshotId) {
        selected.stale = true;
        selected.mapped = false;
        return selected;
    }
    const kind = target?.kind ?? 'review';
    const key = target?.id;
    if (kind === 'review') {
        selected.areaId = view.areas[0]?.id ?? null;
        selected.fileId = view.areas[0]?.fileIds[0] ?? view.files[0]?.id ?? null;
    } else if (kind === 'area') {
        const area = view.areas.find((entry) => entry.id === key);
        selected.areaId = area?.id ?? null;
        selected.fileId = area?.fileIds[0] ?? null;
    } else if (kind === 'reason') {
        selected.fileId = (view.reasons ?? []).some((reason) => reason.id === key) ? reasonFiles(view, key)[0] ?? null : null;
        selected.mapped = Boolean(selected.fileId);
    } else if (kind === 'file') selected.fileId = view.files.find((entry) => entry.id === key)?.id ?? null;
    else if (kind === 'hunk') {
        selected.fileId = view.files.find((file) => file.hunks.some((hunk) => hunk.id === key))?.id ?? null;
        selected.hunkId = selected.fileId ? key : null;
    } else if (kind === 'finding') {
        const finding = view.findings.find((entry) => entry.id === key);
        selected.findingId = finding?.id ?? null;
        const anchor = finding?.anchors[0];
        selected.fileId = anchor?.fileId ?? null;
        selected.hunkId = anchor?.hunkId ?? null;
        selected.metadataField = anchor?.field ?? null;
    } else if (kind === 'comment') {
        const comment = view.discussion.items.find((entry) => entry.id === key);
        selected.commentId = comment?.id ?? null;
        const current = comment && !comment.outdated && comment.commit && comment.commit === view.target.head;
        const file = current ? view.files.find((entry) => entry.newPath === comment.path || entry.oldPath === comment.path) : null;
        const hunk = file?.hunks.find((entry) => comment.line !== null && ['old', 'new'].includes(comment.side) &&
            comment.line >= entry[`${comment.side}Start`] && comment.line < entry[`${comment.side}Start`] + entry[`${comment.side}Count`]);
        selected.fileId = file?.id ?? null;
        selected.hunkId = hunk?.id ?? null;
        selected.mapped = Boolean(hunk);
    }
    if (!selected.areaId && selected.fileId) selected.areaId = view.areas.find((area) => area.fileIds.includes(selected.fileId))?.id ?? null;
    return selected;
}

/** The stage a focus target belongs to, so an agent focus request opens the right view. Every focus target lives in Review. */
export function stageFor() {
    return 'review';
}

export function safeWebUrl(value) {
    try {
        const url = new URL(value);
        return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? url.href : null;
    } catch {
        return null;
    }
}
