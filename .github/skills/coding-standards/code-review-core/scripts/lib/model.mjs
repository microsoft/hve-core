// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export class ReviewError extends Error {
    constructor(code, message) {
        super(message);
        this.name = 'ReviewError';
        this.code = code;
    }
}

export const PERSPECTIVES = ['functional', 'standards', 'accessibility', 'security', 'readiness', 'context', 'investigation'];
export const WORK_STATES = ['pending', 'in_progress', 'completed', 'blocked', 'unavailable', 'skipped', 'stale'];
export const SEVERITIES = ['Critical', 'High', 'Medium', 'Low'];
const ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const own = (value, key) => Object.hasOwn(value, key);

export function check(condition, message, code = 'invalid_record') {
    if (!condition) throw new ReviewError(code, message);
}

export function object(value, keys, label, optional = []) {
    check(value !== null && typeof value === 'object' && !Array.isArray(value), `${label} must be an object.`);
    check(Object.keys(value).every((key) => keys.includes(key) || optional.includes(key)), `${label} contains an unsupported field.`);
    check(keys.every((key) => own(value, key)), `${label} is missing required fields.`);
    return value;
}

export function text(value, label, empty = false) {
    check(typeof value === 'string' && (empty || value.trim().length > 0) && !value.includes('\0'), `${label} must be text.`);
    return value;
}

export function id(value, label = 'ID') {
    check(typeof value === 'string' && ID.test(value), `${label} must be a bounded path-safe identifier.`);
    return value;
}

export function relativePath(value, label = 'Path') {
    text(value, label);
    check(!value.startsWith('/') && !value.includes('\\') && !/^[A-Za-z]:/.test(value) &&
        value.split('/').every((part) => part !== '' && part !== '.' && part !== '..'), `${label} must be a contained relative path.`);
    return value;
}

function integer(value, label, minimum = 0) {
    check(Number.isSafeInteger(value) && value >= minimum, `${label} must be an integer >= ${minimum}.`);
}

function enumeration(value, values, label) {
    check(values.includes(value), `${label} must be one of ${values.join(', ')}.`);
}

function array(value, label) {
    check(Array.isArray(value), `${label} must be an array.`);
    return value;
}

function ids(value, label, allowed) {
    array(value, label).forEach((entry) => id(entry, label));
    check(new Set(value).size === value.length, `${label} contains duplicate IDs.`);
    if (allowed) check(value.every((entry) => allowed.has(entry)), `${label} references an unknown ID.`);
}

function unique(items, label) {
    ids(items.map((entry) => entry.id), label);
}

function version(value) {
    check(value.schemaVersion === 1, 'Unsupported schemaVersion; existing records were left unchanged.', 'unsupported_schema');
}

function limitations(value) {
    array(value, 'limitations').forEach((entry) => {
        object(entry, ['id', 'summary', 'blocking'], 'limitation');
        id(entry.id);
        text(entry.summary, 'limitation summary');
        check(typeof entry.blocking === 'boolean', 'limitation blocking must be boolean.');
    });
    unique(value, 'limitations');
}

const REASON_ID = /^R[1-9]$/;
export const MAP_LIMITS = Object.freeze({ reasons: 9, boxes: 6, parts: 16, links: 32 });
export const PART_CHANGES = ['new', 'changed', 'removed', 'unchanged'];
export const LINK_CHANGES = ['new', 'removed', 'unchanged'];

function bounded(value, label, max) {
    text(value, label);
    check(value.length <= max, `${label} must be at most ${max} characters.`);
    return value;
}

