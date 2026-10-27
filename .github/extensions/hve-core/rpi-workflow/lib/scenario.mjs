// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import * as implement from './scenario/implement.mjs';
import * as plan from './scenario/plan.mjs';
import * as research from './scenario/research.mjs';
import * as review from './scenario/review.mjs';
import { findItem, PHASES, SESSION_FORMAT, SESSION_VERSION, validateSession } from './model.mjs';

/**
 * Sample RPI session used by the canvas mockup: a fictional field-inspections app gaining
 * offline drafts. `buildScenario` returns the session as it looks during one stage.
 */

export const SCENARIO_ID = 'field-inspections-offline-sync';
export const STAGES = PHASES;

const NEXT_ACTION = Object.freeze({
    research: 'Waiting for your answer to D2 before planning',
    plan: 'Waiting for your answer to D5; implementation starts after it',
    implement: 'Implementing P02-T02; P03-T01 waits for your answer to D6',
    review: 'Routing accepted findings RV-001 to RV-004 to a child loop',
    followup: 'Child loop field-inspections-offline-sync-review-fixes is fixing RV-001 to RV-004',
});

// Trace connections that no reference field records. Every other trace link derives from the
// session's own fields (see referenceLinks in model.mjs).
const LINKS = Object.freeze([
    ['D1', 'P01-T01'], ['D2', 'D5'], ['F2', 'D7'], ['D3', 'P03-T01'], ['D6', 'CH-006'], ['D4', 'P04-T01'],
]);

const ANSWERS = Object.freeze({
    'FB-002': {
        decision: 'D2', option: 'a', text: 'Keep both photos when their content differs.', minutes: 160, sentMinutes: 158,
        interpretation: { text: 'Merge different fields automatically. Send same-field conflicts to a review step where the inspector chooses Keep mine, Keep theirs, or Keep both; photos with different content are always kept side by side.', effect: 'Adds P02-T03, Review same-field conflicts', minutes: 155 },
    },
    'FB-003': {
        decision: 'D5', option: 'a', text: '', minutes: 120, sentMinutes: 118,
        interpretation: { text: 'Put conflict review in a Review tab inside the inspection and show the number of open conflicts on the tab.', effect: 'Updates P02-T03 Details', minutes: 116 },
    },
    'FB-006': {
        decision: 'D6', option: 'a', text: 'Version field is fine; tell the API team about the weak ETags anyway.', minutes: 58, sentMinutes: 57,
        interpretation: { text: 'Photo metadata writes send the record version field; inspection writes keep If-Match. A note to the API team about weak ETags is added as a follow-up.', effect: 'Unpauses P03-T01; AL-001 becomes a confirmed divergence', minutes: 56 },
    },
});

/**
 * @param {string} stage One of STAGES.
 * @param {number} [nowMs]
 * @returns {any} A validated session document.
 */
