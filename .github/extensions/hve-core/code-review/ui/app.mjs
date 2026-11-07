// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { badge, count, h, icon, idChip, meta, prose, shortSha, svg, time } from './dom.mjs';
import {
    anchorLabel, coverageBoard, DISPOSITION, defaultFindingFilter, EXECUTION, FEEDBACK_KIND, feedbackState, fileAnnotations,
    fileLabel, fileStats, fileStatus, FINDING_FILTERS, filterShowing, findingFilter, hunkAnnotations, impactLayout, isMarked, isRetained, matches, needsYou,
    OUTCOME, PERSPECTIVE, perspectiveOf, plainText, resolveFocus, SEVERITY, splitPath, STAGE_STATUS, stageFor, stages, targetSummary,
} from './views.mjs';

const $ = (id) => document.getElementById(id);
const token = document.querySelector('meta[name="review-token"]').content;
const STAGE_KEYS = ['capture', 'review', 'verify', 'outcome'];
const ui = {
    stage: 'review', target: null, focus: null, filter: '', findingFilter: null, follow: true, live: 'connecting',
    navHidden: false, steerHidden: false, drawer: null, boardOpen: true, shortcuts: true, reportText: null,
    remoteFocus: '', needsIndex: -1, composer: { id: null, target: null, saved: '' }, loaded: false,
};
let view = null;
const evidence = new Map();
let refreshing = false;
let refreshAgain = false;
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

function note(message, tone, iconName, action = null) {
    const area = $('statusArea');
    const element = h('div', { class: `notice status-note tone-${tone}` }, icon(iconName), h('p', { class: 'status-note-text' }, message));
    if (action) element.append(h('button', { type: 'button', class: 'btn btn-compact', on: { click: () => { element.remove(); syncStatus(); action.run(); } } }, action.label));
    element.append(h('button', { type: 'button', class: 'icon-btn', title: 'Dismiss', on: { click: () => { element.remove(); syncStatus(); } } },
        icon('x'), h('span', { class: 'visually-hidden' }, 'Dismiss')));
    area.append(element);
    while (area.children.length > 3) area.firstElementChild.remove();
    syncStatus();
    announce(message, { urgent: tone === 'danger' });
}

function syncStatus() {
    $('statusArea').hidden = $('statusArea').children.length === 0;
}

function run(action) {
    return Promise.resolve().then(action).catch((error) => reportFailure(error.message ?? String(error)));
}

// Selection

const about = (kind, id) => ({ kind, id, snapshotId: view.snapshotId });