/** Reasons claim whole files or single hunks; a hunk belongs to at most one reason. */
function reasons(value, snapshot) {
    array(value, 'reasons');
    check(value.length >= 1 && value.length <= MAP_LIMITS.reasons, `Record between 1 and ${MAP_LIMITS.reasons} reasons, or null to remove them.`);
    const hunkFile = new Map(snapshot.files.flatMap((file) => file.hunks.map((hunk) => [hunk.id, file.id])));
    const whole = new Set();
    const claimed = new Set();
    const split = new Set();
    for (const reason of value) {
        object(reason, ['id', 'title', 'why', 'fileIds', 'hunkIds'], 'reason');
        check(typeof reason.id === 'string' && REASON_ID.test(reason.id), 'Reason IDs run from R1 to R9.');
        bounded(reason.title, 'reason title', 80);
        check(!/[\n\r\u2028\u2029]/.test(reason.title), 'reason title must be one line.');
        bounded(reason.why, 'reason why', 400);
        ids(reason.fileIds, 'reason files', new Set(snapshot.files.map((file) => file.id)));
        ids(reason.hunkIds, 'reason hunks', new Set(hunkFile.keys()));
        check(reason.fileIds.length + reason.hunkIds.length > 0, 'A reason must explain at least one file or hunk.');
        for (const fileId of reason.fileIds) {
            check(!whole.has(fileId), 'A file belongs whole to at most one reason.');
            whole.add(fileId);
        }
        for (const hunkId of reason.hunkIds) {
            check(!claimed.has(hunkId), 'A hunk belongs to at most one reason.');
            claimed.add(hunkId);
            split.add(hunkFile.get(hunkId));
        }
    }
    check([...split].every((fileId) => !whole.has(fileId)), 'A file a reason claims whole cannot have hunks claimed by a reason.');
    unique(value, 'reasons');
}

/** A change map of boxes, parts, and links checked against the snapshot and the recorded reasons. */
function changeMap(value, snapshot, reasonIds) {
    object(value, ['title', 'description', 'boxes', 'parts', 'links'], 'change map');
    bounded(value.title, 'map title', 120);
    bounded(value.description, 'map description', 300);
    array(value.boxes, 'map boxes');
    array(value.parts, 'map parts');
    array(value.links, 'map links');
    check(value.parts.length > 0, 'A change map needs at least one part.');
    check(value.boxes.length <= MAP_LIMITS.boxes && value.parts.length <= MAP_LIMITS.parts && value.links.length <= MAP_LIMITS.links,
        `A change map holds at most ${MAP_LIMITS.boxes} boxes, ${MAP_LIMITS.parts} parts, and ${MAP_LIMITS.links} links.`);
    for (const box of value.boxes) {
        object(box, ['id', 'label', 'parent'], 'map box');
        bounded(box.label, 'box label', 120);
    }
    unique(value.boxes, 'map boxes');
    const boxes = new Map(value.boxes.map((box) => [box.id, box]));
    for (const box of value.boxes) {
        if (box.parent === null) continue;
        const parent = boxes.get(box.parent);
        check(parent && parent !== box && parent.parent === null, 'A box sits at the top level or inside one top-level box.');
    }
    const files = new Set(snapshot.files.map((file) => file.id));
    for (const part of value.parts) {
        object(part, ['id', 'label', 'box', 'change', 'before', 'after', 'fileIds', 'reasonIds'], 'map part');
        bounded(part.label, 'part label', 120);
        check(part.box === null || boxes.has(part.box), 'A part sits in a known box or in none.');
        enumeration(part.change, PART_CHANGES, 'part change');
        const article = part.change === 'unchanged' ? 'An' : 'A';
        if (['changed', 'removed'].includes(part.change)) bounded(part.before, 'part before', 160);
        else check(part.before === null, `${article} ${part.change} part has no before line.`);
        if (['new', 'changed'].includes(part.change)) bounded(part.after, 'part after', 160);
        else check(part.after === null, `${article} ${part.change} part has no after line.`);
        ids(part.fileIds, 'part files', files);
        ids(part.reasonIds, 'part reasons', reasonIds);
    }
    unique(value.parts, 'map parts');
    check(value.parts.every((part) => !boxes.has(part.id)), 'Box and part IDs must differ.');
    const parts = new Map(value.parts.map((part) => [part.id, part]));
    for (const link of value.links) {
        object(link, ['from', 'to', 'label', 'change', 'kind', 'anchor', 'uncertainty'], 'map link');
        const from = parts.get(link.from);
        const to = parts.get(link.to);
        check(from && to && from !== to, 'A link joins two different known parts.');
        bounded(link.label, 'link label', 60);
        enumeration(link.change, LINK_CHANGES, 'link change');
        enumeration(link.kind, ['uses', 'checks'], 'link kind');
        if (link.anchor !== null) validateAnchor(link.anchor, snapshot);
        if (link.uncertainty !== null) bounded(link.uncertainty, 'link uncertainty', 300);
        check(link.anchor !== null || link.uncertainty !== null, 'A map link needs evidence or an explicit uncertainty.');
        if (from.change === 'new' || to.change === 'new') check(link.change === 'new', 'A link to a new part is new.');
        if (from.change === 'removed' || to.change === 'removed') check(link.change === 'removed', 'A link to a removed part is removed.');
    }
}

