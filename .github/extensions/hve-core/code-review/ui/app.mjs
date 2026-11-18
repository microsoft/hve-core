// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, count, h, icon, idChip, meta, prose, shortSha, svg, time } from './dom.mjs';
import {
    anchorLabel, arrivals, AVAILABILITY, boardLanes, bySeverity, DISPOSITION, EXECUTION, FEEDBACK_KIND, feedbackState, fileAnnotations,
    fileLabel, fileStats, fileStatus, findingGroups, findingsFor, hidingNarrowing, hunkAnnotations, isMarked, isRetained, matches, needsAttention, needsYou, perspectiveProgress,
    NOT_EXPLAINED, OUTCOME, PERSPECTIVE, perspectiveOf, plainText, reasonCoverage, reasonFiles, resolveFocus, REVIEWER_STATUS, REVIEWERS, reviewFlow, SEVERITY, splitPath,
    STAGE_STATUS, stageFor, stages, targetPresent, targetSummary,
} from './views.mjs';
import { layoutMap, MAP_VIEWS, mapModel, tagWords } from './map.mjs';
import { closeMapPreview, renderMap } from './diagram.mjs';

const $ = (id) => document.getElementById(id);
const token = document.querySelector('meta[name="review-token"]').content;
const STAGE_KEYS = ['capture', 'review', 'outcome'];
const ui = {
    stage: 'review', target: null, focus: null, filter: '', follow: true, live: 'connecting',
    navHidden: false, steerHidden: false, drawer: null, boardOpen: true, boardLane: null, flowOpen: true, shortcuts: true, reportText: null,
    remoteFocus: '', needsIndex: -1, composer: { id: null, target: null, saved: '' }, loaded: false,
    mapView: 'changes', mapPinned: null, mapText: false, reason: null,
    expandedFinding: null, groupOpen: new Map(), findingArea: false, shownFindings: new Set(), newlyShown: new Set(), heldIds: new Set(), discussionOpen: false,
};
const MAP_VIEW_WORDS = { changes: 'Changes', before: 'Before', after: 'After' };
let mapCache = { key: null, model: null, layout: null };
let coverageCache = { key: null, value: null };
let view = null;
const evidence = new Map();
let loading = null;
let reloading = null;
let sendRevision = null;

// Transport

