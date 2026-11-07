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
    proposed: { label: 'To verify', icon: 'question', tone: 'attention' },
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

export function coverageBoard(view) {
    const groups = [
        { id: 'pending', title: 'Needs review', icon: 'circle', tone: 'muted', areas: [] },
        { id: 'active', title: 'In progress', icon: 'active', tone: 'accent', areas: [] },
        { id: 'attention', title: 'Needs attention', icon: 'alert', tone: 'danger', areas: [] },
        { id: 'reviewed', title: 'Reviewed', icon: 'check-circle', tone: 'success', areas: [] },
    ];
    for (const area of view.areas) {
        const group = area.status === 'pending' ? 'pending' : area.status === 'in_progress' ? 'active' : area.status === 'reviewed' ? 'reviewed' : 'attention';
        groups.find((entry) => entry.id === group).areas.push(area);
    }
    return groups;
}

/** Derives the stage rail from recorded state only; nothing infers where the agent is. */
export function stages(view) {
    const required = (view.workItems ?? []).filter((item) => item.required);
    let review = 'upcoming';
    if (required.length && required.every((item) => item.status === 'completed')) review = 'done';
    else if (required.some((item) => ATTENTION.has(item.status))) review = 'blocked';
    else if (required.length) review = 'active';
    const proposed = view.findings.filter((finding) => finding.disposition === 'proposed').length;
    let verify = 'upcoming';
    if (review === 'done' && proposed === 0) verify = 'done';
    else if (proposed || view.findings.length || review === 'done') verify = 'active';
    let outcome = 'upcoming';
    if (view.outcome && !view.stale) outcome = 'done';
    else if (view.status === 'incomplete') outcome = 'blocked';
    const reviewed = view.areas.filter((area) => area.status === 'reviewed').length;
    return [
        { id: 'capture', label: 'Capture', icon: 'file', status: view.stale ? 'blocked' : 'done', detail: `${view.files.length} ${view.files.length === 1 ? 'file' : 'files'}` },
        { id: 'review', label: 'Review', icon: 'code', status: review, detail: view.areas.length ? `${reviewed} of ${view.areas.length} areas reviewed` : 'Not scheduled' },
        { id: 'verify', label: 'Verify', icon: 'shield-check', status: verify, detail: proposed ? `${proposed} to verify` : `${view.findings.length} ${view.findings.length === 1 ? 'finding' : 'findings'}` },
        { id: 'outcome', label: 'Outcome', icon: 'flag', status: outcome, detail: (OUTCOME[view.stale ? 'none' : view.outcome ?? 'none'] ?? OUTCOME.none).label },
    ];
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
        .map((finding) => ({ kind: 'finding', id: finding.id, stage: 'verify', label: finding.claim, severity: finding.severity }));
}

export function bySeverity(left, right) {
    return (SEVERITY[left.severity]?.rank ?? 9) - (SEVERITY[right.severity]?.rank ?? 9) || String(left.id).localeCompare(String(right.id));
}

export const FINDING_FILTERS = [
    { id: 'verify', label: 'To verify', test: (finding) => finding.disposition === 'proposed' },
    { id: 'retained', label: 'Retained', test: (finding) => ['accepted', 'disputed', 'deferred'].includes(finding.disposition) },
    { id: 'rejected', label: 'Rejected', test: (finding) => finding.disposition === 'rejected' },
    { id: 'all', label: 'All', test: () => true },
];

export function findingFilter(view, id) {
    const filter = FINDING_FILTERS.find((entry) => entry.id === id) ?? FINDING_FILTERS[3];
    return view.findings.filter(filter.test).sort(bySeverity);
}

/** Opens on the first filter with findings, so the default never hides what exists. */
export function defaultFindingFilter(view) {
    return FINDING_FILTERS.find((entry) => view.findings.some(entry.test))?.id ?? 'all';
}