/**
 * Counts what each reason explains and what no reason explains. A hunk is explained when its file
 * is claimed whole or the hunk itself is claimed; a file without hunks counts by file.
 *
 * @returns {{ reasons: { id: string, files: number, hunks: number }[], unexplained: { files: number, hunks: number } }}
 */
export function reasonCoverage(state, snapshot) {
    const owner = new Map();
    const wholeFiles = new Set();
    const counts = (state.reasons ?? []).map((reason) => {
        const files = new Set(reason.fileIds);
        let hunks = 0;
        for (const file of snapshot.files) {
            if (reason.fileIds.includes(file.id)) {
                wholeFiles.add(file.id);
                hunks += file.hunks.length;
                for (const hunk of file.hunks) owner.set(hunk.id, reason.id);
            }
            for (const hunk of file.hunks) {
                if (!reason.hunkIds.includes(hunk.id)) continue;
                files.add(file.id);
                hunks += 1;
                owner.set(hunk.id, reason.id);
            }
        }
        return { id: reason.id, files: files.size, hunks };
    });
    const unexplained = { files: 0, hunks: 0 };
    for (const file of snapshot.files) {
        const open = file.hunks.filter((hunk) => !owner.has(hunk.id)).length;
        unexplained.hunks += open;
        if (open > 0 || (file.hunks.length === 0 && !wholeFiles.has(file.id))) unexplained.files += 1;
    }
    return { reasons: counts, unexplained };
}

function coverage(value, files, hunks) {
    object(value, ['fileIds', 'hunkIds', 'notApplicable'], 'coverage');
    ids(value.fileIds, 'coverage files', new Set(files));
    ids(value.hunkIds, 'coverage hunks', new Set(hunks));
    if (value.notApplicable !== null) text(value.notApplicable, 'notApplicable reason');
}