async function api(url, body) {
    const response = await fetch(url, {
        method: body === undefined ? 'GET' : 'POST',
        headers: { 'X-Review-Token': token, ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.message ?? `Request failed (${response.status}).`);
    return result;
}

/** Errors use the assertive alert region; everything else waits politely. */
function announce(message, { urgent = false } = {}) {
    const region = $(urgent ? 'alerter' : 'announcer');
    region.textContent = '';
    window.setTimeout(() => { region.textContent = message; }, 30);
}

function reportFailure(message) {
    note(message, 'danger', 'alert');
}

/** A dismissible status note; `quiet` leaves the announcement to a caller that combines news. */
function note(message, tone, iconName, action = null, { quiet = false } = {}) {
    const area = $('statusArea');
    const element = h('div', { class: `notice status-note tone-${tone}` }, icon(iconName), h('p', { class: 'status-note-text' }, message));
    if (action) element.append(h('button', { type: 'button', class: 'btn btn-compact', on: { click: () => { element.remove(); syncStatus(); action.run(); } } }, action.label));
    element.append(h('button', { type: 'button', class: 'icon-btn', title: 'Dismiss', on: { click: () => { element.remove(); syncStatus(); } } },
        icon('x'), h('span', { class: 'visually-hidden' }, 'Dismiss')));
    area.append(element);
    while (area.children.length > 3) area.firstElementChild.remove();
    syncStatus();
    if (!quiet) announce(message, { urgent: tone === 'danger' });
}

function syncStatus() {
    $('statusArea').hidden = $('statusArea').children.length === 0;
}

function run(action) {
    return Promise.resolve().then(action).catch((error) => reportFailure(error.message ?? String(error)));
}

// Selection

const about = (kind, id) => ({ kind, id, snapshotId: view.snapshotId });
/** Whether the reader has been shown a finding; held arrivals stay out of every finding surface. */
const isShown = (finding) => ui.shownFindings.has(finding.id);

function select(target, { stage = null, moveFocus = true, flash = false } = {}) {
    ui.target = target;
    ui.focus = resolveFocus(view, target);
    ui.boardLane = null;
    if (target.kind === 'reason') ui.reason = target.id;
    else if (target.kind === 'area') ui.reason = null;
    if (target.kind === 'finding') revealFinding(target.id);
    if (target.kind === 'comment') ui.discussionOpen = true;
    if (target.kind === 'perspective') ui.flowOpen = true;
    if (stage) ui.stage = stage;
    render({ keepScroll: false });
    const element = selectionElement();
    if (element) {
        element.scrollIntoView({ block: 'start', behavior: 'auto' });
        if (flash) {
            element.classList.remove('is-flash');
            void element.offsetWidth;
            element.classList.add('is-flash');
        }
        if (moveFocus) element.focus({ preventScroll: true });
    } else if (moveFocus) $('viewTitle')?.focus({ preventScroll: true });
}

/**
 * Selects a reason as a lens over files, findings, and the map, or clears it with null. The file in
 * view stays when the reason explains it; otherwise the reason's first file opens.
 */
function selectReason(reasonId) {
    ui.reason = reasonId;
    const files = reasonId ? reasonFiles(view, reasonId, currentCoverage()) : [];
    if (files.length && !files.includes(ui.focus?.fileId)) {
        ui.target = reasonId === NOT_EXPLAINED ? about('file', files[0]) : about('reason', reasonId);
        ui.focus = resolveFocus(view, ui.target);
    }
    render();
    const what = reasonId === NOT_EXPLAINED ? 'Changes no reason explains' : `Reason ${reasonId}`;
    announce(reasonId ? `${what}: ${files.length} ${files.length === 1 ? 'file' : 'files'}.` : 'All changes.');
}

/** Reason coverage for the current revision, computed once and shared by every row. */
function currentCoverage() {
    const key = `${view.snapshotId}:${view.revision}`;
    if (coverageCache.key !== key) coverageCache = { key, value: reasonCoverage(view) };
    return coverageCache.value;
}

/**
 * Shows a finding: releases it if held, opens its group, expands it, and drops a reason or area
 * narrowing that would hide it.
 */
function revealFinding(findingId) {
    const finding = view.findings.find((entry) => entry.id === findingId);
    if (!finding) return;
    ui.shownFindings.add(findingId);
    ui.expandedFinding = findingId;
    const group = findingGroups([finding])[0];
    if (group) ui.groupOpen.set(group.id, true);
    clearHidingNarrowing([findingId]);
}

/** Clears the reason lens or area scope when either would hide one of the findings; returns which. */
function clearHidingNarrowing(ids) {
    const hidden = hidingNarrowing(view, ids, { reasonId: ui.reason, areaId: ui.findingArea ? ui.focus?.areaId ?? null : null });
    if (hidden.reason) ui.reason = null;
    if (hidden.area) ui.findingArea = false;
    return hidden;
}

function selectionElement() {
    const target = ui.target;
    if (!target) return null;
    const escape = (value) => CSS.escape(value);
    if (ui.stage === 'capture' && ui.focus.metadataField) return document.querySelector(`#meta-${escape(ui.focus.metadataField)}`);
    if (ui.stage !== 'review') return null;
    if (target.kind === 'reason') return document.querySelector(`[data-key="reason-${escape(target.id)}"]`);
    if (target.kind === 'perspective') return document.querySelector(`#reviewer-${escape(target.id)}`);
    if (target.kind === 'finding') return document.querySelector(`#finding-${escape(target.id)}`);
    if (target.kind === 'comment') return document.querySelector(`#comment-${escape(target.id)}`);
    if (ui.focus.hunkId) return document.querySelector(`#hunk-${escape(ui.focus.hunkId)}`);
    if (target.kind === 'file') return $('row-diff');
    if (target.kind === 'area') return $('row-area');
    return null;
}

function goToAnchor(anchor) {
    if (anchor.side === 'metadata' || anchor.field) {
        ui.target = about('review', view.reviewId);
        ui.focus = { ...resolveFocus(view, ui.target), metadataField: anchor.field };
        ui.stage = 'capture';
        render({ keepScroll: false });
        const element = document.querySelector(`#meta-${CSS.escape(anchor.field)}`);
        element?.scrollIntoView({ block: 'start' });
        element?.focus({ preventScroll: true });
        return;
    }
    select(anchor.hunkId ? about('hunk', anchor.hunkId) : about('file', anchor.fileId), { stage: 'review' });
}

// Rendering

/**
 * Rebuilds the page from `view` and `ui`. Focus returns to the element with the same `data-key`, or
 * else the same `id`, and the document, navigator, and change map keep their scroll positions.
 */
function render({ keepScroll = true } = {}) {
    if (!view) return;
    const active = document.activeElement;
    const key = active?.dataset?.key;
    const id = !key && active && active !== document.body ? active.id : '';
    const inDocument = $('document').contains(active) || $('navBody').contains(active) || $('steer').contains(active);
    const inSteer = $('steer').contains(active);
    const scroll = { doc: $('document').scrollTop, nav: $('navigator').scrollTop };
    const map = document.querySelector('.change-map .diagram-scroll');
    const mapScroll = map ? { left: map.scrollLeft, top: map.scrollTop } : null;
    renderHeader();
    renderNav();
    renderContext();
    renderDocument();
    renderSteer();
    watchOffsets();
    if (keepScroll) {
        $('document').scrollTop = scroll.doc;
        $('navigator').scrollTop = scroll.nav;
    }
    const nextMap = mapScroll && document.querySelector('.change-map .diagram-scroll');
    if (nextMap) {
        nextMap.scrollLeft = mapScroll.left;
        nextMap.scrollTop = mapScroll.top;
    }
    if (key || id) {
        const restore = key ? [...document.querySelectorAll('[data-key]')].find((element) => element.dataset.key === key) : document.getElementById(id);
        if (restore && restore !== document.activeElement) restore.focus({ preventScroll: true });
        else if (!restore && inDocument && !document.activeElement?.closest('#steer .compose')) (inSteer ? $('feedbackTitle') : $('viewTitle'))?.focus({ preventScroll: true });
    }
}

const offsets = typeof ResizeObserver === 'function' ? new ResizeObserver(() => syncOffsets()) : null;

/**
 * Measures the context bar and, while it is pinned, the Coverage board into `--cr-context-h` and
 * `--cr-dock-h`, which place the sticky diff header and the document's scroll padding.
 */
function syncOffsets() {
    const doc = $('document');
    const dock = doc.querySelector('.board-dock');
    const pinned = dock && window.getComputedStyle(dock).position === 'sticky';
    doc.style.setProperty('--cr-context-h', `${$('contextBar').offsetHeight}px`);
    doc.style.setProperty('--cr-dock-h', `${pinned ? dock.offsetHeight : 0}px`);
}

/** Watches the rebuilt board and the context bar, so wrapping, collapsing, or a short panel updates the offsets. */
function watchOffsets() {
    if (!offsets) {
        syncOffsets();
        return;
    }
    offsets.disconnect();
    offsets.observe($('document'));
    offsets.observe($('contextBar'));
    const dock = $('document').querySelector('.board-dock');
    if (dock) offsets.observe(dock);
    syncOffsets();
}

function renderHeader() {
    const summary = targetSummary(view);
    $('reviewTitle').textContent = summary.title;
    document.title = `Code Review: ${summary.title}`;
    const kindIcon = { pr: 'branch', branch: 'branch', local: 'pencil', commit: 'code', selected: 'file' }[view.target.kind] ?? 'file';
    const parts = [badge({ label: summary.kind, icon: kindIcon, tone: 'accent' })];
    if (summary.provider) parts.push(idChip(summary.provider, { title: `${view.target.provider.name} ${summary.provider}` }));
    if (summary.base || summary.head) {
        parts.push(h('span', { class: 'range', title: `${summary.base ?? 'no base'} to ${summary.head ?? 'working tree'}` },
            `${shortSha(summary.base) ?? '∅'} → ${shortSha(summary.head) ?? 'working tree'}`));
    }
    parts.push(idChip(view.reviewId.replace(/^(review-[0-9a-f]{8}).*$/, '$1'), { kind: 'review', title: `Review ${view.reviewId}` }));
    parts[parts.length - 1].classList.add('review-id');
    parts.push(meta(`Revision ${view.revision}`));
    if (view.stale) parts.push(badge({ label: 'Stale source', icon: 'alert', tone: 'attention' }));
    $('reviewMeta').replaceChildren(...parts);
    renderRail();

    const needs = needsYou(view);
    $('needsBtn').classList.toggle('has-items', needs.length > 0);
    $('needsCount').textContent = String(needs.length);
    $('needsBtn').setAttribute('aria-label', needs.length ? `Needs you, ${needs.length} ${needs.length === 1 ? 'finding' : 'findings'}` : 'Needs you, nothing waiting');
    const queued = view.feedback.items.filter((item) => item.status === 'queued').length;
    $('sendBtn').classList.toggle('has-items', queued > 0);
    $('sendCount').textContent = String(queued);
    $('sendBtn').setAttribute('aria-label', queued ? `Review and send, ${queued} waiting` : 'Review and send, nothing waiting');
    renderLive();
}

function renderRail() {
    const rail = $('stageRail');
    const needs = needsYou(view);
    const list = stages(view);
    const nodes = [];
    list.forEach((stage, index) => {
        if (index) nodes.push(h('span', { class: `rail-seg${list[index - 1].status === 'done' ? ' is-done' : ''}`, 'aria-hidden': 'true' }));
        const status = STAGE_STATUS[stage.status];
        const waiting = needs.filter((item) => item.stage === stage.id).length;
        const selected = ui.stage === stage.id;
        nodes.push(h('button', {
            type: 'button', role: 'tab', id: `tab-${stage.id}`, class: `rail-tab tone-${status.tone}`, 'aria-selected': selected, 'aria-controls': 'document',
            tabIndex: selected ? 0 : -1, 'aria-keyshortcuts': String(index + 1), dataset: { key: `tab-${stage.id}`, stage: stage.id },
            'aria-label': `${stage.label}, ${status.label.toLowerCase()}, ${stage.detail}${waiting ? `, ${waiting} ${waiting === 1 ? 'needs' : 'need'} you` : ''}`,
            title: `${stage.label}: ${stage.detail} (${index + 1})`,
            on: { click: () => setStage(stage.id), keydown: railKeys },
        }, icon(status.icon), h('span', { class: 'rail-label' }, stage.label), waiting ? h('span', { class: 'rail-count', 'aria-hidden': 'true' }, String(waiting)) : null));
    });
    rail.replaceChildren(...nodes);
}

function railKeys(event) {
    const order = STAGE_KEYS;
    const index = order.indexOf(event.currentTarget.dataset.stage);
    let next = null;
    if (event.key === 'ArrowRight') next = order[(index + 1) % order.length];
    else if (event.key === 'ArrowLeft') next = order[(index - 1 + order.length) % order.length];
    else if (event.key === 'Home') next = order[0];
    else if (event.key === 'End') next = order.at(-1);
    if (!next) return;
    event.preventDefault();
    setStage(next, { focusTab: true });
}

function setStage(stage, { focusTab = false } = {}) {
    if (!STAGE_KEYS.includes(stage)) return;
    const changed = ui.stage !== stage;
    ui.stage = stage;
    if (changed) ui.boardLane = null;
    render({ keepScroll: !changed });
    if (changed) $('document').scrollTop = 0;
    if (focusTab) $(`tab-${stage}`)?.focus();
    if (changed) announce(`Showing ${stages(view).find((entry) => entry.id === stage).label}.`);
}

function renderLive() {
    const button = $('liveBtn');
    button.dataset.state = ui.live;
    button.dataset.follow = ui.follow ? 'on' : 'off';
    button.setAttribute('aria-pressed', String(ui.follow));
    button.querySelector('use').setAttribute('href', ui.follow && ui.live === 'live' ? '#i-live' : '#i-live-off');
    const label = ui.live === 'connecting' ? 'Connecting' : ui.live === 'reconnecting' ? 'Reconnecting' : ui.follow ? 'Live' : 'Follow agent';
    $('liveLabel').textContent = label;
    button.title = ui.follow ? 'Live: the canvas updates and follows where the agent points. Select to stop following.' : 'Updates continue, but agent focus requests wait for you. Select to follow the agent.';
}

// Navigator

function navItem({ key, iconName, tone, label, title, current, countValue, countLabel = null, onClick, className = '' }) {
    return h('li', {}, h('button', {
        type: 'button', class: `nav-item${className ? ` ${className}` : ''}${tone ? ` tone-${tone}` : ''}`, 'aria-current': current ? 'true' : null, title,
        dataset: { key }, on: { click: onClick },
    }, iconName ? icon(iconName) : null, h('span', { class: 'nav-label' }, label), countValue !== undefined && countValue !== null ? count(countValue, countLabel) : null));
}

function fileLetter(file) {
    const status = fileStatus(file);
    return h('span', { class: `file-letter tone-${status.tone}`, title: status.label }, h('span', { 'aria-hidden': 'true' }, file.status), h('span', { class: 'visually-hidden' }, `${status.label}: `));
}

function renderNav() {
    const body = $('navBody');
    const filter = ui.filter;
    const sections = [];
    if (ui.stage === 'review') {
        const areas = view.areas.filter((area) => matches(filter, area.title, area.id) || view.files.some((file) => area.fileIds.includes(file.id) && matches(filter, fileLabel(file))));
        sections.push(h('h2', { class: 'nav-title' }, 'Areas', count(view.areas.length)));
        const list = h('ul', { class: 'nav-list' });
        for (const area of areas) {
            const status = EXECUTION[area.status] ?? EXECUTION.pending;
            const item = navItem({
                key: `nav-area-${area.id}`, iconName: status.icon, tone: status.tone, label: area.title, title: `${area.title}: ${status.label}`,
                current: ui.focus.areaId === area.id, countValue: area.fileIds.length, countLabel: `${status.label.toLowerCase()}, ${area.fileIds.length} ${area.fileIds.length === 1 ? 'file' : 'files'}`,
                onClick: () => select(about('area', area.id), { stage: 'review' }),
            });
            if (ui.focus.areaId === area.id || filter) {
                const files = view.files.filter((file) => area.fileIds.includes(file.id) && (!filter || matches(filter, fileLabel(file), area.title)));
                if (files.length) {
                    item.append(h('ul', { class: 'nav-sublist', 'aria-label': `Files in ${area.title}` }, files.map((file) => h('li', {}, h('button', {
                        type: 'button', class: 'nav-item nav-file', title: fileLabel(file), 'aria-current': ui.focus.fileId === file.id ? 'true' : null,
                        dataset: { key: `nav-file-${file.id}` }, on: { click: () => select(about('file', file.id), { stage: 'review' }) },
                    }, fileLetter(file), h('span', { class: 'nav-label' }, splitPath(file.newPath ?? file.oldPath).name))))));
                }
            }
            list.append(item);
        }
        sections.push(list);
        if (!areas.length) sections.push(h('p', { class: 'empty' }, filter ? 'No areas or files match the filter.' : 'The review has no areas yet.'));
        // Held arrivals stay out of the navigator until the reader shows them.
        const findings = view.findings.filter((finding) => ui.shownFindings.has(finding.id) && matches(filter, finding.claim, finding.id, finding.severity))
            .sort((left, right) => Number(left.disposition === 'rejected') - Number(right.disposition === 'rejected') || bySeverity(left, right));
        sections.push(h('h2', { class: 'nav-title' }, 'Findings', count(findings.length)));
        if (findings.length) {
            sections.push(h('ul', { class: 'nav-list' }, findings.map((finding) => {
                const severity = SEVERITY[finding.severity];
                return navItem({
                    key: `nav-finding-${finding.id}`, iconName: severity.icon, tone: severity.tone, label: plainText(finding.claim), title: `${finding.severity}: ${plainText(finding.claim)}`,
                    current: ui.focus.findingId === finding.id, onClick: () => select(about('finding', finding.id), { stage: 'review' }),
                });
            })));
        }
        const threads = view.discussion.items.filter((comment) => !comment.replyTo && matches(filter, comment.author, comment.body));
        sections.push(h('h2', { class: 'nav-title' }, 'Discussion', count(view.discussion.items.length)));
        if (threads.length) {
            sections.push(h('ul', { class: 'nav-list' }, threads.map((comment) => navItem({
                key: `nav-comment-${comment.id}`, iconName: 'message', tone: 'user', label: `${comment.author}: ${plainText(comment.body)}`, title: plainText(comment.body),
                current: ui.focus.commentId === comment.id, onClick: () => select(about('comment', comment.id), { stage: 'review' }),
            }))));
        }
    } else {
        const outline = ui.stage === 'capture'
            ? [['row-target', 'Target', 'branch'], ['row-changes', 'Changed files', 'diff', view.files.length], ['row-scope', 'Scope', 'list'],
                ['row-details', 'Pull request details', 'info', view.metadata?.fields?.length ?? 0], ['row-limits', 'Evidence limits', 'alert', view.limitations.length + view.discussion.limitations.length]]
            : [['row-outcome', 'Outcome', 'flag'], ['row-report', 'Report', 'file'], ['row-publication', 'Publishing', 'send']];
        sections.push(h('h2', { class: 'nav-title' }, `${ui.stage === 'capture' ? 'Capture' : 'Outcome'} outline`));
        sections.push(h('ul', { class: 'nav-list' }, outline.filter(([, label]) => matches(filter, label)).map(([id, label, iconName, value]) => navItem({
            key: `nav-${id}`, iconName, label, countValue: value, onClick: () => {
                const row = $(id);
                row?.scrollIntoView({ block: 'start' });
                row?.focus({ preventScroll: true });
                closeDrawer(false);
            },
        }))));
    }
    body.replaceChildren(...sections);
}

// Context bar and document

function renderContext() {
    const stage = stages(view).find((entry) => entry.id === ui.stage);
    const status = STAGE_STATUS[stage.status];
    $('contextBar').replaceChildren(
        h('div', { class: 'context-main' },
            h('h2', { class: 'context-title', id: 'viewTitle', tabIndex: -1 }, icon(stage.icon), stage.label),
            badge(status), h('p', { class: 'context-summary' }, icon('arrow-right'), contextSummary())),
    );
}

function contextSummary() {
    if (ui.stage === 'capture') {
        const totals = view.files.reduce((sum, file) => { const stats = fileStats(file); return { add: sum.add + stats.additions, del: sum.del + stats.deletions }; }, { add: 0, del: 0 });
        return `${targetSummary(view).kind}, ${view.files.length} ${view.files.length === 1 ? 'file' : 'files'}, ${totals.add} lines added, ${totals.del} removed.`;
    }
    if (ui.stage === 'review') {
        const lanes = boardLanes(view);
        const size = (id) => lanes.find((lane) => lane.id === id).areas.length;
        const proposed = view.findings.filter((finding) => finding.disposition === 'proposed').length;
        const checking = proposed ? `, ${proposed} ${proposed === 1 ? 'finding' : 'findings'} being checked` : '';
        return view.areas.length ? `${size('reviewed')} of ${view.areas.length} areas reviewed, ${size('active')} in progress${checking}.` : 'The agent has not scheduled review work yet.';
    }
    return view.outcome && !view.stale ? `The completed review recommends: ${OUTCOME[view.outcome].label.toLowerCase()}.` : `Execution is ${view.status.replace('_', ' ')}; no outcome is available yet.`;
}

function renderDocument() {
    const body = $('docBody');
    const nodes = [];
    if (view.stale) {
        nodes.push(h('div', { class: 'notice tone-attention', role: 'note' },
            h('p', { class: 'notice-title' }, icon('alert'), 'Showing the last valid review evidence'),
            prose(`${view.warning?.message ?? 'The review record could not be read.'} No current outcome is shown until the record is valid again.`, 'prose small')));
    }
    if (ui.stage === 'capture') nodes.push(...captureView());
    else if (ui.stage === 'review') nodes.push(...reviewView());
    else nodes.push(...outcomeView());
    body.replaceChildren(...nodes);
    if (ui.stage === 'review') void renderDiff();
}

function row(id, title, iconName, headExtras = [], ...content) {
    return h('section', { class: 'row', id, tabIndex: -1, 'aria-labelledby': `${id}-title` },
        h('div', { class: 'row-head' }, h('div', { class: 'row-heading' }, h('h3', { class: 'row-title', id: `${id}-title` }, icon(iconName), title), ...headExtras)),
        h('div', { class: 'row-text' }, ...content));
}

function facts(entries) {
    return h('dl', { class: 'facts' }, entries.filter(([, value]) => value !== null && value !== undefined && value !== '').flatMap(([label, value]) => [h('dt', {}, label), h('dd', {}, value)]));
}

function sha(value) {
    return value ? h('code', { title: value }, shortSha(value)) : null;
}

function captureView() {
    const target = view.target;
    const summary = targetSummary(view);
    const selection = target.selection?.length ? h('ul', { class: 'chip-row' }, target.selection.map((entry) => h('li', {}, h('code', {}, `${entry.path}:${entry.startLine}-${entry.endLine}`)))) : null;
    const statuses = {};
    let hunks = 0;
    let additions = 0;
    let deletions = 0;
    for (const file of view.files) {
        statuses[file.status] = (statuses[file.status] ?? 0) + 1;
        hunks += file.hunks.length;
        const stats = fileStats(file);
        additions += stats.additions;
        deletions += stats.deletions;
    }
    const stat = (label, value) => h('div', { class: 'stat' }, h('strong', {}, String(value)), meta(label));
    const omitted = view.files.filter((file) => file.omission);
    const reviewers = REVIEWERS.filter((entry) => (view.workItems ?? []).some((item) => item.perspective === entry.perspective && item.status !== 'stale'));
    const showFlow = () => {
        ui.stage = 'review';
        ui.flowOpen = true;
        render({ keepScroll: false });
        $('row-flow')?.scrollIntoView({ block: 'start' });
        $('row-flow')?.focus({ preventScroll: true });
    };
    const metadata = view.metadata ?? { status: 'unavailable', fields: [] };
    const statusMeta = { complete: { label: 'Complete', icon: 'check-circle', tone: 'success' }, partial: { label: 'Partial', icon: 'half', tone: 'attention' },
        unavailable: { label: 'Unavailable', icon: 'slash-circle', tone: 'muted' }, not_applicable: { label: 'Not applicable', icon: 'dash-circle', tone: 'muted' } };
    const limits = [...view.limitations.map((entry) => ({ text: entry.summary, blocking: entry.blocking })), ...view.discussion.limitations.map((text) => ({ text, blocking: false }))];
    return [
        row('row-target', 'Target', 'branch', [badge({ label: summary.kind, icon: 'branch', tone: 'accent' })], facts([
            ['Title', summary.title],
            ['Provider', summary.provider ? h('span', {}, `${target.provider.name} `, idChip(summary.provider)) : null],
            ['Base', sha(target.base)], ['Head', sha(target.head)], ['Merge base', sha(target.mergeBase)],
            ['Local mode', target.localMode], ['Selection', selection],
            ['Captured', view.capturedAt ? time(view.capturedAt) : null],
            ['Snapshot', idChip(view.snapshotId)], ['Review', idChip(view.reviewId, { kind: 'review' })],
        ])),
        row('row-changes', 'Changed files', 'diff', [count(view.files.length)],
            h('div', { class: 'stat-grid' }, stat('files', view.files.length), stat('hunks', hunks), stat('lines added', additions), stat('lines removed', deletions),
                ...Object.entries(statuses).map(([key, value]) => stat(fileStatus({ status: key }).label.toLowerCase(), value))),
            omitted.length ? h('div', { class: 'notice tone-attention' }, h('p', { class: 'notice-title' }, icon('alert'), `${omitted.length} ${omitted.length === 1 ? 'file is' : 'files are'} kept in inventory without text`),
                h('ul', {}, omitted.map((file) => h('li', {}, h('code', {}, fileLabel(file)), ` ${file.omission}`)))) : null),
        row('row-scope', 'Scope', 'list', [], view.scope ? facts([
            ['Profile', view.scope.profile], ['Depth', view.scope.depth], ['Mode', view.scope.mode],
            ['Reviewers', h('span', { class: 'chip-row' }, reviewers.map((entry) => badge({ label: entry.label, icon: 'eye', tone: 'muted' })),
                h('button', { type: 'button', class: 'link-btn', dataset: { key: 'scope-flow' }, on: { click: showFlow } }, 'See the review flow'))],
            ['Rationale', view.scope.rationale ? prose(view.scope.rationale, 'prose small') : null],
        ]) : h('p', { class: 'empty' }, 'The agent has not scheduled the review yet.')),
        row('row-details', 'Pull request details', 'info', [badge(statusMeta[metadata.status] ?? statusMeta.unavailable)], metadata.fields.length
            ? h('ul', { class: 'metadata-list' }, metadata.fields.map((field) => {
                const linked = view.findings.filter((finding) => isShown(finding) && finding.anchors.some((anchor) => anchor.field === field.name));
                return h('li', { class: `metadata-item${ui.focus.metadataField === field.name ? ' is-current' : ''}`, id: `meta-${field.name}`, tabIndex: -1 },
                    h('h4', {}, field.name), prose(field.value, 'prose small'), meta(`Source: ${field.source}`),
                    linked.length ? h('div', { class: 'chip-row' }, linked.map((finding) => findingChip(finding))) : null);
            }))
            : h('p', { class: 'empty' }, metadata.status === 'not_applicable' ? 'This target has no pull request details.' : 'Pull request details were not captured. Missing details are not a passed readiness check.')),
        row('row-limits', 'Evidence limits', 'alert', [count(limits.length)], limits.length
            ? h('ul', { class: 'steer-list' }, limits.map((entry) => h('li', { class: 'omission' }, entry.blocking ? badge({ label: 'Blocks the outcome', icon: 'alert', tone: 'danger' }) : icon('info'), prose(entry.text, 'prose small'))))
            : h('p', { class: 'empty' }, 'No evidence limits are recorded.')),
    ];
}

function perspectiveChips(work) {
    return h('div', { class: 'perspective-row' }, work.map((item) => {
        const status = EXECUTION[item.status] ?? EXECUTION.pending;
        return h('span', { class: `perspective tone-${status.tone}`, title: `${PERSPECTIVE[item.perspective] ?? item.perspective}: ${status.label}${item.coverage?.notApplicable ? ` (${item.coverage.notApplicable})` : ''}` },
            icon(status.icon), PERSPECTIVE[item.perspective] ?? item.perspective, h('span', { class: 'visually-hidden' }, `, ${status.label}`));
    }));
}

function areaFindings(area) {
    return view.findings.filter((finding) => isShown(finding) && finding.anchors.some((anchor) => area.fileIds.includes(anchor.fileId)));
}

function reviewView() {
    const nodes = [];
    const agentAreaId = view.focus?.snapshotId === view.snapshotId ? resolveFocus(view, view.focus).areaId : null;
    const lanes = boardLanes(view, { agentAreaId, selectedAreaId: ui.focus.areaId });
    const reviewed = lanes.find((lane) => lane.id === 'reviewed').areas.length;
    nodes.push(h('section', { class: 'board-dock', 'aria-labelledby': 'boardTitle' },
        h('div', { class: 'board-dock-head' },
            h('h3', { class: 'board-dock-title', id: 'boardTitle' }, icon('list'), 'Coverage board'),
            h('span', { class: 'board-progress' }, h('progress', { class: 'progress', max: Math.max(view.areas.length, 1), value: reviewed, 'aria-label': 'Areas reviewed' }),
                `${reviewed} of ${view.areas.length} areas reviewed`),
            h('button', { type: 'button', class: 'btn btn-icon board-dock-toggle', 'aria-expanded': ui.boardOpen, 'aria-controls': 'coverageBoard', title: ui.boardOpen ? 'Collapse the board' : 'Expand the board',
                dataset: { key: 'board-toggle' }, on: { click: () => { ui.boardOpen = !ui.boardOpen; ui.boardLane = null; render(); } } }, icon('chevron'),
            h('span', { class: 'visually-hidden' }, ui.boardOpen ? 'Collapse the coverage board' : 'Expand the coverage board'))),
        h('div', { class: 'board', id: 'coverageBoard', hidden: !ui.boardOpen }, lanes.map((lane) => boardLane(lane, agentAreaId))),
        h('p', { class: 'meta', hidden: !ui.boardOpen }, 'Reviewed means every required perspective finished its assigned files. It is not approval, and zero findings is not a pass.')));
    nodes.push(reviewFlowRow());
    nodes.push(reasonsRow());
    const map = changeMapRow();
    if (map) nodes.push(map);
    nodes.push(findingsRow());
    const area = view.areas.find((entry) => entry.id === ui.focus.areaId);
    if (!area) {
        nodes.push(h('p', { class: 'empty row' }, view.areas.length ? 'Select an area to see its summary, before and after, and files.' : 'The agent has not scheduled review work. Captured files are listed under Capture.'));
        nodes.push(discussionRow());
        return nodes;
    }
    const status = EXECUTION[area.status] ?? EXECUTION.pending;
    const target = about('area', area.id);
    nodes.push(row('row-area', area.title, 'nodes', [idChip(area.id, { kind: 'area' }), badge(status)],
        perspectiveChips(area.work),
        area.summary ? prose(area.summary) : h('p', { class: 'empty' }, 'The agent has not summarized this area yet.'),
        h('div', { class: 'btn-row' },
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `next-${area.id}` }, on: { click: () => prepare('review-next', target) } }, icon('flag'), 'Review next'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `explain-${area.id}` }, on: { click: () => prepare('explain', target) } }, icon('bulb'), 'Explain'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `investigate-${area.id}` }, on: { click: () => prepare('investigate', target) } }, icon('search'), 'Investigate'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `comment-${area.id}` }, on: { click: () => prepare('comment', target) } }, icon('message'), 'Comment')),
        h('div', { class: 'compare' },
            h('div', { class: 'compare-card' }, h('h4', {}, icon('clock'), 'Before'), prose(area.before || 'Not described yet.', 'prose small')),
            h('div', { class: 'compare-card' }, h('h4', {}, icon('arrow-right'), 'After'), prose(area.after || 'Not described yet.', 'prose small'))),
        workSummary(area)));
    const lens = ui.reason ? reasonFiles(view, ui.reason, currentCoverage()) : null;
    const files = view.files.filter((file) => (lens ?? area.fileIds).includes(file.id));
    const lensHead = lens ? [
        ui.reason === NOT_EXPLAINED ? badge({ label: 'Not explained yet', icon: 'question', tone: 'muted' }) : idChip(ui.reason, { kind: 'reason', title: `Files reason ${ui.reason} explains` }),
        h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: 'files-show-area' }, on: { click: () => selectReason(null) } }, icon('x'), 'Show area files'),
    ] : [];
    nodes.push(row('row-files', 'Files', 'diff', [count(files.length), ...lensHead],
        files.length ? h('ul', { class: 'file-list' }, files.map((file) => h('li', {}, fileRow(file)))) : h('p', { class: 'empty' }, 'No captured file matches.')));
    nodes.push(h('section', { class: 'row', id: 'row-diff', tabIndex: -1, 'aria-labelledby': 'row-diff-title' }, h('div', { id: 'diffHost' })));
    nodes.push(discussionRow());
    return nodes;
}

