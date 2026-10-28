// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { md } from './components.mjs';
import { badge, confidenceMeta, DECISION_STATUS, DISCOVERY_KIND, EVIDENCE_STATE, FEEDBACK_KIND, FEEDBACK_STATE, h, icon, idChip, known, SEVERITY, sr, TASK_STATUS } from './dom.mjs';
import { taskMarkers } from './board.mjs';
import { kindOf } from './ids.mjs';
import { evidenceSource } from './source-view.mjs';

/** Longest text a preview shows from one field; Go to reads the rest. */
export const PREVIEW_TEXT_LIMIT = 600;

function clip(text) {
    const value = String(text ?? '').trim();
    if (value.length <= PREVIEW_TEXT_LIMIT) return { text: value, clipped: false };
    const cut = value.lastIndexOf(' ', PREVIEW_TEXT_LIMIT);
    return { text: `${value.slice(0, cut > PREVIEW_TEXT_LIMIT / 2 ? cut : PREVIEW_TEXT_LIMIT)}…`, clipped: true };
}

const plainStatus = (label) => (label ? { icon: 'info', label: String(label), tone: 'muted' } : null);
const words = (value) => String(value ?? '').replace(/-/g, ' ');

/**
 * Builds a preview's content parts for one item kind: a title, labeled text fields, badges,
 * and related IDs. Text fields render as Markdown, so IDs inside them open nested previews.
 */
function partsFor(ctx, key, item) {
    const chips = (label, ids) => ({ label, ids: (ids ?? []).filter((id) => typeof id === 'string' && id) });
    const session = ctx.data.session;
    // The plan tasks whose Requirements cite a research finding or decision.
    const citedBy = (id) => (session.plan?.phases ?? []).flatMap((phase) => phase.tasks).filter((task) => task.research?.includes(id)).map((task) => task.id);
    switch (key) {
        case 'Q':
            return { title: item.text, badges: [plainStatus(words(item.status))], related: [chips('Answered by', item.findings)] };
        case 'F':
            return { title: item.title, badges: [known(EVIDENCE_STATE, item.state), item.confidence ? { ...confidenceMeta(item.confidence), prefix: 'Confidence' } : null], related: [chips('Answers', item.questions), chips('Evidence', item.evidence), chips('Plan tasks', citedBy(item.id))] };
        case 'C':
        case 'W': {
            const citing = [...session.research.findings, ...session.decisions].filter((entry) => entry.evidence?.includes(item.id)).map((entry) => entry.id);
            return {
                title: item.claim,
                badges: [item.confidence ? { ...confidenceMeta(item.confidence), prefix: 'Confidence' } : null, plainStatus(item.retrieved && `Retrieved ${item.retrieved}`)],
                source: item,
                related: [chips('Cited by', citing)],
            };
        }
        case 'L':
            return { title: item.question, badges: [plainStatus(words(item.status)), plainStatus(item.effort && `Effort ${item.effort}`)], fields: [['Result', item.summary]], related: [chips('Finding', [item.findingId]), chips('Started from', [item.origin])] };
        case 'D': {
            const chosen = item.options?.find((option) => option.id === item.chosen);
            return {
                title: item.title,
                badges: [known(DECISION_STATUS, item.status), plainStatus(item.owner && `Owner: ${item.owner}`)],
                fields: [['Question', item.question], ['Chosen', chosen?.label], ['Why', item.rationale], ['Impact', item.impact]],
                related: [chips('Evidence', item.evidence), chips('Plan tasks', item.phase === 'research' ? citedBy(item.id) : [])],
            };
        }
        case 'P':
            return { title: item.title, badges: [known(TASK_STATUS, item.status)], fields: [['Goal', item.goals]], related: [chips('Tasks', item.tasks?.map((task) => task.id))] };
        case 'T': {
            // A card leaves out what waits on the task, what blocks it, its changes, and the agent's recent work.
            const impl = session.implementation;
            const markers = taskMarkers(session, item);
            const waitsOn = markers.paused ? markers.decision : null;
            const blocker = markers.blocked ? markers.blocker : null;
            const activity = impl?.current?.taskId === item.id ? (impl.activity ?? []).slice(-3).reverse().map((line) => `- ${line.text}`).join('\n') : '';
            return {
                title: item.title,
                badges: [known(TASK_STATUS, item.status), markers.paused && item.status !== 'paused' ? TASK_STATUS.paused : null, markers.blocked && item.status !== 'blocked' ? TASK_STATUS.blocked : null],
                fields: [
                    ['Goal', item.goals],
                    ['Waiting on', waitsOn?.title],
                    ['Blocked', blocker ? [blocker.text, blocker.owner ? `Owner: ${blocker.owner}.` : '', blocker.clear ?? ''].filter(Boolean).join(' ') : ''],
                    ['Agent activity', activity],
                ],
                related: [
                    chips('Requirements', item.requirements),
                    chips('Research', item.research),
                    chips('Depends on', item.dependencies),
                    chips('Waits on', waitsOn ? [waitsOn.id] : []),
                    chips('Changes', (impl?.changes ?? []).filter((change) => change.taskId === item.id).map((change) => change.id)),
                ],
            };
        }
        case 'FR':
        case 'NFR':
            return { title: item.text, badges: [] };
        case 'PC':
            return { title: item.title, badges: [known(SEVERITY, item.severity), plainStatus(words(item.disposition))], fields: [['Response', item.response]], related: [chips('Related', item.related)] };
        case 'CH':
            return {
                title: item.title,
                badges: [],
                fields: [['What changed', item.behavior], ['Files', (item.files ?? []).map((file) => `\`${file.path}\``).join(', ')]],
                related: [chips('Task', [item.taskId])],
            };
        case 'DS':
            return { title: item.title, badges: [known(DISCOVERY_KIND, item.kind)], fields: [['Detail', item.detail], ['Plan update', item.planUpdate]], related: [chips('Task', [item.taskId]), chips('Decision', [item.decisionId])] };
        case 'AL':
            return { title: item.requirement ?? item.change, badges: [plainStatus(words(item.alignment))], fields: [['Change', item.change], ['Why', item.why], ['Source', item.document ?? item.source]], related: [chips('Plan marker', [item.marker])] };
        case 'RV':
            return { title: item.title, badges: [known(SEVERITY, item.severity), plainStatus(words(item.resolution))], fields: [['Summary', item.summary], ['Route', item.route]], related: [chips('Related', item.related)] };
        case 'RD':
            return { title: item.subject, badges: [plainStatus(words(item.status)), plainStatus(item.owner && `Owner: ${item.owner}`)], fields: [['Why', item.rationale]] };
        case 'FU':
            return { title: item.title, badges: [plainStatus(item.required ? 'Required' : 'Optional'), plainStatus(words(item.status))], fields: [['Why', item.rationale], ['Evidence', item.evidence]] };
        case 'FB':
            return {
                // A saved item of a kind the canvas no longer creates reads as a comment, as it does in the panel.
                title: (FEEDBACK_KIND[item.kind] ?? FEEDBACK_KIND.comment).label,
                badges: [known(FEEDBACK_STATE, item.state)],
                fields: [['Choice', item.optionLabel], ['Your words', item.text]],
                related: [chips('About', [item.target?.id])],
            };
        default:
            return { title: item.title ?? item.text ?? '', badges: [] };
    }
}