export function validateSnapshot(snapshot) {
    object(snapshot, ['schemaVersion', 'reviewId', 'snapshotId', 'capturedAt', 'repository', 'target', 'files', 'discussion', 'omissions'], 'snapshot', ['metadata']);
    version(snapshot);
    id(snapshot.reviewId);
    id(snapshot.snapshotId);
    text(snapshot.repository, 'repository');
    check(typeof snapshot.capturedAt === 'string' && Number.isFinite(Date.parse(snapshot.capturedAt)), 'capturedAt must be an ISO timestamp.');
    const target = object(snapshot.target, ['kind', 'base', 'head', 'mergeBase', 'fingerprint', 'provider', 'selection', 'localMode'], 'target');
    enumeration(target.kind, ['pr', 'branch', 'local', 'commit', 'selected'], 'target kind');
    for (const field of ['base', 'head', 'mergeBase']) {
        check(target[field] === null || /^[a-f0-9]{40,64}$/.test(target[field]), `${field} must be a commit ID or null.`);
    }
    if (['pr', 'branch', 'commit'].includes(target.kind)) check(target.base && target.head, 'Committed targets require explicit base and head.');
    if (target.kind === 'local') enumeration(target.localMode, ['staged', 'unstaged', 'combined'], 'local mode');
    else check(target.localMode === null, 'Only local targets have a local mode.');
    if (target.fingerprint !== null) check(/^[a-f0-9]{64}$/.test(target.fingerprint), 'Invalid content fingerprint.');
    if (target.kind === 'local' || target.kind === 'selected') check(target.fingerprint !== null, 'Local evidence requires a content fingerprint.');
    if (target.provider !== null) {
        object(target.provider, ['name', 'repository', 'id'], 'provider');
        for (const field of ['name', 'repository', 'id']) text(target.provider[field], `provider ${field}`);
    }
    if (target.kind === 'pr') check(target.provider !== null, 'PR/MR targets require provider identity.');
    if (target.selection !== null) {
        array(target.selection, 'selection').forEach((entry) => {
            object(entry, ['path', 'startLine', 'endLine'], 'selection');
            relativePath(entry.path);
            integer(entry.startLine, 'selection start', 1);
            integer(entry.endLine, 'selection end', entry.startLine);
        });
    }
    const allHunks = [];
    array(snapshot.files, 'files').forEach((file) => {
        object(file, ['id', 'status', 'oldPath', 'newPath', 'oldOid', 'newOid', 'evidencePath', 'omission', 'hunks'], 'file');
        id(file.id);
        enumeration(file.status, ['A', 'M', 'D', 'R', 'C', 'T', 'U'], 'file status');
        check(file.oldPath !== null || file.newPath !== null, 'A file requires at least one path.');
        for (const field of ['oldPath', 'newPath', 'evidencePath']) if (file[field] !== null) relativePath(file[field]);
        for (const field of ['oldOid', 'newOid']) check(file[field] === null || /^[a-f0-9]{40,64}$/.test(file[field]), 'Invalid blob ID.');
        if (file.omission !== null) text(file.omission, 'omission');
        check(file.omission !== null || file.evidencePath !== null, 'A file needs captured evidence or an omission.');
        if (file.evidencePath !== null) check(file.evidencePath === `snapshots/${snapshot.snapshotId}/files/${file.id}.json`, 'Evidence path does not match the snapshot/file identity.');
        array(file.hunks, 'hunks').forEach((hunk) => {
            object(hunk, ['id', 'oldStart', 'oldCount', 'newStart', 'newCount', 'oldLines', 'newLines'], 'hunk');
            id(hunk.id);
            for (const field of ['oldStart', 'oldCount', 'newStart', 'newCount']) integer(hunk[field], field);
            for (const side of ['old', 'new']) {
                array(hunk[`${side}Lines`], 'changed lines').forEach((line) => {
                    integer(line, 'changed line', 1);
                    check(line >= hunk[`${side}Start`] && line < hunk[`${side}Start`] + hunk[`${side}Count`], 'Changed line lies outside the hunk.');
                });
            }
            allHunks.push(hunk);
        });
    });
    unique(snapshot.files, 'files');
    unique(allHunks, 'hunks');
    object(snapshot.discussion, ['status', 'items', 'limitations'], 'discussion');
    enumeration(snapshot.discussion.status, ['complete', 'partial', 'unavailable', 'not_applicable'], 'discussion status');
    array(snapshot.discussion.items, 'discussion items').forEach((item) => {
        object(item, ['id', 'author', 'body', 'replyTo', 'kind', 'path', 'line', 'side', 'commit', 'originalLine', 'originalCommit', 'resolution'], 'discussion item', ['originalPath', 'originalSide', 'startLine', 'originalStartLine', 'outdated']);
        for (const field of ['id', 'author', 'body']) text(item[field], `discussion ${field}`, field === 'body');
        enumeration(item.kind, ['inline', 'timeline'], 'discussion kind');
        enumeration(item.resolution, ['resolved', 'unresolved', 'unknown'], 'discussion resolution');
        if (item.path !== null) relativePath(item.path);
        for (const field of ['line', 'originalLine']) if (item[field] !== null) integer(item[field], field, 1);
        if (item.side !== null) enumeration(item.side, ['old', 'new'], 'discussion side');
        for (const field of ['replyTo', 'commit', 'originalCommit']) if (item[field] !== null) text(item[field], field);
        if (item.originalPath !== undefined && item.originalPath !== null) relativePath(item.originalPath);
        if (item.originalSide !== undefined && item.originalSide !== null) enumeration(item.originalSide, ['old', 'new'], 'original side');
        for (const field of ['startLine', 'originalStartLine']) if (item[field] !== undefined && item[field] !== null) integer(item[field], field, 1);
        if (item.outdated !== undefined) check(item.outdated === null || typeof item.outdated === 'boolean', 'outdated must be boolean or null.');
    });
    check(new Set(snapshot.discussion.items.map((item) => item.id)).size === snapshot.discussion.items.length, 'Duplicate discussion IDs.');
    array(snapshot.discussion.limitations, 'discussion limitations').forEach((entry) => text(entry, 'limitation'));
    array(snapshot.omissions, 'omissions').forEach((entry) => text(entry, 'omission'));
    if (snapshot.metadata) {
        object(snapshot.metadata, ['status', 'fields'], 'metadata');
        enumeration(snapshot.metadata.status, ['complete', 'partial', 'unavailable', 'not_applicable'], 'metadata status');
        array(snapshot.metadata.fields, 'metadata fields').forEach((field) => {
            object(field, ['name', 'value', 'source'], 'metadata field');
            id(field.name, 'metadata name');
            text(field.value, 'metadata value', true);
            text(field.source, 'metadata provenance');
        });
        check(new Set(snapshot.metadata.fields.map((field) => field.name)).size === snapshot.metadata.fields.length, 'Duplicate metadata fields.');
    }
    return snapshot;
}