// Review flow

/** Who reviews the change and in what order: five steps on a rail, with Add for reviewers that are not running. */
function reviewFlowRow() {
    const flow = reviewFlow(view, ui.shownFindings);
    const running = flow.reviewers.filter((entry) => entry.scheduled).length;
    const suggested = flow.reviewers.filter((entry) => !entry.scheduled && entry.availability === 'suggested').length;
    const requested = flow.reviewers.filter((entry) => entry.request).length;
    const summary = [`${running} ${running === 1 ? 'reviewer' : 'reviewers'} running`, suggested ? `${suggested} suggested` : null, requested ? `${requested} requested` : null].filter(Boolean).join(', ');
    const words = ui.flowOpen ? 'Collapse the review flow' : 'Expand the review flow';
    return h('section', { class: `row flow-row${ui.flowOpen ? '' : ' is-folded'}`, id: 'row-flow', tabIndex: -1, 'aria-labelledby': 'row-flow-title' },
        h('div', { class: 'row-head' },
            h('div', { class: 'row-heading' }, h('h3', { class: 'row-title', id: 'row-flow-title' }, icon('flow'), 'Review flow'), meta(summary)),
            h('button', { type: 'button', class: 'btn btn-icon row-toggle', 'aria-expanded': ui.flowOpen, 'aria-controls': 'reviewFlow', title: words, dataset: { key: 'flow-toggle' },
                on: { click: () => { ui.flowOpen = !ui.flowOpen; render(); } } }, icon('chevron'), h('span', { class: 'visually-hidden' }, words))),
        h('div', { class: 'row-text', id: 'reviewFlow', hidden: !ui.flowOpen },
            h('p', { class: 'meta' }, 'Who reviews this change, in order. The reviewers in step 3 work side by side, and the agent checks every claim before it counts.'),
            h('ol', { class: 'flow' }, flow.steps.map((step, index) => flowStep(step, index + 1)))));
}

function flowStep(step, number) {
    const status = STAGE_STATUS[step.status];
    return h('li', { class: `flow-step tone-${status.tone}`, dataset: { step: step.id } },
        h('span', { class: 'flow-marker', 'aria-hidden': 'true' }, String(number)),
        h('div', { class: 'flow-body' },
            h('div', { class: 'flow-step-head' },
                h('h4', { class: 'flow-step-title' }, h('span', { class: 'visually-hidden' }, `Step ${number}: `), step.label),
                badge(status), h('span', { class: 'meta flow-summary' }, step.summary)),
            step.reviewers ? reviewerGroups(step.reviewers)
                : h('ul', { class: 'flow-agents' }, step.agents.map((agent) => h('li', { class: 'flow-agent' },
                    icon('sparkle'), h('span', { class: 'flow-agent-name' }, agent.label), meta(agent.role),
                    agent.status ? badge(REVIEWER_STATUS[agent.status]) : null)))));
}

const REQUEST_RANK = { queued: 0, drafted: 0, sent: 0, suggested: 1, available: 2, 'not-needed': 3 };

function reviewerGroups(reviewers) {
    const running = reviewers.filter((entry) => entry.scheduled);
    const available = reviewers.filter((entry) => !entry.scheduled).sort((left, right) => REQUEST_RANK[left.availability] - REQUEST_RANK[right.availability]);
    const group = (title, entries, card, extra = '') => entries.length
        ? h('div', { class: `flow-group${extra}` }, h('h5', { class: 'flow-group-title' }, title, count(entries.length)),
            h('ul', { class: 'reviewer-grid' }, entries.map((entry) => h('li', {}, card(entry)))))
        : null;
    return h('div', { class: 'flow-reviewers' },
        running.length ? null : h('p', { class: 'empty' }, 'The agent chooses reviewers after it groups the files. You can add one now.'),
        group('Core', running.filter((entry) => entry.group === 'core'), reviewerCard),
        group('Non-functional', running.filter((entry) => entry.group === 'non-functional'), reviewerCard),
        group('Add a reviewer', available, availableCard, ' flow-add'));
}

function reviewerCard(entry) {
    const status = REVIEWER_STATUS[entry.status];
    const added = entry.added === 'request' ? 'Added at your request' : entry.added === 'later' ? 'Added after the first plan' : null;
    const found = entry.findings ? `, ${entry.findings} ${entry.findings === 1 ? 'finding' : 'findings'}` : '';
    return h('article', { class: `reviewer-card tone-${status.tone}`, id: `reviewer-${entry.perspective}`, tabIndex: -1, title: entry.summary },
        h('div', { class: 'reviewer-head' }, h('h6', { class: 'reviewer-name' }, entry.label), badge(status)),
        h('p', { class: 'meta reviewer-agent' }, entry.agent),
        h('p', { class: 'reviewer-stats' }, `${entry.areas.done} of ${entry.areas.total} ${entry.areas.total === 1 ? 'area' : 'areas'} done${found}`),
        entry.reason ? h('p', { class: 'reviewer-why' }, entry.reason) : null,
        added ? h('p', { class: 'meta reviewer-added' }, icon('plus'), added) : null);
}

function availableCard(entry) {
    const state = AVAILABILITY[entry.availability];
    const request = entry.request;
    let action = null;
    if (!request) {
        action = h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `add-${entry.perspective}` }, 'aria-label': `Add the ${entry.label} reviewer`,
            on: { click: () => run(() => addReviewer(entry)) } }, icon('plus'), 'Add');
    } else if (request.status !== 'sent') {
        action = h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `request-dismiss-${entry.perspective}` }, 'aria-label': `Dismiss the request to add ${entry.label}`,
            on: { click: () => run(() => dismissItems([request.id], `The request to add ${entry.label} was dismissed. It will not be sent.`,
                { focus: () => document.querySelector(`#reviewer-${CSS.escape(entry.perspective)}`) })) } }, icon('x'), 'Dismiss');
    }
    return h('article', { class: `reviewer-card is-available is-${entry.availability} tone-${state.tone}`, id: `reviewer-${entry.perspective}`, tabIndex: -1 },
        h('div', { class: 'reviewer-head' }, h('h6', { class: 'reviewer-name' }, entry.label), entry.availability === 'available' ? null : badge(state)),
        h('p', { class: 'meta reviewer-agent' }, entry.summary),
        entry.reason ? h('p', { class: 'reviewer-why' }, entry.reason) : null,
        action ? h('div', { class: 'btn-row' }, action) : null);
}

/** Queues a request to add one reviewer; the agent collects it at its next checkpoint or when you send. */
async function addReviewer(entry) {
    const result = await api('/api/feedback', { action: 'request-reviewer', input: {
        revision: view.feedback.revision, perspective: entry.perspective, text: `Add the ${entry.label} reviewer to this review.`,
    } });
    const itemId = result.items.at(-1).id;
    await refresh();
    document.querySelector(`#reviewer-${CSS.escape(entry.perspective)}`)?.focus({ preventScroll: true });
    note(`${entry.label} is requested. Review and send delivers it now, or the agent collects it at its next checkpoint.`, 'accent', 'inbox',
        { label: 'Undo', run: () => run(() => dismissItems([itemId], `The request to add ${entry.label} was dismissed.`,
            { undo: false, focus: () => document.querySelector(`[data-key="add-${CSS.escape(entry.perspective)}"]`) })) });
}

/**
 * One area as a card: its ID with the Agent marker and, when its required work cannot finish, its
 * status words and a colored edge; its title; and its file and finding counts. A click selects it.
 *
 * @param {any} area
 * @param {string} key the card's `data-key`, distinct for the lane's card and its dropdown copy
 * @param {string | null} agentAreaId
 */
function boardCard(area, key, agentAreaId) {
    const status = EXECUTION[area.status] ?? EXECUTION.pending;
    const attention = needsAttention(area);
    const agent = area.id === agentAreaId;
    const findings = areaFindings(area).filter(isRetained);
    const work = area.work.map((item) => `${PERSPECTIVE[item.perspective] ?? item.perspective} ${(EXECUTION[item.status] ?? EXECUTION.pending).label.toLowerCase()}`).join(', ');
    const label = `${area.title}, ${status.label.toLowerCase()}${agent ? ', the agent is here' : ''}. ${work ? `${work}. ` : ''}${area.fileIds.length} ${area.fileIds.length === 1 ? 'file' : 'files'}${findings.length ? `, ${findings.length} ${findings.length === 1 ? 'finding' : 'findings'}` : ''}.`;
    return h('button', {
        type: 'button', class: `board-card${attention ? ' is-attention' : ''}${agent ? ' is-current' : ''}`, 'aria-current': ui.focus.areaId === area.id ? 'true' : null, 'aria-label': label,
        dataset: { key }, on: { click: () => select(about('area', area.id), { stage: 'review' }) },
    }, h('span', { class: 'board-card-head' }, idChip(area.id, { kind: 'area' }),
        agent ? badge({ label: 'Agent', icon: 'sparkle', tone: 'agent' }, { text: h('span', { class: 'board-flag-text' }, 'Agent') }) : null,
        attention ? badge(status, { text: h('span', { class: 'board-flag-text' }, status.label) }) : null),
    h('span', { class: 'board-card-title' }, area.title),
    h('span', { class: 'board-card-foot' }, h('span', {}, `${area.fileIds.length} ${area.fileIds.length === 1 ? 'file' : 'files'}`),
        findings.length ? h('span', {}, `${findings.length} ${findings.length === 1 ? 'finding' : 'findings'}`) : null));
}

