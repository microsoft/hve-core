// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * A session's documents by phase, without DOM: which phases switch documents, how an earlier
 * document reads in place of the current work's, where an ID lives while an earlier document
 * shows, and what the Document list offers. The page and its tests share these rules.
 */

/** The phases that switch documents, and how each phase's document reads in a sentence. */
export const DOCUMENT_NOUNS = Object.freeze({ research: 'research document', plan: 'plan', implement: 'changes record', review: 'review' });

/** Longest label an option or option group shows before it ends with an ellipsis; the notice shows the whole title. */
export const DOCUMENT_OPTION_CHARS = 72;

const EMPTY_PLAN = Object.freeze({ phases: [], requirements: [], diagram: null, critique: null, readiness: null });

/**
 * A phase's documents in the order the session made them; `current` marks the current work's.
 *
 * @param {any} session
 * @param {string} phase
 * @returns {any[]}
 */
export const documentsIn = (session, phase) => session?.documents?.[phase] ?? [];

/** A document's name for people: its title, else its work's name, else its path. */
export const documentLabel = (doc) => doc.title || doc.name || doc.path;

/**
 * The earlier document numbered `n` in a phase, when it can show; null for 0, null, the current
 * work's, or one that could not be read.
 *
 * @param {any} session
 * @param {string} phase
 * @param {number | null | undefined} n
 */
export function earlierDocument(session, phase, n) {
    if (!n) return null;
    return documentsIn(session, phase).find((doc) => doc.n === n && !doc.current && doc.snapshot) ?? null;
}

/** The sections a plan's tasks render, by section ID. */
function taskSectionsOf(plan, sections) {
    const ids = new Set((plan?.phases ?? []).flatMap((phase) => phase.tasks.map((task) => task.sectionId)));
    return Object.fromEntries(Object.entries(sections ?? {}).filter(([id]) => ids.has(id)));
}

/**
 * The plan an earlier changes record shows with: the plan its snapshot names, from that plan's
 * snapshot or, when it is the current work's, the current plan. `missing` when no plan carries
 * the record's name or that plan could not be read.
 *
 * @param {any} session
 * @param {any} doc an earlier changes record
 * @returns {{ plan: any, sections: Record<string, any>, decisions: any[], missing: boolean }}
 */
export function pairedPlanOf(session, doc) {
    const entry = doc.snapshot?.pairedPlan ? documentsIn(session, 'plan').find((item) => item.n === doc.snapshot.pairedPlan) : null;
    if (entry?.current) return { plan: session.plan, sections: taskSectionsOf(session.plan, session.sections), decisions: session.decisions.filter((decision) => decision.phase === 'plan'), missing: false };
    if (entry?.snapshot) return { plan: entry.snapshot.plan, sections: taskSectionsOf(entry.snapshot.plan, entry.snapshot.sections), decisions: entry.snapshot.decisions, missing: false };
    return { plan: EMPTY_PLAN, sections: {}, decisions: [], missing: true };
}

const composed = new WeakMap();

/**
 * The session as it reads with an earlier document in place of the current work's in its phase:
 * that document's part, sections, decisions, status, and other sections; its traces stay in its
 * snapshot. An earlier changes record brings its plan's tasks, task sections, and decisions, so
 * its board, tasks, and change map are its own work's. Results are kept per session object.
 *
 * @param {any} session
 * @param {string} phase
 * @param {any} doc an earlier document of the phase, with its snapshot
 */
export function composeDocument(session, phase, doc) {
    const key = `${phase}:${doc.n}`;
    const cached = composed.get(session)?.get(key);
    if (cached) return cached;
    const { snapshot } = doc;
    const without = (drop) => Object.fromEntries(Object.entries(session.sections).filter(([, section]) => !drop.includes(section.doc)));
    let result = {
        ...session,
        records: { ...session.records, [phase]: snapshot.records ?? [] },
        phases: { ...session.phases, [phase]: { ...session.phases[phase], status: snapshot.record?.status ?? session.phases[phase].status, artifact: doc.path, updatedAt: doc.updatedAt ?? session.phases[phase].updatedAt } },
    };
    if (phase === 'research' || phase === 'plan') {
        result = {
            ...result,
            [phase]: phase === 'research' ? { ...snapshot.research, lanes: [] } : snapshot.plan,
            sections: { ...without([phase]), ...snapshot.sections },
            decisions: [...session.decisions.filter((decision) => decision.phase !== phase), ...snapshot.decisions],
        };
    } else if (phase === 'implement') {
        const paired = pairedPlanOf(session, doc);
        result = {
            ...result,
            plan: paired.plan,
            implementation: snapshot.implementation,
            sections: { ...without(['plan', 'implement']), ...paired.sections, ...snapshot.sections },
            decisions: paired.decisions,
        };
    } else {
        result = {
            ...result,
            review: snapshot.review,
            sections: { ...without(['review']), ...snapshot.sections },
            decisions: session.decisions.filter((decision) => decision.phase !== 'review'),
        };
    }
    if (!composed.has(session)) composed.set(session, new Map());
    composed.get(session).set(key, result);
    return result;
}

/** The pools of IDs each phase's document holds beside its sections; a plan and a changes record also hold the plan's phases and tasks. */
const POOLS = Object.freeze({
    research: (part) => [part.research?.questions, part.research?.findings, part.research?.evidence, part.decisions],
    plan: (part) => [part.plan?.requirements, part.plan?.critique?.findings, part.decisions],
    implement: (part) => [part.implementation?.changes, part.implementation?.discoveries, part.implementation?.alignment],
    review: (part) => [part.review?.findings, part.review?.history],
});