export function validateAnchor(anchor, snapshot, assignedFiles, assignedHunks) {
    object(anchor, ['fileId', 'hunkId', 'side', 'startLine', 'endLine'], 'anchor', ['field']);
    if (anchor.side === 'metadata') {
        check(snapshot.target.kind === 'pr' && anchor.fileId === null && anchor.hunkId === null && anchor.startLine === null && anchor.endLine === null,
            'Metadata anchors require PR context and no invented source location.');
        check(snapshot.metadata?.fields.some((field) => field.name === anchor.field), 'Metadata anchor does not identify a captured field.');
        return anchor;
    }
    check(!own(anchor, 'field'), 'Only metadata anchors name a field.');
    const file = snapshot.files.find((entry) => entry.id === anchor.fileId);
    check(file && (!assignedFiles || assignedFiles.includes(file.id)), 'Anchor file is outside the assigned snapshot.');
    enumeration(anchor.side, ['old', 'new', 'file'], 'anchor side');
    if (anchor.side === 'file') {
        check(anchor.hunkId === null && anchor.startLine === null && anchor.endLine === null, 'File anchors cannot invent line positions.');
        return anchor;
    }
    const hunk = file.hunks.find((entry) => entry.id === anchor.hunkId);
    check(hunk && (!assignedHunks || assignedHunks.includes(hunk.id)), 'Anchor hunk is outside the assignment.');
    integer(anchor.startLine, 'anchor start', 1);
    integer(anchor.endLine, 'anchor end', anchor.startLine);
    const start = hunk[`${anchor.side}Start`];
    check(anchor.startLine >= start && anchor.endLine < start + hunk[`${anchor.side}Count`], 'Anchor is outside its captured hunk.');
    check(hunk[`${anchor.side}Lines`].some((line) => line >= anchor.startLine && line <= anchor.endLine), 'Anchor does not intersect changed lines.');
    return anchor;
}

function finding(value, snapshot, work, merged = false) {
    object(value, ['id', 'severity', 'claim', 'consequence', 'anchors', 'criterion', 'remediation', ...(merged ? ['sources', 'disposition', 'reason'] : [])], 'finding', ['snippet']);
    id(value.id);
    enumeration(value.severity, SEVERITIES, 'severity');
    for (const field of ['claim', 'consequence', 'remediation']) text(value[field], field);
    if (value.criterion !== null) text(value.criterion, 'criterion');
    if (own(value, 'snippet')) text(value.snippet, 'snippet');
    check(array(value.anchors, 'anchors').length > 0, 'A finding requires evidence.');
    value.anchors.forEach((anchor) => validateAnchor(anchor, snapshot, work?.fileIds, work?.hunkIds));
    if (work && work.perspective !== 'readiness') check(value.anchors.every((anchor) => anchor.side !== 'metadata'), 'PR deliverable findings belong to readiness.');
    if (merged) {
        ids(value.sources, 'finding sources');
        check(value.sources.length > 0, 'A finding needs a source work item.');
        enumeration(value.disposition, ['proposed', 'accepted', 'disputed', 'deferred', 'rejected'], 'disposition');
        if (value.disposition === 'proposed') check(value.reason === null, 'Proposed findings have no parent decision.');
        else text(value.reason, 'disposition reason');
    }
}