/**
 * One lane: its header with the count and an alert for hidden cards that need attention, then its
 * one card. A lane with more cards heads with a disclosure button whose dropdown lists them all
 * over the page, so opening it never changes the board's height.
 */
function boardLane(lane, agentAreaId) {
    const many = lane.areas.length > 1;
    const open = many && ui.boardLane === lane.id;
    const dropId = `lane-drop-${lane.id}`;
    const flag = lane.hidden ? h('span', { class: 'lane-flag' }, icon('alert'), h('span', { class: 'visually-hidden' }, `, ${lane.hidden} more ${lane.hidden === 1 ? 'needs' : 'need'} attention`)) : null;
    const label = [icon(lane.icon), h('span', { class: 'lane-label' }, lane.title), count(lane.areas.length), flag];
    const head = many
        ? h('button', { type: 'button', class: 'board-lane-toggle', 'aria-expanded': open, 'aria-controls': dropId, dataset: { key: `board-lane-${lane.id}` }, on: { click: () => toggleLane(lane.id) } },
            ...label, icon('chevron', 'icon chev'))
        : h('span', { class: 'board-lane-label' }, ...label);
    return h('section', { class: `board-col tone-${lane.tone}${open ? ' is-open' : ''}`, 'aria-labelledby': `lane-${lane.id}`, dataset: { lane: lane.id } },
        h('div', { class: 'board-lane-head' },
            h('h4', { class: 'board-col-title', id: `lane-${lane.id}` }, head),
            many ? h('div', { class: 'board-drop', id: dropId, hidden: !open },
                h('ul', { class: 'board-list', 'aria-label': `${lane.title}: ${lane.areas.length} areas` }, lane.areas.map((area) => h('li', {}, boardCard(area, `board-drop-${area.id}`, agentAreaId))))) : null),
        lane.card ? h('div', { class: 'board-lane-card' }, boardCard(lane.card, `card-${lane.card.id}`, agentAreaId)) : h('p', { class: 'empty' }, 'None'));
}

/** Opens a lane's dropdown, closing any other, or closes it when it is open. */
function toggleLane(id) {
    ui.boardLane = ui.boardLane === id ? null : id;
    render();
}

/** Closes the open lane's dropdown, returning focus to its button when asked. */
function closeLane(returnFocus) {
    const lane = ui.boardLane;
    if (!lane) return;
    ui.boardLane = null;
    render();
    if (returnFocus) document.querySelector(`[data-key="board-lane-${CSS.escape(lane)}"]`)?.focus({ preventScroll: true });
}

const laneSelector = (lane) => `[data-lane="${CSS.escape(lane)}"]`;

/** The recorded change map, or one drawn from the areas, laid out once per review revision. */
function currentMap() {
    const key = `${view.snapshotId}:${view.revision}`;
    if (mapCache.key !== key) {
        const model = mapModel(view);
        mapCache = { key, model, layout: model ? layoutMap(model) : null };
    }
    return mapCache;
}

/**
 * The parts to fill: the selected reason's, the parts holding changes no reason explains, or the selected
 * area's, meaning parts that hold its files or its own part on a map drawn from areas.
 */
function highlightedParts(model) {
    if (ui.reason === NOT_EXPLAINED) {
        const open = new Set(currentCoverage().unexplained.fileIds);
        return new Set(model.parts.filter((part) => part.fileIds.some((fileId) => open.has(fileId))).map((part) => part.id));
    }
    if (ui.reason) return new Set(model.parts.filter((part) => part.reasonIds.includes(ui.reason)).map((part) => part.id));
    const area = view.areas.find((entry) => entry.id === ui.focus?.areaId);
    if (!area) return new Set();
    return new Set(model.parts.filter((part) => part.id === `area:${area.id}` || part.fileIds.some((fileId) => area.fileIds.includes(fileId))).map((part) => part.id));
}

function changeMapRow() {
    const { model, layout } = currentMap();
    if (!model) return null;
    if (!MAP_VIEWS.includes(ui.mapView)) ui.mapView = 'changes';
    const views = h('fieldset', { class: 'segmented' }, h('legend', {}, 'View'),
        MAP_VIEWS.map((value) => h('label', {}, h('input', {
            type: 'radio', name: 'mapView', value, checked: ui.mapView === value, dataset: { key: `map-view-${value}` },
            on: { change: () => { ui.mapView = value; ui.mapPinned = null; render(); } },
        }), h('span', {}, MAP_VIEW_WORDS[value]))));
    return row('row-map', 'Change map', 'nodes', [model.source === 'areas' ? badge({ label: 'Drawn from areas', icon: 'info', tone: 'muted' }) : null],
        h('div', { class: 'map-controls' }, views),
        model.source === 'areas' ? h('p', { class: 'map-note' }, 'The agent has not drawn a change map, so each part here is a review area, joined by the impact links the areas record.') : null,
        renderMap(model, layout, {
            view: ui.mapView, idPrefix: 'review-map', highlight: highlightedParts(model), pinned: ui.mapPinned,
            preview: partPreview, onPin: (partId) => { ui.mapPinned = partId; },
            textOpen: ui.mapText, onTextToggle: (open) => { ui.mapText = open; },
            evidence: (link) => h('button', {
                type: 'button', class: 'id-chip', 'data-kind': link.anchor.field ? 'review' : 'file', title: 'Show the evidence for this link',
                dataset: { key: `map-evidence-${link.from}-${link.to}` }, on: { click: () => goToAnchor(link.anchor) },
            }, anchorLabel(view, link.anchor), icon('go-to')),
        }));
}

/** A part's preview: its change, before and after lines, line counts, files, reasons, and findings. */
function partPreview(partId) {
    const part = currentMap().model.parts.find((entry) => entry.id === partId);
    if (!part) return [];
    const files = view.files.filter((file) => part.fileIds.includes(file.id));
    const totals = files.reduce((sum, file) => { const stats = fileStats(file); return { add: sum.add + stats.additions, del: sum.del + stats.deletions }; }, { add: 0, del: 0 });
    const findings = view.findings.filter((finding) => isShown(finding) && finding.disposition !== 'rejected' && finding.anchors.some((anchor) => part.fileIds.includes(anchor.fileId)));
    return [
        h('h4', {}, part.label),
        h('p', { class: 'meta' }, part.change === 'unchanged' ? 'Unchanged. It shows because a changed part connects to it.' : tagWords(part)),
        h('dl', {},
            part.before ? [h('dt', {}, 'Before'), h('dd', {}, part.before)] : null,
            part.after ? [h('dt', {}, 'After'), h('dd', {}, part.after)] : null,
            files.length ? [h('dt', {}, 'Lines'), h('dd', {}, `+${totals.add} \u2212${totals.del} in ${files.length} ${files.length === 1 ? 'file' : 'files'}`)] : null,
            findings.length ? [h('dt', {}, 'Findings'), h('dd', {}, String(findings.length))] : null),
        files.length ? h('div', { class: 'chip-row' }, files.map((file) => h('button', {
            type: 'button', class: 'id-chip', 'data-kind': 'file', title: fileLabel(file),
            on: { click: () => { ui.mapPinned = null; select(about('file', file.id), { stage: 'review' }); } },
        }, splitPath(file.newPath ?? file.oldPath).name, icon('go-to')))) : null,
        part.reasonIds.length ? h('div', { class: 'chip-row' }, part.reasonIds.map((reasonId) => {
            const reason = (view.reasons ?? []).find((entry) => entry.id === reasonId);
            return h('button', {
                type: 'button', class: 'id-chip', 'data-kind': 'reason', 'aria-pressed': ui.reason === reasonId, title: reason ? `${reasonId}: ${reason.title}` : reasonId,
                on: { click: () => { closePreviewTo(partId); selectReason(ui.reason === reasonId ? null : reasonId); } },
            }, reasonId);
        })) : null,
    ];
}

/** Unpins the map's preview and returns focus to its part, whose key survives the next render. */
function closePreviewTo(partId) {
    ui.mapPinned = null;
    [...document.querySelectorAll('#row-map [data-part]')].find((element) => element.getAttribute('data-part') === partId)?.focus({ preventScroll: true });
}

function workSummary(area) {
    const notes = area.work.filter((item) => item.summary || item.observations?.length || item.coverage?.notApplicable);
    if (!notes.length) return null;
    return h('details', {}, h('summary', {}, `Review work notes (${notes.length})`), h('ul', { class: 'steer-list' }, notes.map((item) => h('li', { class: 'omission' },
        badge(EXECUTION[item.status] ?? EXECUTION.pending, { text: PERSPECTIVE[item.perspective] ?? item.perspective }),
        h('div', {}, item.summary ? prose(item.summary, 'prose small') : null, item.coverage?.notApplicable ? meta(`Not applicable: ${item.coverage.notApplicable}`) : null,
            ...(item.observations ?? []).map((text) => meta(text)))))));
}

/**
 * "Why these changes": the agent's reasons as toggle buttons, one selected at a time, with All first
 * and "Not explained yet" last. Unselected reasons show their why on one line; the selected one shows
 * it whole with Explain and Comment.
 */
function reasonsRow() {
    const reasons = view.reasons ?? [];
    const reading = badge({ label: "The agent's reading", icon: 'sparkle', tone: 'muted' });
    if (!reasons.length) {
        return row('row-reasons', 'Why these changes', 'bulb', [reading],
            h('p', { class: 'empty' }, 'The agent has not recorded why these changes were made. Ask it to explain an area or a file.'));
    }
    const coverage = currentCoverage();
    const fileWords = (fileIds) => {
        const split = fileIds.filter((fileId) => (coverage.byFile[fileId] ?? []).length > 1).length;
        return `${fileIds.length} ${fileIds.length === 1 ? 'file' : 'files'}${split ? `, ${split} in part` : ''}`;
    };
    // A file without hunks counts by file only, so a zero hunk count says nothing and is left out.
    const hunkWords = (total) => (total ? `${total} ${total === 1 ? 'hunk' : 'hunks'}` : null);
    const reasonHunks = (reasonId) => coverage.reasons.find((entry) => entry.id === reasonId)?.hunks ?? 0;
    const findingWords = (reasonId) => {
        const total = findingsFor(view, { reasonId }).filter((finding) => isShown(finding) && isRetained(finding)).length;
        return total ? `${total} ${total === 1 ? 'finding' : 'findings'}` : null;
    };
    const option = ({ id, chip = null, title, counts, why = null, actions = null }) => {
        const pressed = ui.reason === id;
        const key = id ?? 'all';
        return h('li', { class: `reason-item${pressed ? ' is-selected' : ''}` },
            h('button', {
                type: 'button', class: 'reason', 'aria-pressed': pressed, 'aria-describedby': why ? `why-${key}` : null, dataset: { key: `reason-${key}` },
                on: { click: () => selectReason(pressed ? null : id) },
            }, chip, h('span', { class: 'reason-title' }, title), h('span', { class: 'reason-counts' }, counts.filter(Boolean).join(' \u00b7 '))),
            why ? h('p', { class: 'reason-why', id: `why-${key}` }, why) : null,
            pressed ? actions : null);
    };
    const items = [
        option({
            id: null, title: 'All changes',
            counts: [`${view.files.length} ${view.files.length === 1 ? 'file' : 'files'}`, hunkWords(view.files.reduce((total, file) => total + file.hunks.length, 0))],
        }),
        ...reasons.map((reason) => option({
            id: reason.id, chip: idChip(reason.id, { kind: 'reason' }), title: reason.title, why: reason.why,
            counts: [fileWords(reasonFiles(view, reason.id, coverage)), hunkWords(reasonHunks(reason.id)), findingWords(reason.id)],
            actions: h('div', { class: 'btn-row' },
                h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `reason-explain-${reason.id}` }, on: { click: () => prepare('explain', about('reason', reason.id)) } }, icon('bulb'), 'Explain'),
                h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `reason-comment-${reason.id}` }, on: { click: () => prepare('comment', about('reason', reason.id)) } }, icon('message'), 'Comment')),
        })),
    ];
    if (coverage.unexplained.fileIds.length) {
        items.push(option({
            id: NOT_EXPLAINED, title: 'Not explained yet', counts: [fileWords(coverage.unexplained.fileIds), hunkWords(coverage.unexplained.hunks), findingWords(NOT_EXPLAINED)],
            why: 'No reason covers these changes. Review them directly, or ask the agent to explain them.',
        }));
    }
    return row('row-reasons', 'Why these changes', 'bulb', [reading],
        h('p', { class: 'meta' }, 'The agent grouped the changes by purpose. Each reason is its reading of the change, not the author\'s words. Select one to narrow the files and the map.'),
        h('ul', { class: 'reason-list', 'aria-label': 'Reasons' }, items));
}

/** A decorative bar of a file's share per reason; the row's name carries the same words. */
function reasonBar(segments) {
    const bar = h('span', { class: 'reason-bar', 'aria-hidden': 'true' });
    for (const segment of segments) {
        const part = h('span', { class: `reason-bar-part${segment.reasonId ? '' : ' is-open'}` });
        part.style.flexGrow = String(Math.max(segment.hunks, 1));
        bar.append(part);
    }
    return bar;
}

function fileRow(file) {
    const stats = fileStats(file);
    const { dir, name } = splitPath(file.newPath ?? file.oldPath);
    const notes = fileAnnotations(view, file, ui.shownFindings);
    const segments = (view.reasons ?? []).length ? currentCoverage().byFile[file.id] ?? [] : [];
    const order = (view.reasons ?? []).map((reason) => reason.id);
    const reasonIds = segments.map((segment) => segment.reasonId).filter(Boolean).sort((left, right) => order.indexOf(left) - order.indexOf(right));
    const open = segments.some((segment) => !segment.reasonId);
    const why = !segments.length ? '' : reasonIds.length ? `, explained by ${reasonIds.join(' and ')}${open ? ', part not explained yet' : ''}` : ', not explained yet';
    const label = `${fileLabel(file)}, ${fileStatus(file).label.toLowerCase()}, ${stats.additions} lines added, ${stats.deletions} removed${why}${notes.findings.length ? `, ${notes.findings.length} ${notes.findings.length === 1 ? 'finding' : 'findings'}` : ''}${notes.comments.length ? `, ${notes.comments.length} ${notes.comments.length === 1 ? 'comment' : 'comments'}` : ''}`;
    return h('button', {
        type: 'button', class: 'file-row', 'aria-current': ui.focus.fileId === file.id ? 'true' : null, title: fileLabel(file), 'aria-label': label,
        dataset: { key: `file-${file.id}` }, on: { click: () => select(about('file', file.id), { stage: 'review' }) },
    }, fileLetter(file), h('span', { class: 'file-path' }, file.status === 'R' ? h('span', { class: 'dir' }, `${file.oldPath} → `) : null, h('span', { class: 'dir' }, dir), h('span', { class: 'name' }, name)),
    segments.length ? h('span', { class: 'file-reasons' }, reasonIds.map((reasonId) => idChip(reasonId, { kind: 'reason' })),
        open ? h('span', { class: 'file-reason-open' }, reasonIds.length ? '+ not explained' : 'Not explained yet') : null,
        segments.length > 1 ? reasonBar(segments) : null) : null,
    h('span', { class: 'file-row-stats' },
        notes.findings.length ? badge({ label: String(notes.findings.length), icon: 'alert', tone: 'danger' }) : null,
        notes.comments.length ? badge({ label: String(notes.comments.length), icon: 'message', tone: 'user' }) : null,
        h('span', { class: 'stat-add', 'aria-label': `${stats.additions} added` }, `+${stats.additions}`),
        h('span', { class: 'stat-delete', 'aria-label': `${stats.deletions} removed` }, `−${stats.deletions}`)));
}