/** Keeps the current filter when it shows the finding; otherwise picks the finding's own group. */
export function filterShowing(view, current, findingId) {
    const finding = view.findings.find((entry) => entry.id === findingId);
    const active = FINDING_FILTERS.find((entry) => entry.id === current);
    if (!finding || (active && active.test(finding))) return current;
    return FINDING_FILTERS.find((entry) => entry.id !== 'all' && entry.test(finding))?.id ?? 'all';
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

function wrapLabel(text, width = 22, maxLines = 3) {
    const lines = [];
    let line = '';
    for (const word of String(text).split(/\s+/).filter(Boolean)) {
        const pieces = word.length > width ? word.match(new RegExp(`.{1,${width}}`, 'g')) : [word];
        for (const piece of pieces) {
            if (!line) line = piece;
            else if (`${line} ${piece}`.length <= width) line = `${line} ${piece}`;
            else {
                lines.push(line);
                line = piece;
            }
        }
    }
    if (line) lines.push(line);
    if (lines.length > maxLines) {
        lines.length = maxLines;
        lines[maxLines - 1] = `${lines[maxLines - 1].slice(0, width - 1)}…`;
    }
    return lines.length ? lines : [''];
}

/**
 * Lays out impact relationships as columns ordered by longest path, so a change reads left to
 * right toward what it affects. Cycles and back-links route below the boxes.
 */
export function impactLayout(edges, { nodeWidth = 184, gapX = 64, gapY = 16, pad = 8, lineHeight = 18 } = {}) {
    const names = [];
    for (const edge of edges) for (const name of [edge.from, edge.to]) if (!names.includes(name)) names.push(name);
    const layer = new Map(names.map((name) => [name, 0]));
    for (let pass = 0; pass < names.length; pass += 1) {
        let changed = false;
        for (const edge of edges) {
            const next = layer.get(edge.from) + 1;
            if (edge.from !== edge.to && next < names.length && layer.get(edge.to) < next) {
                layer.set(edge.to, next);
                changed = true;
            }
        }
        if (!changed) break;
    }
    const columns = [];
    for (const name of names) (columns[layer.get(name)] ??= []).push(name);
    const nodes = new Map();
    const heights = columns.map((column) => column.reduce((sum, name) => sum + 16 + wrapLabel(name).length * lineHeight, 0) + gapY * Math.max(column.length - 1, 0));
    const tallest = Math.max(0, ...heights);
    columns.forEach((column, index) => {
        let y = pad + (tallest - heights[index]) / 2;
        for (const name of column) {
            const lines = wrapLabel(name);
            const height = 16 + lines.length * lineHeight;
            nodes.set(name, { id: name, label: name, lines, x: pad + index * (nodeWidth + gapX), y, width: nodeWidth, height });
            y += height + gapY;
        }
    });
    let back = false;
    const links = edges.map((edge, index) => {
        const source = nodes.get(edge.from);
        const target = nodes.get(edge.to);
        let path;
        if (target.x > source.x) {
            const x1 = source.x + source.width;
            const y1 = source.y + source.height / 2;
            const x2 = target.x;
            const y2 = target.y + target.height / 2;
            const bend = (x2 - x1) / 2;
            path = `M${x1} ${y1}C${x1 + bend} ${y1} ${x2 - bend} ${y2} ${x2} ${y2}`;
        } else {
            back = true;
            const x1 = source.x + source.width / 2;
            const y1 = source.y + source.height;
            const x2 = target.x + target.width / 2 + (source === target ? 24 : 0);
            const y2 = target.y + target.height;
            path = `M${x1} ${y1}C${x1} ${y1 + 40} ${x2} ${y2 + 40} ${x2} ${y2}`;
        }
        return { index, from: edge.from, to: edge.to, path, uncertain: Boolean(edge.uncertainty) };
    });
    return {
        nodes: [...nodes.values()], links,
        width: pad * 2 + columns.length * nodeWidth + Math.max(columns.length - 1, 0) * gapX,
        height: pad * 2 + tallest + (back ? 44 : 0),
    };
}

/** Findings and comments anchored to one hunk, for the diff margin. */
export function hunkAnnotations(view, file, hunk) {
    const findings = view.findings.filter((finding) => finding.anchors.some((anchor) => anchor.hunkId === hunk.id));
    const comments = view.discussion.items.filter((comment) => {
        if (comment.outdated || !comment.commit || comment.commit !== view.target.head || comment.line === null) return false;
        if (comment.path !== file.newPath && comment.path !== file.oldPath) return false;
        const side = comment.side;
        return ['old', 'new'].includes(side) && comment.line >= hunk[`${side}Start`] && comment.line < hunk[`${side}Start`] + hunk[`${side}Count`];
    });
    return { findings: findings.sort(bySeverity), comments };
}

export function fileAnnotations(view, file) {
    return {
        findings: view.findings.filter((finding) => finding.anchors.some((anchor) => anchor.fileId === file.id)),
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

/** The stage a focus target belongs to, so an agent focus request opens the right view. */
export function stageFor(target) {
    if (!target) return 'review';
    if (target.kind === 'finding' || target.kind === 'comment') return 'verify';
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