function workItem(work, snapshot, areaIds) {
    object(work, ['id', 'snapshotId', 'perspective', 'areaIds', 'fileIds', 'hunkIds', 'required', 'status', 'outputPath', 'coverage', 'resultKey', 'summary', 'observations'], 'work item');
    id(work.id);
    id(work.snapshotId);
    enumeration(work.perspective, PERSPECTIVES, 'perspective');
    enumeration(work.status, WORK_STATES, 'work status');
    check(work.snapshotId === snapshot.snapshotId || work.status === 'stale', 'Old work must be marked stale.');
    check(typeof work.required === 'boolean', 'required must be boolean.');
    if (['context', 'investigation'].includes(work.perspective)) check(!work.required, 'Context/investigation cannot stand in for review coverage.');
    ids(work.areaIds, 'work areas', areaIds);
    check(work.areaIds.length > 0, 'Work needs an assigned area.');
    ids(work.fileIds, 'work files', new Set(snapshot.files.map((file) => file.id)));
    check(work.fileIds.length > 0, 'Work needs assigned files.');
    ids(work.hunkIds, 'work hunks', new Set(snapshot.files.filter((file) => work.fileIds.includes(file.id)).flatMap((file) => file.hunks.map((hunk) => hunk.id))));
    check(work.outputPath === `results/${work.snapshotId}/${work.id}.json`, 'Work output path must match its snapshot and ID.');
    coverage(work.coverage, work.fileIds, work.hunkIds);
    if (work.status === 'completed') {
        check(work.resultKey !== null, 'Completed work requires a validated result.');
        check(work.coverage.notApplicable !== null || (work.fileIds.every((entry) => work.coverage.fileIds.includes(entry)) &&
            work.hunkIds.every((entry) => work.coverage.hunkIds.includes(entry))), 'Completed work has incomplete coverage.');
    }
    if (work.resultKey !== null) text(work.resultKey, 'result key');
    text(work.summary, 'work summary', true);
    array(work.observations, 'observations').forEach((entry) => text(entry, 'observation'));
}

export function areaStatus(state, areaId) {
    const work = state.workItems.filter((item) => item.required && item.areaIds.includes(areaId));
    if (!work.length) return 'pending';
    for (const status of ['stale', 'blocked', 'unavailable', 'skipped']) if (work.some((item) => item.status === status)) return status;
    const area = state.areas.find((entry) => entry.id === areaId);
    const covered = [...new Set(work.map((item) => item.perspective))].every((perspective) =>
        area.fileIds.every((fileId) => work.some((item) => item.perspective === perspective && item.fileIds.includes(fileId))));
    if (covered && work.every((item) => item.status === 'completed')) return 'reviewed';
    return work.some((item) => item.status !== 'pending') ? 'in_progress' : 'pending';
}

function execution(state) {
    if (state.limitations.some((entry) => entry.blocking) ||
        state.workItems.some((item) => item.required && ['blocked', 'unavailable', 'skipped', 'stale'].includes(item.status))) return 'incomplete';
    return state.areas.length > 0 && state.areas.every((area) => areaStatus(state, area.id) === 'reviewed') &&
        state.findings.every((entry) => entry.disposition !== 'proposed') ? 'completed' : 'in_progress';
}

/** Paths of captured files that no area assigns; areas must leave none before work is scheduled. */
export function unassignedFiles(state, snapshot) {
    const assigned = new Set(state.areas.flatMap((area) => area.fileIds));
    return snapshot.files.filter((file) => !assigned.has(file.id)).map((file) => file.newPath ?? file.oldPath);
}

export function outcome(state) {
    if (execution(state) !== 'completed') return null;
    const retained = state.findings.filter((entry) => entry.disposition !== 'rejected');
    if (retained.some((entry) => ['Critical', 'High'].includes(entry.severity))) return 'request_changes';
    return retained.length ? 'approve_with_comments' : 'approve';
}

