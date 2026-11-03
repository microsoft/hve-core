// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Test helper: renders every phase view, its outline, and the steering panel for a session
// under the fake DOM, the way ui/app.mjs does. Call installFakeDom() before importing.
import { deriveView, findItem } from '../../lib/model.mjs';
import { mapPart } from '../../ui/map-part.mjs';
import { decisionAlias } from '../../ui/dom.mjs';
import { serialize } from './fake-dom.mjs';

const MODULES = {
    research: '../../ui/view-research.mjs',
    plan: '../../ui/view-plan.mjs',
    implement: '../../ui/view-implement.mjs',
    review: '../../ui/view-review.mjs',
    followup: '../../ui/view-followup.mjs',
};

/** UI state matching ui/app.mjs at load, for one viewed phase. */
export function initialUi(phase) {
    return {
        presentation: 'focused',
        phase,
        highlight: null,
        editing: null,
        expanded: new Set(),
        openEvidence: new Set(),
        send: { note: '', preview: null, previewNote: null, sending: false, error: null },
        composer: { text: '', anchor: null },
        decisionDrafts: new Map(),
        corrections: new Map(),
        overrides: new Set(),
        revealed: new Set(),
        boardLane: null,
        diagramView: 'after',
        diagramPhase: null,
        recordOpen: true,
        openDetails: new Set(),
        navFilter: '',
        shortcuts: true,
        navOpen: true,
        steerOpen: true,
        drawer: null,
    };
}

/** A view context with no-op actions; a bare `D#` names the viewed phase's decision first, as in the page. */
export function makeContext(session, phase, ui = initialUi(phase), canvas = { handle: 'K7QF', instanceId: 'test-canvas' }) {
    const find = (ref) => {
        if (String(ref).startsWith('part:')) return mapPart(session, ref);
        const id = decisionAlias(session, ref, phase);
        return findItem(session, id)?.item ?? (Object.prototype.hasOwnProperty.call(session.sections, id) ? session.sections[id] : null);
    };
    const act = new Proxy({}, { get: () => () => {} });
    return { data: { session, view: deriveView(session), canvas }, ui, act, find, resolve: (id) => (find(id) ? { phase } : null), now: Date.parse(session.updatedAt) || Date.now() };
}

const toArray = (value) => (Array.isArray(value) ? value : [value]).filter(Boolean);

/**
 * Renders each phase. Returns serialized document and steering HTML plus the outline per
 * phase; a renderer that throws fails the caller's test.
 *
 * @param {any} session
 */
export async function renderAll(session) {
    const { steerPanel } = await import('../../ui/components.mjs');
    const out = {};
    for (const [phase, path] of Object.entries(MODULES)) {
        const view = await import(path);
        const ctx = makeContext(session, phase);
        const outline = view.outline(ctx);
        const rows = toArray(view.renderView(ctx));
        const steer = toArray(steerPanel(ctx));
        out[phase] = { outline, html: rows.map(serialize).join(''), steer: steer.map(serialize).join('') };
    }
    return out;
}