async function renderDiff() {
    const host = $('diffHost');
    if (!host) return;
    const file = view.files.find((entry) => entry.id === ui.focus.fileId);
    const heading = h('h3', { class: 'visually-hidden', id: 'row-diff-title' }, file ? `Diff of ${fileLabel(file)}` : 'Diff');
    if (!file) {
        host.replaceChildren(heading, h('p', { class: 'empty' }, ui.focus.commentId ? 'This comment has no anchor in the captured revision. Its original context stays in the discussion.' : 'Select a file to see its captured diff.'));
        return;
    }
    const stats = fileStats(file);
    const head = h('div', { class: 'diff-file-head' }, fileLetter(file), h('span', { class: 'file-path' }, fileLabel(file)),
        h('span', { class: 'stat-add' }, `+${stats.additions}`), h('span', { class: 'stat-delete' }, `−${stats.deletions}`),
        h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `comment-file-${file.id}` }, on: { click: () => prepare('comment', about('file', file.id)) } }, icon('message'), 'Comment'));
    const bodyHost = h('div', { class: 'diff-file-body' });
    host.replaceChildren(heading, h('div', { class: 'diff-file' }, head, bodyHost));
    if (file.omission) {
        bodyHost.append(h('div', { class: 'notice tone-attention' }, h('p', { class: 'notice-title' }, icon('info'), 'No text preview'), prose(file.omission, 'prose small')));
        return;
    }
    const cacheKey = `${view.snapshotId}:${file.id}`;
    let data = evidence.get(cacheKey);
    if (!data) {
        bodyHost.append(h('p', { class: 'empty' }, 'Loading captured lines…'));
        try {
            data = await api(`/api/evidence?file=${encodeURIComponent(file.id)}&snapshot=${encodeURIComponent(view.snapshotId)}`);
            evidence.set(cacheKey, data);
        } catch (error) {
            bodyHost.replaceChildren(h('p', { class: 'field-error' }, icon('alert'), `The captured lines could not load: ${error.message}`));
            return;
        }
        if (!$('diffHost')?.contains(bodyHost)) return;
    }
    bodyHost.replaceChildren(...hunkBlocks(file, data));
    if (ui.focus.hunkId && ui.stage === 'review') {
        const block = document.querySelector(`#hunk-${CSS.escape(ui.focus.hunkId)}`);
        if (block && ui.target?.kind === 'hunk' && !block.dataset.shown) {
            block.dataset.shown = 'true';
            block.scrollIntoView({ block: 'start' });
        }
    }
}

function hunkBlocks(file, data) {
    if (data.omission) return [h('div', { class: 'notice tone-attention' }, h('p', { class: 'notice-title' }, icon('info'), 'No text preview'), prose(data.omission, 'prose small'))];
    if (!data.lines.length) return [h('p', { class: 'empty' }, 'This change has no text lines, for example a rename or mode change.')];
    const byHunk = new Map();
    for (const line of data.lines) {
        if (!byHunk.has(line.hunkId)) byHunk.set(line.hunkId, []);
        byHunk.get(line.hunkId).push(line);
    }
    return file.hunks.filter((hunk) => byHunk.has(hunk.id)).map((hunk) => {
        const notes = hunkAnnotations(view, file, hunk, ui.shownFindings);
        const anchored = new Set();
        for (const finding of notes.findings) {
            for (const anchor of finding.anchors.filter((entry) => entry.hunkId === hunk.id && entry.startLine !== null)) {
                for (let lineNo = anchor.startLine; lineNo <= (anchor.endLine ?? anchor.startLine); lineNo += 1) anchored.add(`${anchor.side}:${lineNo}`);
            }
        }
        const rows = byHunk.get(hunk.id).map((line) => h('tr', { class: `${line.kind}${anchored.has(`new:${line.newLine}`) || anchored.has(`old:${line.oldLine}`) ? ' is-anchored' : ''}` },
            h('td', { class: 'ln' }, line.oldLine ?? ''), h('td', { class: 'ln' }, line.newLine ?? ''),
            h('td', { class: 'mark' }, line.kind === 'add' ? '+' : line.kind === 'delete' ? '−' : ' ', h('span', { class: 'visually-hidden' }, line.kind === 'add' ? 'added' : line.kind === 'delete' ? 'removed' : '')),
            h('td', { class: 'code' }, h('code', {}, line.text))));
        const table = h('table', { class: 'diff-table' },
            h('caption', { class: 'visually-hidden' }, `${fileLabel(file)}, lines ${hunk.newStart} to ${hunk.newStart + Math.max(hunk.newCount - 1, 0)}`),
            h('thead', {}, h('tr', {}, ['Before', 'After', 'Change', 'Captured text'].map((label) => h('th', { scope: 'col' }, label)))),
            h('tbody', {}, rows));
        const hasNotes = notes.findings.length + notes.comments.length > 0;
        return h('div', { class: `hunk${hasNotes ? ' has-notes' : ''}${ui.focus.hunkId === hunk.id ? ' is-selected' : ''}`, id: `hunk-${hunk.id}`, tabIndex: -1 },
            h('div', { class: 'hunk-code' }, h('div', { class: 'hunk-head' }, h('span', {}, `@@ -${hunk.oldStart},${hunk.oldCount} +${hunk.newStart},${hunk.newCount} @@`), hunkReason(hunk)), table),
            hasNotes ? h('div', { class: 'hunk-notes', 'aria-label': 'Findings and comments on these lines' },
                ...notes.findings.map((finding) => h('div', { class: 'note-card' },
                    h('div', { class: 'note-head' }, badge(SEVERITY[finding.severity], { strong: true }), badge(DISPOSITION[finding.disposition] ?? DISPOSITION.proposed)),
                    h('p', { class: 'note-title' }, finding.claim),
                    h('div', {}, h('button', { type: 'button', class: 'id-chip', 'data-kind': 'finding', dataset: { key: `note-finding-${finding.id}` }, title: 'Open this finding',
                        on: { click: () => select(about('finding', finding.id), { stage: 'review', flash: true }) } }, finding.id, icon('go-to'))))),
                ...notes.comments.map((comment) => h('div', { class: 'note-card is-comment' },
                    h('div', { class: 'note-head' }, h('span', { class: 'comment-author' }, icon('person'), comment.author), resolutionBadge(comment)),
                    prose(comment.body, 'prose small'),
                    h('div', {}, h('button', { type: 'button', class: 'id-chip', 'data-kind': 'comment', dataset: { key: `note-comment-${comment.id}` }, title: 'Open this comment',
                        on: { click: () => select(about('comment', comment.id), { stage: 'review', flash: true }) } }, comment.id, icon('go-to')))))) : null);
    });
}

/** The reason that explains a hunk, as a chip that selects it, or "Not explained yet". */
function hunkReason(hunk) {
    if (!(view.reasons ?? []).length) return null;
    const reasonId = currentCoverage().byHunk[hunk.id];
    if (!reasonId) return h('span', { class: 'hunk-reason-open' }, 'Not explained yet');
    const reason = view.reasons.find((entry) => entry.id === reasonId);
    return h('button', {
        type: 'button', class: 'id-chip', 'data-kind': 'reason', title: `Why: ${reason?.title ?? reasonId}`, 'aria-label': `Reason ${reasonId}: ${reason?.title ?? ''}. Show this reason.`,
        dataset: { key: `hunk-reason-${hunk.id}` }, on: { click: () => selectReason(reasonId) },
    }, reasonId);
}

function findingChip(finding) {
    return h('button', { type: 'button', class: 'id-chip', 'data-kind': 'finding', title: finding.claim, dataset: { key: `chip-finding-${finding.id}` },
        on: { click: () => select(about('finding', finding.id), { stage: 'review', flash: true }) } }, finding.id, icon('go-to'));
}

function resolutionBadge(comment) {
    const meta = { resolved: { label: 'Resolved', icon: 'check-circle', tone: 'success' }, unresolved: { label: 'Unresolved', icon: 'circle', tone: 'attention' },
        unknown: { label: 'Resolution unknown', icon: 'question', tone: 'muted' } };
    return badge(meta[comment.resolution] ?? meta.unknown);
}

/** A row whose title is a disclosure that shows or hides its body, as RPI's secondary rows fold. */
function foldedRow(id, title, iconName, open, onToggle, headExtras, ...content) {
    const section = row(id, title, iconName, headExtras, ...content);
    const body = section.querySelector('.row-text');
    body.id = `${id}-body`;
    body.hidden = !open;
    section.classList.toggle('is-folded', !open);
    section.querySelector('.row-title').replaceChildren(h('button', {
        type: 'button', class: 'row-toggle', 'aria-expanded': open, 'aria-controls': body.id, dataset: { key: `row-toggle-${id}` }, on: { click: onToggle },
    }, icon('chevron', 'icon chev'), icon(iconName), h('span', {}, title)));
    return section;
}

/** Findings narrowed by the reason lens and, when chosen, the selected area. */
function scopedFindings() {
    return findingsFor(view, { reasonId: ui.reason, areaId: ui.findingArea ? ui.focus?.areaId ?? null : null });
}

/**
 * Findings: severity counts and a progress line, then severity groups of one-line rows that expand
 * in place, one at a time. Findings that arrive after the page loaded wait behind "Show N new
 * findings" so nothing moves until the reader asks.
 */
function findingsRow() {
    const scoped = scopedFindings();
    const visible = scoped.filter((finding) => ui.shownFindings.has(finding.id));
    const held = arrivals(view.findings, ui.shownFindings);
    const retained = visible.filter(isRetained);
    const checking = visible.filter((finding) => finding.disposition === 'proposed').length;
    const setAside = visible.length - retained.length;
    const counts = Object.keys(SEVERITY).map((severity) => [severity, retained.filter((finding) => finding.severity === severity).length]).filter(([, value]) => value);
    const progress = perspectiveProgress(view);
    const area = view.areas.find((entry) => entry.id === ui.focus?.areaId) ?? null;
    if (!area) ui.findingArea = false;
    const scope = area ? h('fieldset', { class: 'segmented compact' }, h('legend', {}, 'Show'),
        [['all', 'All areas'], ['area', area.title]].map(([value, label]) => h('label', {}, h('input', {
            type: 'radio', name: 'findingScope', value, checked: (ui.findingArea ? 'area' : 'all') === value, dataset: { key: `finding-scope-${value}` },
            on: { change: () => { ui.findingArea = value === 'area'; render(); } },
        }), h('span', {}, label)))) : null;
    const lens = ui.reason ? (ui.reason === NOT_EXPLAINED ? badge({ label: 'Not explained yet', icon: 'question', tone: 'muted' }) : idChip(ui.reason, { kind: 'reason', title: `Findings on changes reason ${ui.reason} explains` })) : null;
    const show = held.count ? h('button', {
        type: 'button', class: 'btn btn-compact arrivals', dataset: { key: 'show-arrivals' },
        on: { click: () => showArrivals(held.ids) },
    }, icon('plus'), `Show ${held.count} new ${held.count === 1 ? 'finding' : 'findings'}${held.summary ? ` (${held.summary})` : ''}`) : null;
    const groups = findingGroups(visible);
    const empty = view.findings.length
        ? (scoped.length ? 'Every finding here is new; show them above.' : 'No findings match this narrowing.')
        : 'No findings are recorded. Check coverage and evidence limits before drawing a conclusion.';
    return row('row-findings', 'Findings', 'shield-check', [count(retained.length), lens],
        h('ul', { class: 'finding-summary', 'aria-label': 'Findings by severity' },
            counts.map(([severity, value]) => h('li', {}, badge(SEVERITY[severity], { strong: true }), h('span', { class: 'count-text' }, String(value)))),
            checking ? h('li', {}, badge(DISPOSITION.proposed), h('span', { class: 'count-text' }, String(checking))) : null,
            setAside ? h('li', { class: 'meta' }, `${setAside} set aside`) : null),
        progress.length ? h('p', { class: 'finding-progress' }, h('span', {}, 'Areas checked: '), progress.map((entry, index) => [
            index ? ' \u00b7 ' : null, h('strong', {}, PERSPECTIVE[entry.perspective] ?? entry.perspective), ` ${entry.done} of ${entry.total}`,
            entry.attention ? `, ${entry.attention} ${entry.attention === 1 ? 'needs' : 'need'} attention` : entry.active ? `, ${entry.active} running` : null,
        ])) : null,
        scope || show ? h('div', { class: 'finding-tools' }, scope, show) : null,
        groups.length ? h('div', { class: 'finding-groups' }, groups.map(findingGroup)) : h('p', { class: 'empty' }, empty));
}

function findingGroup(group) {
    const holdsExpanded = group.findings.some((finding) => finding.id === ui.expandedFinding);
    const open = ui.groupOpen.get(group.id) ?? (group.open || holdsExpanded);
    const label = group.severity ? badge(SEVERITY[group.severity], { strong: true }) : badge({ label: 'Set aside', icon: 'slash-circle', tone: 'muted' });
    return h('section', { class: 'finding-group', 'aria-labelledby': `group-${group.id}-title` },
        h('h4', { class: 'finding-group-title', id: `group-${group.id}-title` }, h('button', {
            type: 'button', class: 'finding-group-toggle', 'aria-expanded': open, 'aria-controls': `group-${group.id}`, dataset: { key: `group-${group.id}` },
            on: { click: () => { ui.groupOpen.set(group.id, !open); render(); } },
        }, icon('chevron', 'icon chev'), label, count(group.findings.length, `${group.findings.length} ${group.findings.length === 1 ? 'finding' : 'findings'}`))),
        h('ul', { class: 'finding-rows', id: `group-${group.id}`, hidden: !open }, group.findings.map(findingRow)));
}

/** A finding as one line that expands in place into its full card; opening one closes the other. */
function findingRow(finding) {
    const expanded = ui.expandedFinding === finding.id;
    const disposition = DISPOSITION[finding.disposition] ?? DISPOSITION.proposed;
    return h('li', { class: `finding-row${expanded ? ' is-expanded' : ''}` },
        h('button', {
            type: 'button', class: 'finding-row-head', 'aria-expanded': expanded, 'aria-controls': expanded ? `finding-${finding.id}` : null, dataset: { key: `finding-row-${finding.id}` },
            on: { click: () => { ui.expandedFinding = expanded ? null : finding.id; render(); } },
        }, icon('chevron', 'icon chev'), idChip(finding.id, { kind: 'finding' }), h('span', { class: 'finding-row-claim' }, plainText(finding.claim)),
        ui.newlyShown.has(finding.id) ? badge({ label: 'New', icon: 'sparkle', tone: 'accent' }) : null,
        finding.disposition === 'accepted' ? null : badge(disposition)),
        expanded ? findingCard(finding) : null);
}