export function validateState(state, snapshot) {
    validateSnapshot(snapshot);
    object(state, ['schemaVersion', 'reviewId', 'snapshotId', 'revision', 'status', 'snapshotPath', 'areas', 'workItems', 'findings', 'limitations', 'artifacts', 'outcome'], 'state', ['scope', 'context', 'reasons', 'changeMap']);
    version(state);
    check(state.reviewId === snapshot.reviewId && state.snapshotId === snapshot.snapshotId, 'State and snapshot identities differ.');
    integer(state.revision, 'revision');
    check(state.snapshotPath === `snapshots/${snapshot.snapshotId}/snapshot.json`, 'State snapshot path does not match its identity.');
    array(state.areas, 'areas').forEach((area) => {
        object(area, ['id', 'title', 'fileIds', 'summary', 'before', 'after', 'impact'], 'area');
        id(area.id);
        text(area.title, 'area title');
        ids(area.fileIds, 'area files', new Set(snapshot.files.map((file) => file.id)));
        check(area.fileIds.length > 0, 'An area requires files.');
        for (const field of ['summary', 'before', 'after']) text(area[field], field, true);
        array(area.impact, 'impact').forEach((edge) => {
            object(edge, ['from', 'to', 'description', 'anchor', 'uncertainty'], 'impact edge');
            for (const field of ['from', 'to', 'description']) text(edge[field], field);
            if (edge.anchor !== null) validateAnchor(edge.anchor, snapshot);
            if (edge.uncertainty !== null) text(edge.uncertainty, 'uncertainty');
            check(edge.anchor !== null || edge.uncertainty !== null, 'An impact relationship needs evidence or an explicit uncertainty.');
        });
    });
    unique(state.areas, 'areas');
    if (state.areas.length) {
        const unassigned = unassignedFiles(state, snapshot);
        check(unassigned.length === 0, `Areas must include every captured file; unassigned: ${unassigned.join(', ')}.`);
    }
    const areas = new Set(state.areas.map((area) => area.id));
    array(state.workItems, 'work items').forEach((work) => {
        workItem(work, snapshot, areas);
        check(work.fileIds.every((fileId) => state.areas.some((area) => work.areaIds.includes(area.id) && area.fileIds.includes(fileId))), 'Work files must belong to its areas.');
    });
    unique(state.workItems, 'work items');
    array(state.findings, 'findings').forEach((entry) => {
        finding(entry, snapshot, null, true);
        check(entry.sources.every((source) => state.workItems.some((work) => work.id === source)), 'Unknown finding source.');
    });
    unique(state.findings, 'findings');
    limitations(state.limitations);
    object(state.artifacts, ['report'], 'artifacts', ['reportDigest']);
    if (state.artifacts.report !== null) check(state.artifacts.report === 'review.md', 'Report path must be review.md.');
    if (own(state.artifacts, 'reportDigest')) check(/^[a-f0-9]{64}$/.test(state.artifacts.reportDigest), 'Invalid report digest.');
    if (own(state, 'scope')) {
        object(state.scope, ['profile', 'depth', 'mode', 'rationale'], 'scope');
        enumeration(state.scope.profile, ['basic', 'standard', 'full', 'custom'], 'profile');
        enumeration(state.scope.depth, ['basic', 'standard', 'comprehensive'], 'depth');
        enumeration(state.scope.mode, ['sweep', 'guided', 'host-managed'], 'mode');
        text(state.scope.rationale, 'scope rationale');
    }
    if (own(state, 'context')) {
        object(state.context, [], 'context', ['acceptanceCriteria', 'businessAlignment', 'securityPlanDrift', 'stakeholderNotes']);
        for (const value of Object.values(state.context)) check(value !== undefined && value !== null, 'Context records must carry explicit evidence.');
    }
    if (own(state, 'reasons')) reasons(state.reasons, snapshot);
    if (own(state, 'changeMap')) changeMap(state.changeMap, snapshot, new Set((state.reasons ?? []).map((reason) => reason.id)));
    check(state.status === execution(state), 'State status disagrees with evidence.');
    check(state.outcome === outcome(state), 'Review outcome disagrees with coverage or finding dispositions.');
    return state;
}

export function finalizeState(state, snapshot) {
    state.status = execution(state);
    state.outcome = outcome(state);
    return validateState(state, snapshot);
}

export function initialState(snapshot) {
    validateSnapshot(snapshot);
    return finalizeState({
        schemaVersion: 1, reviewId: snapshot.reviewId, snapshotId: snapshot.snapshotId, revision: 0,
        status: 'in_progress', snapshotPath: `snapshots/${snapshot.snapshotId}/snapshot.json`,
        areas: [], workItems: [], findings: [], limitations: [], artifacts: { report: null }, outcome: null,
    }, snapshot);
}

export function newWork(snapshot, area, perspective, workId) {
    return {
        id: id(workId), snapshotId: snapshot.snapshotId, perspective, areaIds: [area.id],
        fileIds: [...area.fileIds], hunkIds: snapshot.files.filter((file) => area.fileIds.includes(file.id)).flatMap((file) => file.hunks.map((hunk) => hunk.id)),
        required: !['context', 'investigation'].includes(perspective), status: 'pending',
        outputPath: `results/${snapshot.snapshotId}/${workId}.json`,
        coverage: { fileIds: [], hunkIds: [], notApplicable: null }, resultKey: null, summary: '', observations: [],
    };
}