function select(target, { stage = null, moveFocus = true, flash = false } = {}) {
    ui.target = target;
    ui.focus = resolveFocus(view, target);
    if (stage) ui.stage = stage;
    if (target.kind === 'finding') ui.findingFilter = filterShowing(view, ui.findingFilter ?? defaultFindingFilter(view), target.id);
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

function selectionElement() {
    const target = ui.target;
    if (!target) return null;
    const escape = (value) => CSS.escape(value);
    if (ui.stage === 'verify' && target.kind === 'finding') return document.querySelector(`#finding-${escape(target.id)}`);
    if (ui.stage === 'verify' && target.kind === 'comment') return document.querySelector(`#comment-${escape(target.id)}`);
    if (ui.stage === 'capture' && ui.focus.metadataField) return document.querySelector(`#meta-${escape(ui.focus.metadataField)}`);
    if (ui.stage !== 'review') return null;
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

function render({ keepScroll = true } = {}) {
    if (!view) return;
    const active = document.activeElement;
    const key = active?.dataset?.key;
    const inDocument = $('document').contains(active) || $('navBody').contains(active) || $('steer').contains(active);
    const scroll = { doc: $('document').scrollTop, nav: $('navigator').scrollTop };
    renderHeader();
    renderNav();
    renderContext();
    renderDocument();
    renderSteer();
    if (keepScroll) {
        $('document').scrollTop = scroll.doc;
        $('navigator').scrollTop = scroll.nav;
    }
    if (key) {
        const restore = [...document.querySelectorAll('[data-key]')].find((element) => element.dataset.key === key);
        if (restore && restore !== document.activeElement) restore.focus({ preventScroll: true });
        else if (!restore && inDocument && !document.activeElement?.closest('#steer .compose')) $('viewTitle')?.focus({ preventScroll: true });
    }
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
    } else if (ui.stage === 'verify') {
        const findings = [...view.findings].sort((a, b) => (SEVERITY[a.severity]?.rank ?? 9) - (SEVERITY[b.severity]?.rank ?? 9))
            .filter((finding) => matches(filter, finding.claim, finding.id, finding.severity));
        sections.push(h('h2', { class: 'nav-title' }, 'Findings', count(view.findings.length)));
        sections.push(h('ul', { class: 'nav-list' }, findings.map((finding) => {
            const severity = SEVERITY[finding.severity];
            return navItem({
                key: `nav-finding-${finding.id}`, iconName: severity.icon, tone: severity.tone, label: plainText(finding.claim), title: `${finding.severity}: ${plainText(finding.claim)}`,
                current: ui.focus.findingId === finding.id, onClick: () => select(about('finding', finding.id), { stage: 'verify' }),
            });
        })));
        const threads = view.discussion.items.filter((comment) => !comment.replyTo && matches(filter, comment.author, comment.body));
        sections.push(h('h2', { class: 'nav-title' }, 'Discussion', count(view.discussion.items.length)));
        sections.push(h('ul', { class: 'nav-list' }, threads.map((comment) => navItem({
            key: `nav-comment-${comment.id}`, iconName: 'message', tone: 'user', label: `${comment.author}: ${plainText(comment.body)}`, title: plainText(comment.body),
            current: ui.focus.commentId === comment.id, onClick: () => select(about('comment', comment.id), { stage: 'verify' }),
        }))));
        if (!findings.length && !threads.length) sections.push(h('p', { class: 'empty' }, filter ? 'Nothing matches the filter.' : 'No findings or comments yet.'));
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
        const board = coverageBoard(view);
        const size = (id) => board.find((group) => group.id === id).areas.length;
        return view.areas.length ? `${size('reviewed')} of ${view.areas.length} areas reviewed, ${size('active')} in progress, ${size('attention')} need attention.` : 'The agent has not scheduled review work yet.';
    }
    if (ui.stage === 'verify') {
        const proposed = view.findings.filter((finding) => finding.disposition === 'proposed').length;
        return `${proposed} to verify, ${view.findings.filter((finding) => isRetained(finding) && finding.disposition !== 'proposed').length} retained, ${view.discussion.items.length} discussion ${view.discussion.items.length === 1 ? 'comment' : 'comments'}.`;
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
    else if (ui.stage === 'verify') nodes.push(...verifyView());
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
    const perspectives = [...new Set((view.workItems ?? []).map((item) => item.perspective))];
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
            ['Perspectives', perspectives.length ? h('span', { class: 'chip-row' }, perspectives.map((entry) => badge({ label: PERSPECTIVE[entry] ?? entry, icon: 'eye', tone: 'muted' }))) : null],
            ['Rationale', view.scope.rationale ? prose(view.scope.rationale, 'prose small') : null],
        ]) : h('p', { class: 'empty' }, 'The agent has not scheduled the review yet.')),
        row('row-details', 'Pull request details', 'info', [badge(statusMeta[metadata.status] ?? statusMeta.unavailable)], metadata.fields.length
            ? h('ul', { class: 'metadata-list' }, metadata.fields.map((field) => {
                const linked = view.findings.filter((finding) => finding.anchors.some((anchor) => anchor.field === field.name));
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
    return view.findings.filter((finding) => finding.anchors.some((anchor) => area.fileIds.includes(anchor.fileId)));
}

function reviewView() {
    const nodes = [];
    const board = coverageBoard(view);
    const reviewed = board.find((group) => group.id === 'reviewed').areas.length;
    nodes.push(h('section', { class: 'board-dock', 'aria-labelledby': 'boardTitle' },
        h('div', { class: 'board-dock-head' },
            h('h3', { class: 'board-dock-title', id: 'boardTitle' }, icon('list'), 'Coverage board'),
            h('span', { class: 'board-progress' }, h('progress', { class: 'progress', max: Math.max(view.areas.length, 1), value: reviewed, 'aria-label': 'Areas reviewed' }),
                `${reviewed} of ${view.areas.length} areas reviewed`),
            h('button', { type: 'button', class: 'btn btn-icon board-dock-toggle', 'aria-expanded': ui.boardOpen, 'aria-controls': 'coverageBoard', title: ui.boardOpen ? 'Collapse the board' : 'Expand the board',
                dataset: { key: 'board-toggle' }, on: { click: () => { ui.boardOpen = !ui.boardOpen; render(); } } }, icon('chevron'),
            h('span', { class: 'visually-hidden' }, ui.boardOpen ? 'Collapse the coverage board' : 'Expand the coverage board'))),
        h('div', { class: 'board', id: 'coverageBoard', hidden: !ui.boardOpen }, board.map((group) => h('section', { class: `board-col tone-${group.tone}`, 'aria-labelledby': `lane-${group.id}` },
            h('h4', { class: 'board-col-title', id: `lane-${group.id}` }, icon(group.icon), group.title, count(group.areas.length)),
            group.areas.length ? h('ul', { class: 'board-list' }, group.areas.map((area) => h('li', {}, boardCard(area, group)))) : h('p', { class: 'empty' }, 'None')))),
        h('p', { class: 'meta', hidden: !ui.boardOpen }, 'Reviewed means every required perspective finished its assigned files. It is not approval, and zero findings is not a pass.')));
    const area = view.areas.find((entry) => entry.id === ui.focus.areaId);
    if (!area) {
        nodes.push(h('p', { class: 'empty row' }, view.areas.length ? 'Select an area to see its summary, impact, and files.' : 'The agent has not scheduled review work. Captured files are listed under Capture.'));
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
        impactMap(area),
        workSummary(area)));
    const files = view.files.filter((file) => area.fileIds.includes(file.id));
    nodes.push(row('row-files', 'Files', 'diff', [count(files.length)], h('ul', { class: 'file-list' }, files.map((file) => h('li', {}, fileRow(file))))));
    nodes.push(h('section', { class: 'row', id: 'row-diff', tabIndex: -1, 'aria-labelledby': 'row-diff-title' }, h('div', { id: 'diffHost' })));
    return nodes;
}

function boardCard(area, group) {
    const status = EXECUTION[area.status] ?? EXECUTION.pending;
    const findings = areaFindings(area);
    const work = area.work.map((item) => `${PERSPECTIVE[item.perspective] ?? item.perspective} ${(EXECUTION[item.status] ?? EXECUTION.pending).label.toLowerCase()}`).join(', ');
    const label = `${area.title}, ${status.label.toLowerCase()}. ${work ? `${work}. ` : ''}${area.fileIds.length} ${area.fileIds.length === 1 ? 'file' : 'files'}${findings.length ? `, ${findings.length} ${findings.length === 1 ? 'finding' : 'findings'}` : ''}.`;
    return h('button', {
        type: 'button', class: `board-card${group.id === 'attention' ? ' is-attention' : ''}`, 'aria-current': ui.focus.areaId === area.id ? 'true' : null, 'aria-label': label,
        dataset: { key: `card-${area.id}` }, on: { click: () => select(about('area', area.id), { stage: 'review' }) },
    }, h('span', { class: 'board-card-head' }, idChip(area.id, { kind: 'area' }), badge(status)),
    h('span', { class: 'board-card-title' }, area.title),
    perspectiveChips(area.work),
    h('span', { class: 'board-card-foot' }, h('span', {}, `${area.fileIds.length} ${area.fileIds.length === 1 ? 'file' : 'files'}`),
        findings.length ? h('span', {}, `${findings.length} ${findings.length === 1 ? 'finding' : 'findings'}`) : null));
}

function impactMap(area) {
    const caption = 'How this change connects to other parts. Each link cites captured evidence or says what is uncertain; the list below describes every link.';
    if (!area.impact.length) {
        return h('div', {}, h('h4', { class: 'sub-title' }, icon('nodes'), 'Impact'), h('p', { class: 'empty' }, 'No impact links are recorded. Untraced consumers are not shown as connections.'));
    }
    const layout = impactLayout(area.impact);
    const drawing = svg('svg', { class: 'impact-svg', viewBox: `0 0 ${layout.width} ${layout.height}`, width: layout.width, height: layout.height, 'aria-hidden': 'true', focusable: 'false' },
        svg('defs', {}, svg('marker', { id: 'impact-arrow', viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' },
            svg('path', { d: 'M0 0L10 5L0 10z', class: 'impact-arrowhead' }))),
        layout.links.map((link) => svg('path', { d: link.path, class: `impact-link${link.uncertain ? ' is-uncertain' : ''}`, 'marker-end': 'url(#impact-arrow)' })),
        layout.nodes.map((node) => svg('g', { class: 'impact-box' },
            svg('rect', { x: node.x, y: node.y, width: node.width, height: node.height, rx: 6 }),
            svg('text', { class: 'impact-text', x: node.x + 12, y: node.y + 8 },
                node.lines.map((line, index) => svg('tspan', { x: node.x + 12, dy: index ? 18 : 14 }, line))))));
    return h('figure', { class: 'impact-map' }, h('h4', { class: 'sub-title' }, icon('nodes'), 'Impact'), h('figcaption', {}, caption),
        h('div', { class: 'impact-canvas' }, drawing),
        h('ol', { class: 'impact-list' }, area.impact.map((edge, index) => h('li', { class: `impact-edge${edge.uncertainty ? ' is-uncertain' : ''}` },
            h('div', { class: 'impact-flow' }, h('span', { class: 'impact-node' }, icon('code'), edge.from), h('span', { class: 'impact-arrow' }, icon('arrow-right'), h('span', { class: 'visually-hidden' }, 'affects')),
                h('span', { class: 'impact-node' }, icon('code'), edge.to)),
            prose(edge.description, 'prose small'),
            h('div', { class: 'impact-foot' },
                edge.anchor?.fileId ? h('button', { type: 'button', class: 'id-chip', 'data-kind': 'file', dataset: { key: `impact-${index}` }, title: 'Show the supporting evidence',
                    on: { click: () => goToAnchor(edge.anchor) } }, anchorLabel(view, edge.anchor), icon('go-to')) : null,
                edge.uncertainty ? badge({ label: 'Uncertain', icon: 'question', tone: 'attention' }) : null,
                edge.uncertainty ? h('span', { class: 'meta' }, edge.uncertainty) : null)))));
}

function workSummary(area) {
    const notes = area.work.filter((item) => item.summary || item.observations?.length || item.coverage?.notApplicable);
    if (!notes.length) return null;
    return h('details', {}, h('summary', {}, `Review work notes (${notes.length})`), h('ul', { class: 'steer-list' }, notes.map((item) => h('li', { class: 'omission' },
        badge(EXECUTION[item.status] ?? EXECUTION.pending, { text: PERSPECTIVE[item.perspective] ?? item.perspective }),
        h('div', {}, item.summary ? prose(item.summary, 'prose small') : null, item.coverage?.notApplicable ? meta(`Not applicable: ${item.coverage.notApplicable}`) : null,
            ...(item.observations ?? []).map((text) => meta(text)))))));
}

function fileRow(file) {
    const stats = fileStats(file);
    const { dir, name } = splitPath(file.newPath ?? file.oldPath);
    const notes = fileAnnotations(view, file);
    const label = `${fileLabel(file)}, ${fileStatus(file).label.toLowerCase()}, ${stats.additions} lines added, ${stats.deletions} removed${notes.findings.length ? `, ${notes.findings.length} ${notes.findings.length === 1 ? 'finding' : 'findings'}` : ''}${notes.comments.length ? `, ${notes.comments.length} ${notes.comments.length === 1 ? 'comment' : 'comments'}` : ''}`;
    return h('button', {
        type: 'button', class: 'file-row', 'aria-current': ui.focus.fileId === file.id ? 'true' : null, title: fileLabel(file), 'aria-label': label,
        dataset: { key: `file-${file.id}` }, on: { click: () => select(about('file', file.id), { stage: 'review' }) },
    }, fileLetter(file), h('span', { class: 'file-path' }, file.status === 'R' ? h('span', { class: 'dir' }, `${file.oldPath} → `) : null, h('span', { class: 'dir' }, dir), h('span', { class: 'name' }, name)),
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
        const notes = hunkAnnotations(view, file, hunk);
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
            h('div', { class: 'hunk-code' }, h('div', { class: 'hunk-head' }, `@@ -${hunk.oldStart},${hunk.oldCount} +${hunk.newStart},${hunk.newCount} @@`), table),
            hasNotes ? h('div', { class: 'hunk-notes', 'aria-label': 'Findings and comments on these lines' },
                ...notes.findings.map((finding) => h('div', { class: 'note-card' },
                    h('div', { class: 'note-head' }, badge(SEVERITY[finding.severity], { strong: true }), badge(DISPOSITION[finding.disposition] ?? DISPOSITION.proposed)),
                    h('p', { class: 'note-title' }, finding.claim),
                    h('div', {}, h('button', { type: 'button', class: 'id-chip', 'data-kind': 'finding', dataset: { key: `note-finding-${finding.id}` }, title: 'Open this finding',
                        on: { click: () => select(about('finding', finding.id), { stage: 'verify', flash: true }) } }, finding.id, icon('go-to'))))),
                ...notes.comments.map((comment) => h('div', { class: 'note-card is-comment' },
                    h('div', { class: 'note-head' }, h('span', { class: 'comment-author' }, icon('person'), comment.author), resolutionBadge(comment)),
                    prose(comment.body, 'prose small'),
                    h('div', {}, h('button', { type: 'button', class: 'id-chip', 'data-kind': 'comment', dataset: { key: `note-comment-${comment.id}` }, title: 'Open this comment',
                        on: { click: () => select(about('comment', comment.id), { stage: 'verify', flash: true }) } }, comment.id, icon('go-to')))))) : null);
    });
}

function findingChip(finding) {
    return h('button', { type: 'button', class: 'id-chip', 'data-kind': 'finding', title: finding.claim, dataset: { key: `chip-finding-${finding.id}` },
        on: { click: () => select(about('finding', finding.id), { stage: 'verify', flash: true }) } }, finding.id, icon('go-to'));
}

function resolutionBadge(comment) {
    const meta = { resolved: { label: 'Resolved', icon: 'check-circle', tone: 'success' }, unresolved: { label: 'Unresolved', icon: 'circle', tone: 'attention' },
        unknown: { label: 'Resolution unknown', icon: 'question', tone: 'muted' } };
    return badge(meta[comment.resolution] ?? meta.unknown);
}

function verifyView() {
    if (!ui.findingFilter || !FINDING_FILTERS.some((entry) => entry.id === ui.findingFilter)) ui.findingFilter = defaultFindingFilter(view);
    const shown = findingFilter(view, ui.findingFilter);
    const filters = h('fieldset', { class: 'segmented', 'aria-label': 'Show findings' }, h('legend', { class: 'visually-hidden' }, 'Show findings'),
        FINDING_FILTERS.map((entry) => h('label', {}, h('input', { type: 'radio', name: 'findingFilter', value: entry.id, checked: ui.findingFilter === entry.id,
            dataset: { key: `filter-${entry.id}` }, on: { change: () => { ui.findingFilter = entry.id; render(); } } }),
        h('span', {}, entry.label), count(findingFilter(view, entry.id).length))));
    const findings = row('row-findings', 'Findings', 'shield-check', [count(view.findings.length)], filters,
        shown.length ? h('ul', { class: 'finding-list' }, shown.map((finding) => h('li', {}, findingCard(finding))))
            : h('p', { class: 'empty' }, view.findings.length ? 'No findings in this view.' : 'No findings are recorded. Check coverage and evidence limits before drawing a conclusion.'));
    const discussion = view.discussion;
    const statusMeta = { complete: { label: 'Imported', icon: 'check-circle', tone: 'success' }, partial: { label: 'Partly imported', icon: 'half', tone: 'attention' },
        unavailable: { label: 'Unavailable', icon: 'slash-circle', tone: 'muted' }, not_applicable: { label: 'Not applicable', icon: 'dash-circle', tone: 'muted' } };
    const roots = discussion.items.filter((comment) => !comment.replyTo || !discussion.items.some((entry) => entry.id === comment.replyTo));
    const thread = (comment) => h('li', {}, commentCard(comment), (() => {
        const replies = discussion.items.filter((entry) => entry.replyTo === comment.id);
        return replies.length ? h('ul', { class: 'replies' }, replies.map(thread)) : null;
    })());
    const talk = row('row-discussion', 'Pull request discussion', 'message', [badge(statusMeta[discussion.status] ?? statusMeta.unavailable), count(discussion.items.length)],
        discussion.limitations.length ? h('div', { class: 'notice tone-attention' }, h('p', { class: 'notice-title' }, icon('info'), 'Import limits'), h('ul', {}, discussion.limitations.map((text) => h('li', {}, text)))) : null,
        roots.length ? h('ul', { class: 'thread-list' }, roots.map(thread)) : h('p', { class: 'empty' }, discussion.status === 'not_applicable' ? 'This target has no provider discussion.' : 'No discussion was imported.'));
    return [findings, talk];
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
                on: { click: () => { select(about('finding', item.id), { stage: 'verify', flash: true }); closeDrawer(false); } } },
            icon(severity.icon), h('span', { class: 'steer-link-text' }, `${severity.label}: ${plainText(item.label)}`)));
        })) : h('p', { class: 'empty' }, 'Nothing needs you. High and Critical findings wait here until you mark them seen.'));

    const groups = [
        ['Not sent', view.feedback.items.filter((item) => item.status === 'queued')],
        ['Drafts', view.feedback.items.filter((item) => item.status === 'draft')],
        ['Sent', view.feedback.items.filter((item) => item.status === 'sent')],
        ['Read back', view.feedback.items.filter((item) => item.status === 'interpreted')],
    ].filter(([, items]) => items.length);
    $('feedbackSection').replaceChildren(
        h('h3', { class: 'steer-title', id: 'feedbackTitle' }, icon('inbox'), 'Your feedback', count(view.feedback.items.length)),
        ...(groups.length ? groups.map(([title, items]) => h('div', { class: 'feedback-group' }, h('h4', { class: 'feedback-group-title' }, title),
            h('ul', { class: 'feedback-list' }, items.map((item) => h('li', {}, feedbackItem(item))))))
            : [h('p', { class: 'empty' }, 'Questions, disputes, and comment drafts you add stay here until you send them. Bookmarks and seen marks stay private to you.')]));
    renderComposerTarget();
}