/**
 * Shows held findings in place, opening their groups, and moves focus to the first of them. A reason
 * lens or area scope that would hide any of them is cleared, and the announcement says so.
 */
function showArrivals(ids) {
    const hidden = clearHidingNarrowing(ids);
    for (const id of ids) {
        ui.shownFindings.add(id);
        ui.newlyShown.add(id);
        const finding = view.findings.find((entry) => entry.id === id);
        const group = finding ? findingGroups([finding])[0] : null;
        if (group) ui.groupOpen.set(group.id, true);
    }
    render();
    const first = ids.map((id) => document.querySelector(`[data-key="finding-row-${CSS.escape(id)}"]`)).find(Boolean);
    first?.focus({ preventScroll: true });
    first?.scrollIntoView({ block: 'nearest' });
    const widened = [hidden.reason ? 'reasons' : null, hidden.area ? 'areas' : null].filter(Boolean).join(' and ');
    announce(`Showing ${ids.length} new ${ids.length === 1 ? 'finding' : 'findings'}.${widened ? ` The list now covers all ${widened}.` : ''}`);
}

/** The pull request discussion, folded at the end of Review; inline comments also show in the diff. */
function discussionRow() {
    const discussion = view.discussion;
    const statusMeta = { complete: { label: 'Imported', icon: 'check-circle', tone: 'success' }, partial: { label: 'Partly imported', icon: 'half', tone: 'attention' },
        unavailable: { label: 'Unavailable', icon: 'slash-circle', tone: 'muted' }, not_applicable: { label: 'Not applicable', icon: 'dash-circle', tone: 'muted' } };
    const roots = discussion.items.filter((comment) => !comment.replyTo || !discussion.items.some((entry) => entry.id === comment.replyTo));
    const thread = (comment) => h('li', {}, commentCard(comment), (() => {
        const replies = discussion.items.filter((entry) => entry.replyTo === comment.id);
        return replies.length ? h('ul', { class: 'replies' }, replies.map(thread)) : null;
    })());
    return foldedRow('row-discussion', 'Pull request discussion', 'message', ui.discussionOpen, () => { ui.discussionOpen = !ui.discussionOpen; render(); },
        [badge(statusMeta[discussion.status] ?? statusMeta.unavailable), count(discussion.items.length)],
        discussion.limitations.length ? h('div', { class: 'notice tone-attention' }, h('p', { class: 'notice-title' }, icon('info'), 'Import limits'), h('ul', {}, discussion.limitations.map((text) => h('li', {}, text)))) : null,
        roots.length ? h('ul', { class: 'thread-list' }, roots.map(thread)) : h('p', { class: 'empty' }, discussion.status === 'not_applicable' ? 'This target has no provider discussion.' : 'No discussion was imported.'));
}

function findingCard(finding) {
    const target = about('finding', finding.id);
    const seen = isMarked(view.feedback, 'seen', target);
    const bookmarked = isMarked(view.feedback, 'bookmarks', target);
    const perspectives = [...new Set((finding.sources ?? []).map((source) => perspectiveOf(view, source)).filter(Boolean))];
    return h('article', { class: 'finding', id: `finding-${finding.id}`, tabIndex: -1, 'aria-current': ui.focus.findingId === finding.id ? 'true' : null, 'aria-labelledby': `finding-${finding.id}-title` },
        h('div', { class: 'finding-head' },
            badge(SEVERITY[finding.severity], { strong: true }), idChip(finding.id, { kind: 'finding' }), badge(DISPOSITION[finding.disposition] ?? DISPOSITION.proposed),
            ...perspectives.map((entry) => badge({ label: PERSPECTIVE[entry] ?? entry, icon: 'eye', tone: 'muted' })),
            seen ? badge({ label: 'Seen', icon: 'check', tone: 'muted' }) : null,
            h('span', { class: 'finding-actions' },
                h('button', { type: 'button', class: 'btn btn-icon', 'aria-pressed': bookmarked, title: bookmarked ? 'Remove bookmark' : 'Bookmark', dataset: { key: `bookmark-${finding.id}` },
                    on: { click: () => run(() => mark('bookmark', target, !bookmarked)) } }, icon(bookmarked ? 'bookmark-fill' : 'bookmark'), h('span', { class: 'visually-hidden' }, 'Bookmark')),
                h('button', { type: 'button', class: 'btn btn-icon', 'aria-pressed': seen, title: seen ? 'Mark as not seen' : 'Mark as seen', dataset: { key: `seen-${finding.id}` },
                    on: { click: () => run(() => mark('seen', target, !seen)) } }, icon('eye'), h('span', { class: 'visually-hidden' }, 'Seen')))),
        h('h4', { class: 'finding-title', id: `finding-${finding.id}-title` }, finding.claim),
        h('dl', { class: 'finding-facts' },
            h('dt', {}, 'Consequence'), h('dd', {}, prose(finding.consequence)),
            h('dt', {}, 'Suggested change'), h('dd', {}, prose(finding.remediation)),
            finding.criterion ? [h('dt', {}, 'Criterion'), h('dd', {}, prose(finding.criterion))] : null,
            h('dt', {}, 'Evidence'), h('dd', {}, h('div', { class: 'chip-row' }, finding.anchors.map((anchor, index) => h('button', {
                type: 'button', class: 'id-chip', 'data-kind': anchor.field ? 'review' : 'file', title: 'Show this evidence', dataset: { key: `anchor-${finding.id}-${index}` },
                on: { click: () => goToAnchor(anchor) } }, anchorLabel(view, anchor), icon('go-to'))))),
            finding.snippet ? [h('dt', {}, 'Snippet'), h('dd', {}, h('pre', { class: 'report-well' }, h('code', {}, finding.snippet)))] : null,
            finding.disposition !== 'proposed' && finding.reason ? [h('dt', {}, 'Agent decision'), h('dd', {}, prose(finding.reason))] : null),
        h('div', { class: 'btn-row' },
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `explain-${finding.id}` }, on: { click: () => prepare('explain', target) } }, icon('bulb'), 'Explain'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `investigate-${finding.id}` }, on: { click: () => prepare('investigate', target) } }, icon('search'), 'Investigate'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `dispute-${finding.id}` }, on: { click: () => prepare('dispute', target) } }, icon('half'), 'Dispute'),
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `draft-${finding.id}` }, on: { click: () => prepare('draft', target) } }, icon('pencil'), 'Draft a comment')));
}

function commentCard(comment) {
    const target = about('comment', comment.id);
    const focus = resolveFocus(view, target);
    const place = (path, line, commit, side = null) => `${path}${line ? `:${line}` : ''}${side ? ` (${side === 'new' ? 'after' : 'before'})` : ''}${commit ? ` at ${shortSha(commit)}` : ''}`;
    const current = comment.path ? place(comment.path, comment.line, comment.commit, comment.side) : null;
    const originalPath = comment.originalPath ?? comment.path;
    const moved = comment.originalLine !== null && comment.originalLine !== undefined
        && (comment.originalLine !== comment.line || (comment.originalCommit ?? null) !== (comment.commit ?? null) || originalPath !== comment.path);
    const where = [current, moved ? `Originally ${place(originalPath ?? '', comment.originalLine, comment.originalCommit)}` : null, comment.replyTo ? `Reply to ${comment.replyTo}` : null].filter(Boolean).join('. ');
    return h('article', { class: 'comment', id: `comment-${comment.id}`, tabIndex: -1, 'aria-current': ui.focus.commentId === comment.id ? 'true' : null, 'aria-labelledby': `comment-${comment.id}-title` },
        h('div', { class: 'comment-head' },
            h('h4', { class: 'comment-author', id: `comment-${comment.id}-title` }, icon('person'), comment.author),
            badge({ label: comment.kind === 'inline' ? 'Inline' : 'Conversation', icon: comment.kind === 'inline' ? 'code' : 'message', tone: 'user' }),
            resolutionBadge(comment), comment.outdated ? badge({ label: 'Outdated', icon: 'clock', tone: 'muted' }) : null, idChip(comment.id, { kind: 'comment' })),
        prose(comment.body),
        where ? h('p', { class: 'meta' }, where) : null,
        h('div', { class: 'btn-row' },
            focus.mapped && focus.fileId ? h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `show-comment-${comment.id}` },
                on: { click: () => select(about('hunk', focus.hunkId), { stage: 'review' }) } }, icon('code'), 'Show in diff') : null,
            h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `reply-${comment.id}` }, on: { click: () => prepare('draft', target) } }, icon('pencil'), 'Draft a reply'),
            comment.kind === 'inline' && !(focus.mapped && focus.fileId) ? meta('Not mapped to the captured revision.') : null));
}

function outcomeView() {
    const key = view.outcome && !view.stale ? view.outcome : 'none';
    const outcome = OUTCOME[key] ?? OUTCOME.none;
    const reasons = [];
    for (const item of (view.workItems ?? []).filter((entry) => entry.required && ['blocked', 'unavailable', 'skipped', 'stale'].includes(entry.status))) {
        const area = view.areas.find((entry) => item.areaIds.includes(entry.id));
        reasons.push(`${PERSPECTIVE[item.perspective] ?? item.perspective} review of ${area?.title ?? item.areaIds.join(', ')} is ${EXECUTION[item.status].label.toLowerCase()}.`);
    }
    for (const limit of view.limitations.filter((entry) => entry.blocking)) reasons.push(limit.summary);
    const pendingWork = (view.workItems ?? []).filter((entry) => entry.required && ['pending', 'in_progress'].includes(entry.status)).length;
    const proposed = view.findings.filter((finding) => finding.disposition === 'proposed').length;
    const retained = view.findings.filter((finding) => isRetained(finding) && finding.disposition !== 'proposed');
    let explanation;
    if (key !== 'none') explanation = 'The agent\'s recommendation for the completed review. Reviewed coverage is not human approval: the report\'s human-review checkbox stays yours.';
    else if (view.stale) explanation = 'The review record cannot be read right now, so no outcome is shown.';
    else if (view.status === 'incomplete') explanation = 'The review is incomplete, so it has no outcome.';
    else explanation = `The outcome appears once every required area is reviewed and every finding is verified. ${pendingWork} required ${pendingWork === 1 ? 'task is' : 'tasks are'} still open and ${proposed} ${proposed === 1 ? 'finding awaits' : 'findings await'} verification.`;
    const severityCounts = Object.keys(SEVERITY).map((level) => [level, retained.filter((finding) => finding.severity === level).length]).filter(([, value]) => value);
    return [
        row('row-outcome', 'Outcome', 'flag', [],
            h('div', { class: `outcome-card tone-${outcome.tone}` },
                h('p', { class: 'outcome-verdict' }, icon(outcome.icon), outcome.label),
                prose(explanation, 'prose small'),
                reasons.length ? h('ul', { class: 'steer-list' }, reasons.map((text) => h('li', { class: 'omission' }, icon('alert'), prose(text, 'prose small')))) : null,
                severityCounts.length ? h('div', { class: 'chip-row' }, meta('Retained findings'), severityCounts.map(([level, value]) => badge(SEVERITY[level], { strong: true, text: `${value} ${level}` }))) : null)),
        row('row-report', 'Report', 'file', [],
            view.artifacts?.report ? h('p', { class: 'meta' }, 'Saved as ', h('code', {}, view.artifacts.report), ' in the review folder. It is yours to edit; this view is read-only.') : h('p', { class: 'empty' }, 'No report has been saved yet.'),
            view.artifacts?.report ? h('div', { class: 'btn-row' }, h('button', { type: 'button', class: 'btn', dataset: { key: 'read-report' }, on: { click: () => run(readReport) } }, icon('file'), ui.reportText === null ? 'Read the saved report' : 'Reload the report')) : null,
            ui.reportText !== null ? h('pre', { class: 'report-well', tabIndex: 0, 'aria-label': 'Saved review report, read-only' }, ui.reportText) : null),
        row('row-publication', 'Publishing', 'send', [],
            prose('This canvas never posts comments, submits reviews, resolves threads, approves, or merges. Before staging or posting, the agent shows what it would send, checks the target again, and asks you.', 'prose small')),
    ];
}

async function readReport() {
    const report = await api('/api/report');
    ui.reportText = report.text;
    render();
    document.querySelector('.report-well')?.focus();
    announce('Saved report loaded, read-only.');
}

// Steering panel

function renderSteer() {
    const needs = needsYou(view);
    const needsSection = $('needsSection');
    needsSection.classList.toggle('has-items', needs.length > 0);
    needsSection.replaceChildren(
        h('h3', { class: 'steer-title', id: 'needsTitle' }, icon('hand'), 'Needs you', count(needs.length)),
        needs.length ? h('ul', { class: 'steer-list' }, needs.map((item) => {
            const severity = SEVERITY[item.severity];
            return h('li', {}, h('button', { type: 'button', class: `steer-link tone-${severity.tone}`, dataset: { key: `needs-${item.id}` },
                on: { click: () => { select(about('finding', item.id), { stage: 'review', flash: true }); closeDrawer(false); } } },
            icon(severity.icon), h('span', { class: 'steer-link-text' }, `${severity.label}: ${plainText(item.label)}`)));
        })) : h('p', { class: 'empty' }, 'Nothing needs you. High and Critical findings wait here until you mark them seen.'));

    const active = view.feedback.items.filter((item) => item.status !== 'dismissed');
    const groups = [
        ['Not sent', active.filter((item) => item.status === 'queued')],
        ['Drafts', active.filter((item) => item.status === 'draft')],
        ['Sent', active.filter((item) => item.status === 'sent')],
        ['Read back', active.filter((item) => item.status === 'interpreted')],
    ].filter(([, items]) => items.length);
    $('feedbackSection').replaceChildren(
        h('h3', { class: 'steer-title', id: 'feedbackTitle', tabIndex: -1 }, icon('inbox'), 'Your feedback', count(active.length)),
        ...(groups.length ? groups.map(([title, items]) => h('div', { class: 'feedback-group' }, h('h4', { class: 'feedback-group-title' }, title),
            h('ul', { class: 'feedback-list' }, items.map((item) => h('li', {}, feedbackItem(item))))))
            : [h('p', { class: 'empty' }, 'Questions, disputes, and comment drafts you add stay here until you send them. Bookmarks and seen marks stay private to you.')]));
    renderComposerTarget();
}