export function validateResult(result, state, snapshot) {
    object(result, ['schemaVersion', 'reviewId', 'snapshotId', 'workItemId', 'execution', 'summary', 'coverage', 'findings', 'observations', 'limitations'], 'result');
    version(result);
    check(result.reviewId === state.reviewId && result.snapshotId === state.snapshotId, 'Result is for a different review or stale snapshot.', 'stale_result');
    const work = state.workItems.find((item) => item.id === result.workItemId);
    check(work && work.snapshotId === result.snapshotId && work.status !== 'stale', 'Result has no current assignment.');
    enumeration(result.execution, ['completed', 'blocked', 'unavailable'], 'result execution');
    text(result.summary, 'result summary');
    coverage(result.coverage, work.fileIds, work.hunkIds);
    if (result.execution === 'completed') check(result.coverage.notApplicable !== null ||
        (work.fileIds.every((entry) => result.coverage.fileIds.includes(entry)) && work.hunkIds.every((entry) => result.coverage.hunkIds.includes(entry))), 'Completed result has incomplete coverage.');
    array(result.findings, 'result findings').forEach((entry) => finding(entry, snapshot, work));
    unique(result.findings, 'result findings');
    if (['context', 'investigation'].includes(work.perspective)) check(result.findings.length === 0, 'Context/investigation returns observations; the parent schedules grading separately.');
    array(result.observations, 'observations').forEach((entry) => text(entry, 'observation'));
    limitations(result.limitations);
    if (result.execution !== 'completed') check(result.limitations.length > 0, 'Incomplete results need an explicit limitation.');
    return work;
}

export function stableJson(value) {
    if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
    if (value && typeof value === 'object') return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
    return JSON.stringify(value);
}

function appendFindings(next, work, findings) {
    for (const entry of findings) {
        const duplicate = next.findings.find((existing) => existing.claim === entry.claim && stableJson(existing.anchors) === stableJson(entry.anchors));
        if (duplicate) {
            if (!duplicate.sources.includes(work.id)) duplicate.sources.push(work.id);
            if (SEVERITIES.indexOf(entry.severity) < SEVERITIES.indexOf(duplicate.severity)) {
                duplicate.severity = entry.severity;
                duplicate.disposition = 'proposed';
                duplicate.reason = null;
            }
            continue;
        }
        check(!next.findings.some((existing) => existing.id === entry.id), 'Finding ID collision.', 'result_conflict');
        next.findings.push({ ...structuredClone(entry), sources: [work.id], disposition: 'proposed', reason: null });
    }
}

export function assess(state, snapshot, workItemId, findings) {
    validateState(state, snapshot);
    const work = state.workItems.find((entry) => entry.id === workItemId);
    check(work && !['context', 'investigation'].includes(work.perspective), 'Parent findings need an owning review work item.');
    array(findings, 'parent findings').forEach((entry) => finding(entry, snapshot, work));
    const next = structuredClone(state);
    appendFindings(next, work, findings);
    return finalizeState(next, snapshot);
}

export function mergeResult(state, snapshot, result, resultKey) {
    validateState(state, snapshot);
    const assigned = validateResult(result, state, snapshot);
    text(resultKey, 'result key');
    if (assigned.resultKey !== null) {
        check(assigned.resultKey === resultKey, 'A different result was already merged; allocate a new work item.', 'result_conflict');
        return structuredClone(state);
    }
    const next = structuredClone(state);
    const work = next.workItems.find((item) => item.id === assigned.id);
    Object.assign(work, { status: result.execution, coverage: structuredClone(result.coverage), resultKey, summary: result.summary, observations: [...result.observations] });
    appendFindings(next, work, result.findings);
    for (const entry of result.limitations) {
        const limitation = { ...entry, id: `${work.id}.${entry.id}`, blocking: entry.blocking || (work.required && result.execution !== 'completed') };
        id(limitation.id);
        next.limitations.push(limitation);
    }
    next.revision++;
    return finalizeState(next, snapshot);
}