export function buildScenario(stage = 'implement', nowMs = Date.now()) {
    const index = PHASES.indexOf(stage);
    if (index < 0) {
        throw new Error(`Unknown stage: ${stage}`);
    }
    const reached = (phase) => PHASES.indexOf(phase) <= index;
    const passed = (phase) => PHASES.indexOf(phase) < index;
    const time = (minutes) => new Date(nowMs - Math.round(minutes * 60000)).toISOString();
    const day = time(0).slice(0, 10);
    const copy = (value) => structuredClone(value);

    const artifact = (dir, suffix) => `.copilot-tracking/${dir}/${day}/${SCENARIO_ID}-${suffix}.md`;
    const phases = {
        research: { title: 'Research', artifact: artifact('research', 'research') },
        plan: { title: 'Plan', artifact: artifact('plans', 'plan') },
        implement: { title: 'Changes', artifact: artifact('changes', 'changes') },
        review: { title: 'Review', artifact: artifact('reviews/logs', 'review') },
        followup: { title: 'Follow-up', artifact: null },
    };
    const updated = { research: 150, plan: 110, implement: 2, review: 9, followup: 1 };
    for (const phase of PHASES) {
        phases[phase].status = passed(phase) ? 'done' : phase === stage ? 'active' : 'upcoming';
        phases[phase].updatedAt = reached(phase) ? time(updated[phase]) : null;
        if (!reached(phase)) {
            phases[phase].artifact = null;
        }
    }

    const sections = {};
    const addSections = (source, doc, minutes) => {
        for (const [id, section] of Object.entries(source)) {
            sections[id] = { id, doc, title: section.title, markdown: section.markdown, revision: 1, editedBy: 'agent', updatedAt: time(minutes) };
        }
    };
    addSections(research.sections, 'research', 150);
    if (reached('plan')) addSections(plan.sections, 'plan', 110);
    if (reached('implement')) addSections(implement.sections, 'implement', 4);
    if (reached('review')) addSections({ 'review-summary': review.sections['review-summary'] }, 'review', 12);
    if (reached('followup')) addSections({ 'followup-summary': review.sections['followup-summary'] }, 'followup', 2);

    const lanes = copy(research.lanes).map((lane) => ({ ...lane, createdAt: time(170), updatedAt: time(lane.status === 'done' ? 165 : 4) }));
    if (passed('research')) {
        lanes[0].status = 'done';
        lanes[0].summary = 'Measured on three test devices: the quota held about 20 visits. Requesting persistence is still advised (R1).';
    }
    const questions = copy(research.questions);
    if (stage === 'research') {
        questions[1].status = 'open';
    }

    const decisions = copy(research.decisions);
    const feedback = copy(research.feedback);
    if (reached('plan')) decisions.push(...copy(plan.decisions));
    if (reached('implement')) decisions.push(...copy(implement.decisions));

    const answer = (id) => {
        const spec = ANSWERS[id];
        const decision = decisions.find((d) => d.id === spec.decision);
        const option = decision.options.find((o) => o.id === spec.option);
        decision.status = 'resolved';
        decision.chosen = spec.option;
        decision.feedbackId = id;
        feedback.push({ id, kind: 'answer', state: 'applied', target: { id: decision.id, type: 'decision', phase: decision.phase }, optionId: option.id, optionLabel: option.label, text: spec.text, delivery: 'queue', minutes: spec.minutes, sentMinutes: spec.sentMinutes, interpretation: spec.interpretation });
    };
    if (passed('research')) {
        const d4 = decisions.find((d) => d.id === 'D4');
        d4.status = 'resolved';
        feedback[0].state = 'applied';
        answer('FB-002');
    }
    if (passed('plan')) answer('FB-003');
    if (reached('implement')) feedback.push(...copy(implement.feedback));
    if (passed('implement')) {
        answer('FB-006');
        const comment = feedback.find((f) => f.id === 'FB-004');
        comment.state = 'applied';
        comment.interpretation = { text: 'Autosave now waits 500 ms after the last change.', effect: 'Updated the autosave in CH-002', minutes: 30 };
        const request = feedback.find((f) => f.id === 'FB-005');
        request.state = 'applied';
        request.sentMinutes = 2.5;
        request.interpretation = { text: 'Started research lane L3 on iOS storage pressure for installed web apps.', effect: 'Adds L3 to Research', minutes: 2 };
        request.minutes = 3;
        lanes.push({ id: 'L3', question: request.text, status: 'running', effort: 'max', origin: 'FB-005', findingId: 'F1', createdAt: time(2), updatedAt: time(1) });
    }
    const feedbackItems = feedback.map(({ minutes, sentMinutes, interpretation, ...item }) => {
        const result = { ...item, createdAt: time(minutes), updatedAt: time(interpretation?.minutes ?? sentMinutes ?? minutes), history: [{ state: 'queued', by: 'user', at: time(minutes) }] };
        if (sentMinutes !== undefined && item.state !== 'queued') {
            result.sentAt = time(sentMinutes);
            result.history.push({ state: 'sent', by: item.delivery === 'queue' ? 'agent' : 'user', at: time(sentMinutes) });
        }
        if (interpretation) {
            result.interpretation = { text: interpretation.text, effect: interpretation.effect, at: time(interpretation.minutes) };
            result.history.push({ state: 'interpreted', by: 'agent', at: time(interpretation.minutes) });
            if (item.state === 'applied') {
                result.history.push({ state: 'applied', by: 'user', at: time(Math.max(interpretation.minutes - 1, 0)) });
            }
        }
        return result;
    });

    const planPhases = reached('plan') ? copy(plan.phases) : [];
    for (const phase of planPhases) {
        for (const task of phase.tasks) {
            if (stage === 'implement') {
                task.status = implement.taskStatus[task.id];
            } else if (passed('implement')) {
                task.status = 'done';
            }
        }
        phase.status = phase.tasks.every((t) => t.status === 'done') ? 'done' : phase.tasks.some((t) => t.status !== 'todo') ? 'in-progress' : 'todo';
    }
    const findTask = (id) => planPhases.flatMap((p) => p.tasks).find((t) => t.id === id);
    if (stage === 'plan') findTask('P02-T03').decisionId = 'D5';
    if (stage === 'implement') {
        findTask('P03-T01').decisionId = 'D6';
        findTask('P03-T01').guidance = ['Reuse retryWithBackoff from src/net/retry.ts; it already honors Retry-After.'];
    }

    const stamp = (items) => items.map(({ minutes, ...item }) => ({ ...item, at: time(minutes) }));
    let implementation = { current: null, activity: [], changes: [], discoveries: [], alignment: [], validation: [], blockers: [] };
    if (stage === 'implement') {
        implementation = {
            current: { taskId: 'P02-T02', startedAt: time(16) },
            activity: stamp(copy(implement.activity)),
            changes: stamp(copy(implement.changes)),
            discoveries: stamp(copy(implement.discoveries)),
            alignment: copy(implement.alignment),
            validation: copy(implement.validation),
            blockers: copy(implement.blockers),
        };
    } else if (passed('implement')) {
        const validation = copy(implement.validation).map((row) => (row.status === 'passed' ? row : { ...row, status: 'passed', summary: row.check.startsWith('iOS') ? 'Passed when the lab returned' : '19 tests' }));
        implementation = {
            current: null,
            activity: stamp([...copy(implement.activity), { kind: 'note', text: 'Finished P04-T02; all tasks complete', minutes: 20 }]),
            changes: stamp([...copy(implement.changes), ...copy(implement.laterChanges)]),
            discoveries: stamp(copy(implement.discoveries)),
            alignment: copy(implement.alignment).map((entry) => ({ ...entry, alignment: 'divergence-confirmed' })),
            validation,
            blockers: [],
        };
    }

    const reviewDoc = reached('review')
        ? { execution: review.review.execution, outcome: review.review.outcome, depth: review.review.depth, findings: copy(review.review.findings), history: stamp(copy(review.review.history)), validation: copy(review.review.validation) }
        : { execution: null, outcome: null, depth: null, findings: [], history: [], validation: [] };
    // Before Follow-up, the session holds only this task, still running.
    const followUps = reached('followup')
        ? copy(review.followUps)
        : { items: [], tree: { ...copy(review.followUps.tree), tasks: copy(review.followUps.tree.tasks.slice(0, 1)).map((task) => ({ ...task, status: 'running' })) } };

    const checklistFor = (phase, list) => copy(list).map((item) => (passed(phase) ? { ...item, checked: true } : item));
    const session = {
        format: SESSION_FORMAT,
        version: SESSION_VERSION,
        id: SCENARIO_ID,
        revision: 1,
        updatedAt: time(0),
        scenario: { id: SCENARIO_ID, stage, sample: true },
        task: { id: SCENARIO_ID, title: 'Offline drafts with background sync', repository: 'contoso/field-inspections', branch: 'feat/offline-drafts', parent: null },
        session: {
            mode: 'automatic',
            activePhase: stage,
            status: stage === 'followup' ? 'completed' : 'active',
            sessionStatus: 'running',
            nextAction: NEXT_ACTION[stage],
            participation: { research: 'user-retained', plan: 'user-retained', review: 'agent-owned', followup: 'agent-owned' },
            boundary: 'through-review',
        },
        phases,
        sections,
        research: {
            questions,
            findings: copy(research.findings),
            evidence: copy(research.evidence),
            alternatives: copy(research.alternatives),
            risks: copy(research.risks),
            lanes,
            readiness: stage === 'research' ? { status: 'not-ready', text: 'Not ready: D2 needs your answer before planning.' } : { status: 'ready', text: 'Ready: every question is answered with evidence and every decision is settled.' },
        },
        plan: reached('plan')
            ? {
                phases: planPhases,
                requirements: copy(plan.requirements),
                diagram: copy(plan.diagram),
                critique: copy(plan.critique),
                readiness: stage === 'plan' ? { status: 'not-ready', text: 'Not ready: D5 needs your answer.' } : { status: 'ready', text: 'Ready: the critique findings are resolved and every decision is settled.' },
            }
            : { phases: [], requirements: [], diagram: null, critique: null, readiness: null },
        implementation,
        review: reviewDoc,
        followUps,
        decisions,
        feedback: feedbackItems,
        links: [],
        checklists: {
            research: checklistFor('research', research.checklist),
            plan: reached('plan') ? checklistFor('plan', plan.checklist) : [],
            implement: reached('implement') ? checklistFor('implement', implement.checklist) : [],
            review: reached('review') ? checklistFor('review', review.checklists.review) : [],
            followup: reached('followup') ? copy(review.checklists.followup) : [],
        },
    };
    session.links = LINKS.filter(([from, to]) => findItem(session, from) && findItem(session, to)).map((pair) => [...pair]);
    return validateSession(session);
}