function targetLabel(target) {
    if (target.kind === 'review') return 'Whole review';
    if (target.kind === 'finding') return target.id;
    if (target.kind === 'perspective') return `${PERSPECTIVE[target.id] ?? target.id} reviewer`;
    if (target.kind === 'file' || target.kind === 'hunk') {
        const file = target.kind === 'file' ? view.files.find((entry) => entry.id === target.id) : view.files.find((entry) => entry.hunks.some((hunk) => hunk.id === target.id));
        return file ? `${splitPath(file.newPath ?? file.oldPath).name}${target.kind === 'hunk' ? ' (lines)' : ''}` : target.id;
    }
    if (target.kind === 'area') return view.areas.find((entry) => entry.id === target.id)?.title ?? target.id;
    if (target.kind === 'reason') return `Reason ${target.id}`;
    return target.id;
}

function targetChip(target) {
    const older = target.snapshotId !== view.snapshotId;
    const gone = !older && !targetPresent(view, target);
    const kind = { finding: 'finding', comment: 'comment', area: 'area', reason: 'reason', file: 'file', hunk: 'file', review: 'review', perspective: 'review' }[target.kind];
    if (older || gone || target.kind === 'review') {
        return idChip(older ? `${targetLabel(target)} (earlier snapshot)` : gone ? `${targetLabel(target)} (no longer in this review)` : targetLabel(target), { kind });
    }
    return h('button', { type: 'button', class: 'id-chip', 'data-kind': kind, title: 'Show this item', on: { click: () => select(target, { stage: stageFor() }) } }, targetLabel(target), icon('go-to'));
}

const DISMISSED_WORDS = {
    draft: 'Draft dismissed. Nothing was sent.',
    queued: 'Removed. It will not be sent.',
    interpreted: 'Read-back cleared from your feedback.',
};

function feedbackItem(item) {
    const state = feedbackState(item);
    const key = (action) => ({ key: `${action}-${item.id}` });
    const dismiss = h('button', { type: 'button', class: 'btn btn-compact', dataset: key('dismiss'), 'aria-label': `Dismiss this ${FEEDBACK_KIND[item.kind]?.toLowerCase() ?? 'feedback'}`,
        on: { click: () => run(() => dismissItems([item.id], DISMISSED_WORDS[item.status])) } }, icon('x'), 'Dismiss');
    let actions = [];
    if (item.status === 'draft') actions = [h('button', { type: 'button', class: 'btn btn-compact', dataset: key('edit'), on: { click: () => editDraft(item) } }, icon('pencil'), 'Edit'), dismiss];
    else if (item.status === 'queued') actions = [h('button', { type: 'button', class: 'btn btn-compact', dataset: key('edit'), on: { click: () => run(() => editQueued(item)) } }, icon('pencil'), 'Edit'), dismiss];
    else if (item.status === 'interpreted') actions = [dismiss];
    return h('article', { class: 'feedback-item' },
        h('div', { class: 'chip-row' }, badge(state), meta(FEEDBACK_KIND[item.kind] ?? item.kind), targetChip(item.target)),
        h('p', { class: 'feedback-item-text' }, item.text || '(empty draft)'),
        item.delivery?.status === 'failed' ? h('p', { class: 'field-error' }, icon('alert'), `${item.delivery.error ?? 'Delivery failed.'} The agent can still collect it.`) : null,
        item.interpretation ? h('div', { class: 'readback' }, h('p', { class: 'meta' }, icon('sparkle'), ' The agent understood'), prose(item.interpretation.text, 'prose small'),
            meta(`${item.interpretation.effect}${item.interpretation.applied ? '' : ' (not applied yet)'}`)) : null,
        item.status === 'sent' ? h('p', { class: 'meta' }, 'The agent has this one. It stays until the agent reads it back.') : null,
        actions.length ? h('div', { class: 'btn-row' }, actions) : null);
}

/** Dismisses feedback the agent does not have yet, with Undo in the status note. Focus lands on `focus()`, since the dismissed item's controls are gone. */
async function dismissItems(ids, words, { undo = true, focus = () => $('feedbackTitle') } = {}) {
    await api('/api/feedback', { action: 'dismiss', input: { revision: view.feedback.revision, ids } });
    if (ids.includes(ui.composer.id)) resetComposer();
    await refresh();
    focus()?.focus({ preventScroll: true });
    if (undo) note(words, 'accent', 'x', { label: 'Undo', run: () => run(() => restoreItems(ids)) });
    else announce(words);
}

async function restoreItems(ids) {
    await api('/api/feedback', { action: 'restore', input: { revision: view.feedback.revision, ids } });
    await refresh();
    const restored = view.feedback.items.filter((item) => ids.includes(item.id));
    const request = restored.find((item) => item.kind === 'add-reviewer');
    const target = (request ? document.querySelector(`#reviewer-${CSS.escape(request.target.id)}`) : null)
        ?? document.querySelector(`[data-key="dismiss-${CSS.escape(ids[0])}"]`) ?? $('feedbackTitle');
    target?.focus({ preventScroll: true });
    const drafted = restored.some((item) => item.status === 'draft');
    announce(drafted ? 'Restored as a draft. Edit it before you queue it again.' : 'Restored.');
}

/** Takes an unsent item back to a draft and opens it in the composer. */
async function editQueued(item) {
    if (composerDirty() && $('feedbackText').value.trim()) {
        composerError('Save, queue, or dismiss your current words before opening another item.');
        $('feedbackText').focus();
        return;
    }
    await api('/api/feedback', { action: 'unqueue', input: { revision: view.feedback.revision, ids: [item.id] } });
    await refresh();
    const draft = view.feedback.items.find((entry) => entry.id === item.id);
    if (draft) editDraft(draft);
    announce('Taken back to a draft. Queue it again when it is ready.');
}

function renderComposerTarget() {
    if (!ui.composer.target || (ui.composer.target.snapshotId !== view.snapshotId && !ui.composer.id)) ui.composer.target = about('review', view.reviewId);
    $('composeTarget').replaceChildren(targetChip(ui.composer.target));
    $('composeReset').hidden = ui.composer.target.kind === 'review';
    const reviewer = ui.composer.target.kind === 'perspective';
    const option = $('feedbackKind').querySelector('option[value="add-reviewer"]');
    option.hidden = !reviewer;
    option.disabled = !reviewer;
    if (!reviewer && $('feedbackKind').value === 'add-reviewer') $('feedbackKind').value = 'comment';
}

function composerDirty() {
    return $('feedbackText').value !== ui.composer.saved;
}

function composerError(message) {
    const error = $('composeError');
    error.hidden = !message;
    error.replaceChildren(...(message ? [icon('alert'), message] : []));
    $('feedbackText').setAttribute('aria-invalid', message ? 'true' : 'false');
    if (message) $('feedbackText').setAttribute('aria-describedby', 'composeError composeHelp');
    else $('feedbackText').setAttribute('aria-describedby', 'composeHelp');
    if (message) announce(message, { urgent: true });
}

function prepare(kind, target) {
    if (composerDirty() && $('feedbackText').value.trim()) {
        composerError('Save, queue, or dismiss your current words before starting another item. Your text is still here.');
        openSteer();
        $('feedbackText').focus();
        return;
    }
    composerError('');
    ui.composer = { id: null, target, saved: '' };
    $('feedbackText').value = '';
    $('feedbackKind').value = kind;
    renderComposerTarget();
    openSteer();
    $('feedbackText').focus();
    announce(`Adding ${FEEDBACK_KIND[kind]?.toLowerCase() ?? kind} about ${targetLabel(target)}.`);
}

function editDraft(item) {
    if (composerDirty() && $('feedbackText').value.trim()) {
        composerError('Save, queue, or dismiss your current words before opening another draft.');
        $('feedbackText').focus();
        return;
    }
    composerError('');
    ui.composer = { id: item.id, target: item.target, saved: item.text };
    $('feedbackKind').value = item.kind;
    $('feedbackText').value = item.text;
    renderComposerTarget();
    $('feedbackText').focus();
}

async function saveDraft(queue) {
    const text = $('feedbackText').value;
    if (!text.trim()) {
        composerError('Write something before saving or queueing.');
        $('feedbackText').focus();
        return;
    }
    composerError('');
    const result = await api('/api/feedback', { action: 'save', input: {
        revision: view.feedback.revision, kind: $('feedbackKind').value, target: ui.composer.target, text, ...(ui.composer.id ? { id: ui.composer.id } : {}),
    } });
    const id = ui.composer.id ?? result.items.at(-1).id;
    if (queue) {
        await api('/api/feedback', { action: 'queue', input: { revision: result.revision, ids: [id] } });
        resetComposer();
    } else ui.composer = { ...ui.composer, id, saved: text };
    await refresh();
    announce(queue ? 'Queued for the agent. Use Review and send to deliver it.' : 'Draft saved. It stays private until you queue it.');
}

/** Empties the composer and points it back at the whole review. */
function resetComposer() {
    ui.composer = { id: null, target: about('review', view.reviewId), saved: '' };
    $('feedbackText').value = '';
    $('feedbackKind').value = 'comment';
    composerError('');
    renderComposerTarget();
}

/**
 * Throws away what the composer holds. Unsaved words come back with Undo; an open saved draft is
 * dismissed, and Undo restores it with the words you had typed.
 */
async function dismissComposer() {
    const held = { id: ui.composer.id, target: ui.composer.target, saved: ui.composer.saved, kind: $('feedbackKind').value, text: $('feedbackText').value };
    if (!held.id && !held.text.trim()) {
        resetComposer();
        announce('Nothing to dismiss. The input is empty.');
        return;
    }
    const putBack = () => {
        if (composerDirty() && $('feedbackText').value.trim()) {
            composerError('Save, queue, or dismiss your current words before you undo.');
            return;
        }
        ui.composer = { id: held.id, target: held.target, saved: held.saved };
        $('feedbackKind').value = held.kind;
        $('feedbackText').value = held.text;
        renderComposerTarget();
        $('feedbackText').focus();
    };
    resetComposer();
    if (held.id) {
        await api('/api/feedback', { action: 'dismiss', input: { revision: view.feedback.revision, ids: [held.id] } });
        await refresh();
        note('Draft dismissed. Nothing was sent.', 'accent', 'x', { label: 'Undo', run: () => run(async () => { await restoreItems([held.id]); putBack(); }) });
    } else note('Your words were dismissed. Nothing was sent.', 'accent', 'x', { label: 'Undo', run: putBack });
    $('feedbackText').focus();
}

async function mark(kind, target, value) {
    await api('/api/feedback', { action: 'mark', input: { revision: view.feedback.revision, target, kind, value } });
    await refresh();
    announce(kind === 'bookmark' ? (value ? 'Bookmarked.' : 'Bookmark removed.') : (value ? 'Marked as seen.' : 'Marked as not seen.'));
}

// Review and send

async function openSend() {
    await refresh();
    renderSendList();
    $('sendError').hidden = true;
    $('sendSheet').showModal();
    $('sendTitle').focus();
}

/** Lists queued items in Review and send, each with Dismiss, and tracks the revision being sent. */
function renderSendList() {
    sendRevision = view.feedback.revision;
    const queued = view.feedback.items.filter((item) => item.status === 'queued');
    $('sendList').replaceChildren(...(queued.length ? queued.map((item) => h('article', { class: 'feedback-item' },
        h('div', { class: 'chip-row' }, badge(feedbackState(item)), meta(FEEDBACK_KIND[item.kind] ?? item.kind), idChip(targetLabel(item.target)),
            item.target.snapshotId !== view.snapshotId ? badge({ label: 'Earlier snapshot', icon: 'clock', tone: 'attention' }) : null),
        h('p', { class: 'feedback-item-text' }, item.text),
        h('div', { class: 'btn-row' }, h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `send-dismiss-${item.id}` }, 'aria-label': `Dismiss this ${FEEDBACK_KIND[item.kind]?.toLowerCase() ?? 'item'}`,
            on: { click: () => run(async () => {
                await dismissItems([item.id], DISMISSED_WORDS.queued, { focus: () => $('sendTitle') });
                renderSendList();
                ($('sendList').querySelector('button') ?? $('sendTitle')).focus();
            }) } }, icon('x'), 'Dismiss')))) : [h('p', { class: 'empty' }, 'Nothing is queued. Save an item and choose Queue for the agent first.')]));
    $('sendNow').disabled = queued.length === 0;
}

async function sendNow() {
    $('sendNow').disabled = true;
    try {
        const sent = view.feedback.items.filter((item) => item.status === 'queued').length;
        await api('/api/feedback', { action: 'send', input: { revision: sendRevision } });
        $('sendSheet').close();
        await refresh();
        announce(`Sent ${sent} ${sent === 1 ? 'item' : 'items'} to the agent. They stay pending until the agent reads them back.`);
    } catch (error) {
        $('sendError').hidden = false;
        $('sendError').replaceChildren(icon('alert'), `${error.message} Close and reopen to see the current queue.`);
        $('sendNow').disabled = false;
        $('sendNow').focus();
        announce(`Not sent. ${error.message}`, { urgent: true });
        await run(refresh);
    }
}

// Panels, appearance, and shortcuts

const navDocked = () => window.matchMedia('(min-width: 720px)').matches;
const steerDocked = () => window.matchMedia('(min-width: 1360px)').matches;

function applyPanels() {
    const workspace = $('workspace');
    const nav = navDocked();
    const steer = steerDocked();
    workspace.classList.toggle('nav-docked', nav);
    workspace.classList.toggle('steer-docked', steer);
    const navShown = nav ? !ui.navHidden : ui.drawer === 'nav';
    const steerShown = steer ? !ui.steerHidden : ui.drawer === 'steer';
    workspace.classList.toggle('nav-hidden', !navShown);
    workspace.classList.toggle('steer-hidden', !steerShown);
    $('navToggle').setAttribute('aria-expanded', String(navShown));
    $('navToggle').querySelector('.visually-hidden').textContent = navShown ? 'Hide navigator' : 'Show navigator';
    $('steerToggle').setAttribute('aria-expanded', String(steerShown));
    $('steerToggle').querySelector('.visually-hidden').textContent = steerShown ? 'Hide steering panel' : 'Show steering panel';
    $('navClose').hidden = nav;
    $('steerClose').hidden = steer;
    const drawer = ui.drawer && !(ui.drawer === 'nav' ? nav : steer);
    $('scrim').hidden = !drawer;
    for (const [element, name] of [[$('document'), null], [$('navigator'), 'nav'], [$('steer'), 'steer'], [document.querySelector('.topbar'), null]]) {
        element.inert = Boolean(drawer) && ui.drawer !== name;
    }
}

function toggleNav() {
    if (navDocked()) ui.navHidden = !ui.navHidden;
    else ui.drawer = ui.drawer === 'nav' ? null : 'nav';
    applyPanels();
    if (ui.drawer === 'nav') $('navFilter').focus();
}

function toggleSteer() {
    if (steerDocked()) ui.steerHidden = !ui.steerHidden;
    else ui.drawer = ui.drawer === 'steer' ? null : 'steer';
    applyPanels();
    if (ui.drawer === 'steer') $('steerTitle').setAttribute('tabindex', '-1'), $('steerTitle').focus();
}

function openSteer() {
    if (steerDocked()) ui.steerHidden = false;
    else ui.drawer = 'steer';
    applyPanels();
}