/**
 * The content of an ID's preview: a header naming the ID and its kind with a Go to button,
 * then the item's title, text, status, and related IDs. Returns null when the ID is unknown.
 *
 * @param {any} ctx view context
 * @param {string} id the ID a chip navigates to
 * @param {{ titleId: string }} options
 */
export function previewContent(ctx, id, options) {
    const item = ctx.find(id);
    const kind = kindOf(id);
    if (!item || !kind) return null;
    const label = item.ref ?? id;
    const parts = partsFor(ctx, kind.key, item);
    const notes = [];
    const fields = (parts.fields ?? []).filter(([, value]) => typeof value === 'string' && value.trim()).map(([name, value]) => {
        const shown = clip(value);
        if (shown.clipped) notes.push(name);
        return h('div', { class: 'preview-field' }, h('p', { class: 'preview-label', text: name }), h('div', { class: 'preview-text' }, md(ctx, shown.text)));
    });
    const title = clip(parts.title);
    const related = (parts.related ?? []).filter((group) => group.ids.length).map((group) => h('p', { class: 'chip-row preview-related' },
        h('span', { class: 'meta', text: group.label }),
        group.ids.map((ref) => {
            const shown = ctx.find(ref)?.ref ?? ref;
            return ctx.resolve(ref) ? idChip(ref, ctx.act.navigate, { label: shown }) : h('span', { class: 'id-chip', text: shown });
        })));
    const go = h('button', { type: 'button', class: 'btn btn-quiet preview-go', dataset: { key: `preview-go-${id}` }, onclick: () => ctx.act.navigate(id) },
        h('span', { text: 'Go to' }), sr(` ${label}`), icon('go-to', { className: 'icon-inline chip-icon' }));
    return {
        kind,
        label,
        head: h('div', { class: 'preview-head' },
            h('p', { class: 'preview-kind' }, h('span', { class: 'id-chip', text: label }), h('span', { text: kind.kind })),
            go),
        body: [
            title.text ? h('div', { class: 'preview-title', id: options.titleId }, md(ctx, title.text)) : h('p', { class: 'preview-title', id: options.titleId, text: `${label} · ${kind.kind}` }),
            ...(parts.badges ?? []).filter(Boolean).length ? [h('p', { class: 'preview-badges' }, (parts.badges ?? []).filter(Boolean).map((meta) => badge(meta, { prefix: meta.prefix, strong: Boolean(meta.prefix) })))] : [],
            ...fields,
            parts.source ? h('div', { class: 'preview-source' }, evidenceSource(ctx, parts.source)) : null,
            ...related,
            title.clipped || notes.length ? h('p', { class: 'meta preview-more', text: `Go to ${label} to read all of it.` }) : null,
        ].filter(Boolean),
    };
}