/**
 * What a phase's document holds for lookups: its part, its own decisions, and its own sections,
 * from an earlier document's composed session or from the current work's.
 *
 * @param {any} session
 * @param {string} phase
 * @param {any | null} doc an earlier document, or null or the current entry for the current work's
 */
export function partOf(session, phase, doc) {
    const source = doc && !doc.current ? composeDocument(session, phase, doc) : session;
    const tasks = phase === 'implement' ? taskSectionsOf(source.plan, source.sections) : {};
    return {
        research: source.research,
        plan: source.plan,
        implementation: source.implementation,
        review: source.review,
        decisions: source.decisions.filter((decision) => decision.phase === phase),
        sections: { ...Object.fromEntries(Object.entries(source.sections).filter(([, section]) => section.doc === phase)), ...tasks },
    };
}

/**
 * An item a phase's document holds: in its pools, in its plan's phases and tasks for a plan or
 * changes record, or among its sections.
 *
 * @param {string} phase
 * @param {ReturnType<typeof partOf>} part
 * @param {string} id
 */
export function findInPart(phase, part, id) {
    for (const pool of POOLS[phase](part)) {
        const found = (pool ?? []).find((item) => item?.id === id);
        if (found) return found;
    }
    if (phase === 'plan' || phase === 'implement') {
        for (const planPhase of part.plan?.phases ?? []) {
            if (planPhase.id === id) return planPhase;
            const task = planPhase.tasks.find((entry) => entry.id === id);
            if (task) return task;
        }
    }
    return Object.prototype.hasOwnProperty.call(part.sections, id) ? part.sections[id] : null;
}

/**
 * The newest earlier document holding an ID, searching Research, Plan, Implement, and Review in
 * order, as `{ phase, doc, item }`.
 *
 * @param {any} session
 * @param {string} id
 */
export function inEarlier(session, id) {
    for (const phase of Object.keys(DOCUMENT_NOUNS)) {
        for (const doc of [...documentsIn(session, phase)].reverse()) {
            if (doc.current || !doc.snapshot) continue;
            const item = findInPart(phase, partOf(session, phase, doc), id);
            if (item) return { phase, doc, item };
        }
    }
    return null;
}

/**
 * Where an ID lives while an earlier document shows: in that document, then in its work's other
 * documents, newest first with the current work's included, as `{ phase, doc, item }`, where
 * `doc` is an earlier document's number or null for the current work's. Null when none holds it,
 * so the caller falls back to the current work and other earlier documents.
 *
 * @param {any} session
 * @param {{ phase: string, doc: any }} scope the shown phase and its earlier document
 * @param {string} id
 */
export function scopedLookup(session, scope, id) {
    const own = findInPart(scope.phase, partOf(session, scope.phase, scope.doc), id);
    if (own) return { phase: scope.phase, doc: scope.doc.n, item: own };
    for (const phase of Object.keys(DOCUMENT_NOUNS)) {
        if (phase === scope.phase) continue;
        const docs = documentsIn(session, phase).filter((entry) => entry.name === scope.doc.name && (entry.current || entry.snapshot));
        for (const entry of [...docs].reverse()) {
            const item = findInPart(phase, partOf(session, phase, entry), id);
            if (item) return { phase, doc: entry.current ? null : entry.n, item };
        }
    }
    return null;
}

const clip = (text) => (text.length > DOCUMENT_OPTION_CHARS ? `${text.slice(0, DOCUMENT_OPTION_CHARS - 1).trimEnd()}…` : text);

/**
 * What a phase's Document list offers, or null when the phase has no earlier document. Options
 * keep the session's order; Review's sit in one group per work, labeled with the work's plan
 * title, in the order each work's first review was listed. When the current work has none of the
 * phase's documents, a "Current work" option ends the list outside any group.
 *
 * @param {any} session
 * @param {string} phase
 * @param {number | null | undefined} shown the earlier document shown, if any
 * @param {(doc: any) => string} [timeOf] how long ago a document changed, appended to its option
 * @returns {{ selected: number, groups: { label: string | null, options: { value: number, text: string, title: string | null, disabled: boolean }[] }[] } | null}
 */
export function documentChoices(session, phase, shown, timeOf = () => '') {
    const docs = documentsIn(session, phase);
    if (!DOCUMENT_NOUNS[phase] || !docs.some((doc) => !doc.current)) return null;
    const current = docs.find((doc) => doc.current) ?? null;
    const option = (doc) => {
        const time = doc.updatedAt ? timeOf(doc) : '';
        return {
            value: doc.n,
            text: `${clip(documentLabel(doc))}${doc.current ? ' (current)' : doc.snapshot ? '' : ' (unreadable)'}${time ? ` · ${time}` : ''}`,
            title: doc.path,
            disabled: !doc.current && !doc.snapshot,
        };
    };
    let groups;
    if (phase === 'review') {
        const byWork = new Map();
        for (const doc of docs) {
            if (!byWork.has(doc.name)) byWork.set(doc.name, { label: clip(doc.workTitle || doc.name || doc.path), options: [] });
            byWork.get(doc.name).options.push(option(doc));
        }
        groups = [...byWork.values()];
    } else {
        groups = [{ label: null, options: docs.map(option) }];
    }
    if (!current) groups.push({ label: null, options: [{ value: 0, text: `Current work: no ${DOCUMENT_NOUNS[phase]} yet`, title: null, disabled: false }] });
    const shownEarlier = earlierDocument(session, phase, shown);
    return { selected: shownEarlier?.n ?? current?.n ?? 0, groups };
}