function closeDrawer(returnFocus = true) {
    if (!ui.drawer) return;
    const which = ui.drawer;
    ui.drawer = null;
    applyPanels();
    if (returnFocus) $(which === 'nav' ? 'navToggle' : 'steerToggle').focus();
}

function applyPreferences(preferences) {
    const root = document.documentElement;
    root.dataset.theme = preferences.theme;
    root.dataset.contrast = preferences.contrast;
    for (const input of document.querySelectorAll('input[name="theme"]')) input.checked = input.value === preferences.theme;
    $('contrastSwitch').checked = preferences.contrast === 'more';
    $('appearanceNote').textContent = preferences.theme === 'system' ? 'System follows your editor or operating system.' : `${preferences.theme === 'light' ? 'Light' : 'Dark'} overrides your editor theme for this canvas.`;
    $('appearanceBtn').querySelector('use').setAttribute('href', preferences.theme === 'light' ? '#i-sun' : preferences.theme === 'dark' ? '#i-moon' : '#i-contrast');
    $('appearanceBtn').querySelector('.visually-hidden').textContent = `Appearance: ${preferences.theme}${preferences.contrast === 'more' ? ', more contrast' : ''}`;
}

async function savePreferences(patch) {
    const root = document.documentElement;
    const next = { theme: root.dataset.theme, contrast: root.dataset.contrast, ...patch };
    applyPreferences(next);
    try {
        await api('/api/preferences', patch);
        announce(`Appearance set to ${next.theme}${next.contrast === 'more' ? ' with more contrast' : ''}.`);
    } catch (error) {
        reportFailure(`Appearance not saved: ${error.message}`);
    }
}

function toggleAppearance(open) {
    const menu = $('appearanceMenu');
    const show = open ?? menu.hidden;
    menu.hidden = !show;
    $('appearanceBtn').setAttribute('aria-expanded', String(show));
    if (show) menu.querySelector('input[name="theme"]:checked')?.focus();
}

function detectHostScheme() {
    const root = document.documentElement;
    const raw = getComputedStyle(root).getPropertyValue('--background-color-default').trim();
    if (!raw) {
        delete root.dataset.hostScheme;
        return;
    }
    const probe = document.createElement('canvas').getContext('2d');
    probe.fillStyle = '#000001';
    const sentinel = String(probe.fillStyle);
    probe.fillStyle = raw;
    const parsed = String(probe.fillStyle);
    const channels = parsed.startsWith('#') ? [1, 3, 5].map((index) => Number.parseInt(parsed.slice(index, index + 2), 16)) : (parsed.match(/[\d.]+/g) ?? []).slice(0, 3).map(Number);
    if (channels.length !== 3 || (parsed === sentinel && raw.toLowerCase() !== '#000001')) {
        delete root.dataset.hostScheme;
        return;
    }
    const [r, g, b] = channels.map((value) => {
        const c = value / 255;
        return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    root.dataset.hostScheme = 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.179 ? 'dark' : 'light';
}

const SHORTCUTS = [
    ['1 to 3', 'View Capture, Review, or Outcome'], ['n', 'Go to the next item that needs you'], ['[ and ]', 'Previous and next file in the area'],
    ['/', 'Filter the navigator'], ['b', 'Show or hide the navigator'], ['s', 'Show or hide the steering panel'], ['?', 'Show this list'],
    ['Escape', 'Close a menu, drawer, or dialog'], ['Arrow keys', 'Move between stages in the rail'],
];

function openShortcuts() {
    $('shortcutList').replaceChildren(...SHORTCUTS.flatMap(([keys, action]) => [h('dt', {}, h('kbd', {}, keys)), h('dd', {}, action)]));
    $('shortcutsDialog').showModal();
}

function nextNeeds() {
    const needs = needsYou(view);
    if (!needs.length) {
        announce('Nothing needs you right now.');
        return;
    }
    ui.needsIndex = (ui.needsIndex + 1) % needs.length;
    const item = needs[ui.needsIndex];
    select(about(item.kind, item.id), { stage: item.stage, flash: true });
}

function stepFile(delta) {
    const area = view.areas.find((entry) => entry.id === ui.focus.areaId);
    const files = area ? area.fileIds : view.files.map((file) => file.id);
    if (!files.length) return;
    const index = files.indexOf(ui.focus.fileId);
    const next = files[(index + delta + files.length) % files.length];
    select(about('file', next), { stage: 'review', moveFocus: false });
    announce(`Showing ${fileLabel(view.files.find((file) => file.id === next))}.`);
}

function onKey(event) {
    if (event.key === 'Escape') {
        if (event.isComposing || event.keyCode === 229) return;
        // Some embedded hosts deliver Escape without the browser's dialog close request.
        const dialog = document.querySelector('dialog[open]');
        if (dialog) {
            dialog.close();
            event.preventDefault();
        } else if (closeMapPreview()) {
            event.preventDefault();
        } else if (!$('appearanceMenu').hidden) {
            toggleAppearance(false);
            $('appearanceBtn').focus();
            event.preventDefault();
        } else if (ui.boardLane) {
            const active = document.activeElement;
            closeLane(!active || active === document.body || Boolean(active.closest('[data-lane]')));
            event.preventDefault();
        } else if (ui.drawer) {
            closeDrawer();
            event.preventDefault();
        }
        return;
    }
    if (event.ctrlKey || event.metaKey || event.altKey || event.isComposing || !ui.shortcuts || !view) return;
    const field = event.target.closest?.('input, textarea, select, [contenteditable="true"]');
    if (field || document.querySelector('dialog[open]')) return;
    const key = event.key;
    if (/^[1-3]$/.test(key)) setStage(STAGE_KEYS[Number(key) - 1]);
    else if (key === 'n') nextNeeds();
    else if (key === '/') {
        if (!navDocked()) ui.drawer = 'nav';
        else ui.navHidden = false;
        applyPanels();
        $('navFilter').focus();
    } else if (key === 'b') toggleNav();
    else if (key === 's') toggleSteer();
    else if (key === '?') openShortcuts();
    else if (key === '[') stepFile(-1);
    else if (key === ']') stepFile(1);
    else return;
    event.preventDefault();
}

// Data

/**
 * Loads the current review. A call made while a load is in flight waits for one more load, so a
 * caller that awaits it always sees data at least as new as its call; concurrent callers share it.
 */
function refresh() {
    if (!loading) {
        loading = load().finally(() => { loading = null; });
        return loading;
    }
    if (!reloading) {
        const again = () => { reloading = null; return refresh(); };
        reloading = loading.then(again, again);
    }
    return reloading;
}

async function load() {
    const previous = view;
    view = await api('/api/state');
    if (previous && previous.snapshotId !== view.snapshotId) {
        evidence.clear();
        ui.reportText = null;
        ui.reason = null;
        ui.mapPinned = null;
        ui.expandedFinding = null;
        ui.groupOpen.clear();
        ui.newlyShown.clear();
    }
    // The first load and a new snapshot show every finding; later arrivals wait for the reader.
    if (!previous || previous.snapshotId !== view.snapshotId) {
        ui.shownFindings = new Set(view.findings.map((finding) => finding.id));
        ui.heldIds = new Set();
    }
    const reasonIds = (view.reasons ?? []).map((reason) => reason.id);
    // A lens clears once nothing is left for it: a removed reason, or no unexplained changes.
    const lensEmpty = ui.reason === NOT_EXPLAINED ? !reasonIds.length || !currentCoverage().unexplained.fileIds.length : !reasonIds.includes(ui.reason);
    if (ui.reason && lensEmpty) ui.reason = null;
    const remote = view.focus ? `${view.focus.snapshotId}:${view.focusRevision ?? 0}` : '';
    let agentFocus = null;
    if (view.focus && remote !== ui.remoteFocus) {
        ui.remoteFocus = remote;
        if (previous || !ui.loaded) agentFocus = view.focus;
    }
    if (!ui.target || ui.target.snapshotId !== view.snapshotId) ui.target = about('review', view.reviewId);
    ui.focus = resolveFocus(view, ui.target);
    if (ui.target.kind === 'reason' && !ui.focus.mapped) {
        ui.target = about('review', view.reviewId);
        ui.focus = resolveFocus(view, ui.target);
    }
    // One refresh makes at most one announcement, so the focus note and other news are combined.
    const news = [];
    if (agentFocus && agentFocus.snapshotId === view.snapshotId) {
        if (ui.follow || !ui.loaded) select(agentFocus, { stage: stageFor(), moveFocus: false, flash: Boolean(previous) });
        else {
            render();
            const pointed = `The agent pointed to ${agentFocus.kind} ${agentFocus.id}.`;
            note(pointed, 'accent', 'sparkle', { label: 'Show', run: () => select(agentFocus, { stage: stageFor(), flash: true }) }, { quiet: true });
            news.push(pointed);
        }
    } else render();
    // Held findings are compared by ID after any agent focus reveal, so each arrival is news once.
    const held = arrivals(view.findings, ui.shownFindings, ui.heldIds);
    ui.heldIds = new Set(held.ids);
    if (previous) {
        if (previous.snapshotId !== view.snapshotId) news.push('A new snapshot loaded. Your feedback is kept; coverage belongs to the new snapshot.');
        else if (held.fresh.length) news.push(`${held.count} new ${held.count === 1 ? 'finding is' : 'findings are'} waiting in Findings${held.summary ? `, including ${held.summary}` : ''}.`);
        else if (view.feedback.items.some((item) => item.status === 'interpreted' && previous.feedback.items.find((entry) => entry.id === item.id)?.status !== 'interpreted')) news.push('The agent read back your feedback.');
        else if (!previous.stale && view.stale) news.push('The review record could not be read. The last valid evidence stays on screen.');
        else if (previous.revision !== view.revision && !news.length) news.push(`Review updated to revision ${view.revision}.`);
    }
    if (news.length) announce(news.join(' '));
    ui.loaded = true;
}

const live = new AbortController();
let following = true;

async function stream() {
    while (following) {
        try {
            const response = await fetch('/api/events', { headers: { 'X-Review-Token': token }, signal: live.signal });
            if (!response.ok || !response.body) throw new Error(`Live updates unavailable (${response.status}).`);
            ui.live = 'live';
            renderLive();
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let pending = '';
            try {
                for (;;) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    pending += decoder.decode(value, { stream: true });
                    if (pending.includes('\n\n')) {
                        pending = pending.slice(pending.lastIndexOf('\n\n') + 2);
                        await run(refresh);
                    }
                }
            } finally {
                await reader.cancel().catch(() => {});
            }
        } catch (error) {
            if (!following) return;
        }
        if (!following) return;
        if (ui.live !== 'reconnecting') announce('Live updates paused; reconnecting. The current view stays on screen.');
        ui.live = 'reconnecting';
        renderLive();
        await new Promise((resolve) => setTimeout(resolve, 3000));
    }
}

function wire() {
    $('navToggle').addEventListener('click', toggleNav);
    $('steerToggle').addEventListener('click', toggleSteer);
    $('navClose').addEventListener('click', () => closeDrawer());
    $('steerClose').addEventListener('click', () => closeDrawer());
    $('scrim').addEventListener('click', () => closeDrawer());
    $('needsBtn').addEventListener('click', () => run(nextNeeds));
    $('sendBtn').addEventListener('click', () => run(openSend));
    $('sendNow').addEventListener('click', () => run(sendNow));
    $('liveBtn').addEventListener('click', () => {
        ui.follow = !ui.follow;
        renderLive();
        announce(ui.follow ? 'Following the agent.' : 'Stopped following the agent. Updates continue.');
    });
    $('appearanceBtn').addEventListener('click', () => toggleAppearance());
    for (const input of document.querySelectorAll('input[name="theme"]')) input.addEventListener('change', () => savePreferences({ theme: input.value }));
    $('contrastSwitch').addEventListener('change', (event) => savePreferences({ contrast: event.target.checked ? 'more' : 'standard' }));
    document.addEventListener('click', (event) => {
        if (!$('appearanceMenu').hidden && !event.target.closest('#appearanceMenu, #appearanceBtn')) toggleAppearance(false);
        if (ui.boardLane && event.target.isConnected && !event.target.closest(laneSelector(ui.boardLane))) closeLane(false);
    });
    // Focus leaving the open lane closes it once focus has landed.
    document.addEventListener('focusout', (event) => {
        const lane = ui.boardLane;
        if (!lane || !event.target.closest?.(laneSelector(lane))) return;
        const next = event.relatedTarget;
        if (!(next instanceof Element) || next.closest(laneSelector(lane))) return;
        window.setTimeout(() => {
            if (ui.boardLane !== lane || document.activeElement?.closest?.(laneSelector(lane))) return;
            closeLane(false);
        }, 0);
    });
    $('shortcutsBtn').addEventListener('click', openShortcuts);
    $('shortcutSwitch').addEventListener('change', (event) => {
        ui.shortcuts = event.target.checked;
        for (const element of document.querySelectorAll('[aria-keyshortcuts]')) {
            if (!ui.shortcuts) element.dataset.shortcut = element.getAttribute('aria-keyshortcuts');
            if (ui.shortcuts && element.dataset.shortcut) element.setAttribute('aria-keyshortcuts', element.dataset.shortcut);
            else element.removeAttribute('aria-keyshortcuts');
        }
    });
    for (const dialog of document.querySelectorAll('dialog')) {
        const opener = { element: null };
        dialog.addEventListener('close', () => opener.element?.focus());
        new MutationObserver(() => { if (dialog.open) opener.element = document.activeElement; }).observe(dialog, { attributes: true, attributeFilter: ['open'] });
        for (const close of dialog.querySelectorAll('[data-close]')) close.addEventListener('click', () => dialog.close());
    }
    $('navFilter').addEventListener('input', (event) => {
        ui.filter = event.target.value;
        renderNav();
    });
    $('saveDraft').addEventListener('click', () => run(() => saveDraft(false)));
    $('queueDraft').addEventListener('click', () => run(() => saveDraft(true)));
    $('dismissDraft').addEventListener('click', () => run(dismissComposer));
    $('composeReset').addEventListener('click', () => {
        composerError('');
        ui.composer = { ...ui.composer, target: about('review', view.reviewId) };
        renderComposerTarget();
        announce('Now about the whole review. Save to keep the change.');
    });
    $('feedbackText').addEventListener('input', () => composerError(''));
    document.addEventListener('keydown', onKey);
    window.matchMedia('(min-width: 720px)').addEventListener('change', () => { ui.drawer = null; applyPanels(); });
    window.matchMedia('(min-width: 1360px)').addEventListener('change', () => { ui.drawer = null; applyPanels(); });
    window.addEventListener('resize', () => {
        const docked = { nav: navDocked(), steer: steerDocked() };
        if (ui.drawer && docked[ui.drawer]) ui.drawer = null;
        applyPanels();
    });
    window.addEventListener('pagehide', () => {
        following = false;
        live.abort();
    });
}

detectHostScheme();
applyPreferences({ theme: document.documentElement.dataset.theme, contrast: document.documentElement.dataset.contrast });
wire();
applyPanels();
await run(refresh);
void stream();