function targetLabel(target) {
    if (target.kind === 'review') return 'Whole review';
    if (target.kind === 'finding') return target.id;
    if (target.kind === 'file' || target.kind === 'hunk') {
        const file = target.kind === 'file' ? view.files.find((entry) => entry.id === target.id) : view.files.find((entry) => entry.hunks.some((hunk) => hunk.id === target.id));
        return file ? `${splitPath(file.newPath ?? file.oldPath).name}${target.kind === 'hunk' ? ' (lines)' : ''}` : target.id;
    }
    if (target.kind === 'area') return view.areas.find((entry) => entry.id === target.id)?.title ?? target.id;
    return target.id;
}

function targetChip(target) {
    const older = target.snapshotId !== view.snapshotId;
    const kind = { finding: 'finding', comment: 'comment', area: 'area', file: 'file', hunk: 'file', review: 'review' }[target.kind];
    if (older || target.kind === 'review') return idChip(older ? `${targetLabel(target)} (earlier snapshot)` : targetLabel(target), { kind });
    return h('button', { type: 'button', class: 'id-chip', 'data-kind': kind, title: 'Show this item', on: { click: () => select(target, { stage: stageFor(target) }) } }, targetLabel(target), icon('go-to'));
}

function feedbackItem(item) {
    const state = feedbackState(item);
    return h('article', { class: 'feedback-item' },
        h('div', { class: 'chip-row' }, badge(state), meta(FEEDBACK_KIND[item.kind] ?? item.kind), targetChip(item.target)),
        h('p', { class: 'feedback-item-text' }, item.text || '(empty draft)'),
        item.delivery?.status === 'failed' ? h('p', { class: 'field-error' }, icon('alert'), `${item.delivery.error ?? 'Delivery failed.'} The agent can still collect it.`) : null,
        item.interpretation ? h('div', { class: 'readback' }, h('p', { class: 'meta' }, icon('sparkle'), ' The agent understood'), prose(item.interpretation.text, 'prose small'),
            meta(`${item.interpretation.effect}${item.interpretation.applied ? '' : ' (not applied yet)'}`)) : null,
        item.status === 'draft' ? h('div', { class: 'btn-row' }, h('button', { type: 'button', class: 'btn btn-compact', dataset: { key: `edit-${item.id}` }, on: { click: () => editDraft(item) } }, icon('pencil'), 'Edit')) : null);
}

function renderComposerTarget() {
    if (!ui.composer.target || (ui.composer.target.snapshotId !== view.snapshotId && !ui.composer.id)) ui.composer.target = about('review', view.reviewId);
    $('composeTarget').replaceChildren(targetChip(ui.composer.target));
    $('composeReset').hidden = ui.composer.target.kind === 'review';
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
        composerError('Save or queue your current words before starting another item. Your text is still here.');
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
        composerError('Save or queue your current words before opening another draft.');
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
        ui.composer = { id: null, target: about('review', view.reviewId), saved: '' };
        $('feedbackText').value = '';
        $('feedbackKind').value = 'comment';
    } else ui.composer = { ...ui.composer, id, saved: text };
    await refresh();
    announce(queue ? 'Queued for the agent. Use Review and send to deliver it.' : 'Draft saved. It stays private until you queue it.');
}

async function mark(kind, target, value) {
    await api('/api/feedback', { action: 'mark', input: { revision: view.feedback.revision, target, kind, value } });
    await refresh();
    announce(kind === 'bookmark' ? (value ? 'Bookmarked.' : 'Bookmark removed.') : (value ? 'Marked as seen.' : 'Marked as not seen.'));
}

// Review and send

async function openSend() {
    await refresh();
    sendRevision = view.feedback.revision;
    const queued = view.feedback.items.filter((item) => item.status === 'queued');
    $('sendList').replaceChildren(...(queued.length ? queued.map((item) => h('article', { class: 'feedback-item' },
        h('div', { class: 'chip-row' }, badge(feedbackState(item)), meta(FEEDBACK_KIND[item.kind] ?? item.kind), idChip(targetLabel(item.target)),
            item.target.snapshotId !== view.snapshotId ? badge({ label: 'Earlier snapshot', icon: 'clock', tone: 'attention' }) : null),
        h('p', { class: 'feedback-item-text' }, item.text))) : [h('p', { class: 'empty' }, 'Nothing is queued. Save an item and choose Queue for the agent first.')]));
    $('sendNow').disabled = queued.length === 0;
    $('sendError').hidden = true;
    $('sendSheet').showModal();
    $('sendTitle').focus();
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
    ['1 to 4', 'View Capture, Review, Verify, or Outcome'], ['n', 'Go to the next item that needs you'], ['[ and ]', 'Previous and next file in the area'],
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
        } else if (!$('appearanceMenu').hidden) {
            toggleAppearance(false);
            $('appearanceBtn').focus();
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
    if (/^[1-4]$/.test(key)) setStage(STAGE_KEYS[Number(key) - 1]);
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

async function refresh() {
    if (refreshing) {
        refreshAgain = true;
        return;
    }
    refreshing = true;
    try {
        const previous = view;
        view = await api('/api/state');
        if (previous && previous.snapshotId !== view.snapshotId) {
            evidence.clear();
            ui.reportText = null;
        }
        const remote = view.focus ? `${view.focus.snapshotId}:${view.focusRevision ?? 0}` : '';
        let agentFocus = null;
        if (view.focus && remote !== ui.remoteFocus) {
            ui.remoteFocus = remote;
            if (previous || !ui.loaded) agentFocus = view.focus;
        }
        if (!ui.target || ui.target.snapshotId !== view.snapshotId) ui.target = about('review', view.reviewId);
        ui.focus = resolveFocus(view, ui.target);
        if (agentFocus && agentFocus.snapshotId === view.snapshotId) {
            if (ui.follow || !ui.loaded) select(agentFocus, { stage: stageFor(agentFocus), moveFocus: false, flash: Boolean(previous) });
            else {
                render();
                note(`The agent pointed to ${agentFocus.kind} ${agentFocus.id}.`, 'accent', 'sparkle', { label: 'Show', run: () => select(agentFocus, { stage: stageFor(agentFocus), flash: true }) });
            }
        } else render();
        if (previous) {
            if (previous.snapshotId !== view.snapshotId) announce('A new snapshot loaded. Your feedback is kept; coverage belongs to the new snapshot.');
            else if (view.feedback.items.some((item) => item.status === 'interpreted' && previous.feedback.items.find((entry) => entry.id === item.id)?.status !== 'interpreted')) announce('The agent read back your feedback.');
            else if (!previous.stale && view.stale) announce('The review record could not be read. The last valid evidence stays on screen.');
            else if (previous.revision !== view.revision) announce(`Review updated to revision ${view.revision}.`);
        }
        ui.loaded = true;
    } finally {
        refreshing = false;
        if (refreshAgain) {
            refreshAgain = false;
            queueMicrotask(() => run(refresh));
        }
    }
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
    $('composeReset').addEventListener('click', () => {
        if (composerDirty() && $('feedbackText').value.trim()) {
            composerError('Save or queue your current words before changing what they are about.');
            return;
        }
        composerError('');
        ui.composer = { id: null, target: about('review', view.reviewId), saved: '' };
        renderComposerTarget();
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
