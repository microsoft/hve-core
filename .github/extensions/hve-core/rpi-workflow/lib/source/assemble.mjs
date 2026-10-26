// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';

import { checklistFor, verdictOf } from '../checklists.mjs';
import { PHASES, SESSION_FORMAT, SESSION_VERSION, validateSession } from '../model.mjs';
import { idsIn, labelKey, linksIn, listItems, plainText } from './markdown.mjs';
import { stateDecision } from './parse.mjs';

/**
 * Builds a canvas session document from one task's parsed RPI artifacts. Every list the
 * views read is present, every status word is mapped into the canvas vocabulary (unknown
 * words map to a neutral value and add a warning), and section IDs use the keys the views
 * render. Times the artifacts do not record stay absent.
 */

const TASK_ID = /^P\d{2}-T\d{2}$/;
const PHASE_NAMES = { research: 'research', plan: 'plan', implement: 'implement', implementation: 'implement', review: 'review', 'follow-up': 'followup', followup: 'followup' };
const PHASE_TITLES = { research: 'Research', plan: 'Plan', implement: 'Changes', review: 'Review', followup: 'Follow-up' };
const pad = (n) => String(n).padStart(3, '0');
const fingerprint = (value) => createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex').slice(0, 24);
const NONE_RE = /^(?:none|none yet|not applicable|n\/a)\.?$/i;

/** Canvas phase key for a state's phase name, or null. */
export const phaseKey = (value) => PHASE_NAMES[labelKey(value)] ?? null;

/** The earliest-mentioned state wins, so "Evidence-backed for X; partially supported for Y" reads as evidence-backed. */
export function evidenceStateOf(text) {
    const value = String(text ?? '').toLowerCase();
    const candidates = [
        ['evidence-backed', /evidence[- ]backed/],
        ['partially-supported', /partial/],
        ['hypothesis', /hypothes|conjectur/],
        ['weakened', /weaken|disprov/],
        ['unresolved', /unresolved/],
    ].map(([state, re]) => [state, value.search(re)]).filter(([, at]) => at >= 0).sort((a, b) => a[1] - b[1]);
    return candidates[0]?.[0] ?? null;
}

export function confidenceOf(text) {
    const match = /^(very high|medium-high|medium-low|high|medium|low)\b/i.exec(plainText(text));
    return match ? match[1].toLowerCase() : null;
}

export function questionStatusOf(text) {
    const value = labelKey(text);
    if (value.startsWith('answered')) return 'answered';
    if (value.startsWith('blocked')) return 'blocked';
    return 'open';
}

export function alternativeOf(text) {
    return /^(selected|rejected|deferred|viable)/i.exec(labelKey(text))?.[1].toLowerCase() ?? 'viable';
}

export function priorityOf(text) {
    const value = labelKey(text);
    if (/^(h|high|critical)\b/.test(value)) return 'H';
    if (/^(l|low)\b/.test(value)) return 'L';
    return 'M';
}

/** Validation status, or null when the text names none. */
export function validationOf(text) {
    const value = labelKey(text);
    if (/^pass|^ok\b|^succeeded/.test(value)) return 'passed';
    if (/fail/.test(value)) return 'failed';
    if (/^skip/.test(value)) return 'skipped';
    if (/unavailable|not run|n\/a|blocked/.test(value)) return 'unavailable';
    return null;
}

export function severityOf(text) {
    const value = labelKey(text);
    return ['critical', 'high', 'medium', 'low'].includes(value) ? value : 'low';
}

export function routeOf(text) {
    const value = labelKey(text);
    if (value.includes('implement')) return 'rpi-implement';
    if (value.includes('plan')) return 'rpi-plan';
    if (value.includes('research')) return 'rpi-research';
    if (value.includes('follow')) return 'follow-up';
    return 'none';
}

/** Review finding decision for a history status, or null when the status is not one. */
export function findingDecisionOf(text) {
    const value = labelKey(text);
    if (/^accept/.test(value)) return 'accepted';
    if (/^reject/.test(value)) return 'rejected';
    if (/^defer/.test(value)) return 'deferred';
    if (/^(resolv|fixed|closed)/.test(value)) return 'resolved';
    if (/^propos/.test(value)) return 'proposed';
    return null;
}

export function critiqueDispositionOf(text) {
    const value = labelKey(text);
    if (value.startsWith('resolv')) return 'resolved';
    if (value.startsWith('accept')) return 'accepted with risk';
    if (value.startsWith('supersed')) return 'superseded';
    return 'open';
}

export function alignmentOf(text) {
    const value = labelKey(text);
    return ['divergence-confirmed', 'source-gap', 'pending-decision'].find((key) => value.includes(key)) ?? 'clarification';
}

export function readinessOf(text) {
    const value = labelKey(text);
    if (/not ready|blocked|needs clarification/.test(value)) return 'not-ready';
    return /\bready\b/.test(value) ? 'ready' : 'not-ready';
}

/** Status of a decision row: needs the user, decided by the agent, or settled. */
function decisionStatusOf(status, owner) {
    const value = labelKey(status);
    if (/unresolved|input requested|needs input/.test(value) || (owner === 'user' && /propos/.test(value))) return 'needs-input';
    if (/defer/.test(value)) return 'resolved';
    return owner === 'agent' ? 'decided' : 'resolved';
}

const truncate = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);
const realItems = (block) => listItems(block).filter((item) => !NONE_RE.test(plainText(item)));
const joinedText = (block) => plainText(realItems(block).join(' ')) || plainText(block);

/** Node IDs a Mermaid flowchart declares. */
function nodeIds(source) {
    const ids = new Set();
    for (const line of String(source ?? '').split('\n')) {
        const match = /^\s*([A-Za-z][\w-]*)\s*\[/.exec(line);
        if (match) ids.add(match[1]);
    }
    return ids;
}

/** Nodes a phase highlights: backticked IDs in "Highlighted work", else non-`new` class members in its diagram. */
function highlightedNodes(phase, afterNodes) {
    const named = [...String(phase.highlighted ?? '').matchAll(/`([A-Za-z][\w-]*)`/g)].map((match) => match[1]).filter((id) => afterNodes.has(id));
    if (named.length) return named;
    const classed = [];
    for (const line of String(phase.diagram ?? '').split('\n')) {
        const match = /^\s*class\s+([\w,-]+)\s+([\w-]+)\s*$/.exec(line);
        if (match && match[2] !== 'new') classed.push(...match[1].split(',').filter((id) => afterNodes.has(id)));
    }
    return [...new Set(classed)];
}

function lower(value) {
    return typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : null;
}

/**
 * Lineage status for a task state: completed, running, or stopped.
 *
 * @param {{ status: string | null, sessionStatus: string | null }} state
 */
export function lineageStatusOf(state) {
    if (lower(state.status) === 'completed') return 'completed';
    return lower(state.sessionStatus) === 'running' ? 'running' : 'stopped';
}

/**
 * @typedef {object} AssembleInput
 * @property {string} id Session document ID.
 * @property {ReturnType<typeof import('./parse.mjs').parseState>} state
 * @property {{ research?: any, plan?: any, critique?: any, changes?: any, review?: any }} artifacts Parsed artifacts whose kind matches their state key.
 * @property {{ key: string, path: string, kind: string | null }[]} [mismatched] State paths whose artifact is another kind, such as reused research.
 * @property {string} statePath Workspace-relative state path.
 * @property {Record<string, { path: string, mtimeMs: number } | undefined>} [files] File facts by state key, plus `state`.
 * @property {{ taskId: string, title: string, relation: 'parent' | 'this' | 'child', status: string }[]} [lineage]
 * @property {{ repository: string | null, branch: string | null } | null} [git]
 * @property {string | null} [root] Absolute workspace root.
 * @property {string} now ISO timestamp.
 */

/**
 * Builds a validated canvas session document for one task.
 *
 * @param {AssembleInput} input
 * @returns {{ session: any, warnings: string[] }}
 */
export function assembleSession(input) {
    const { state, artifacts = {}, mismatched = [], files = {}, lineage = [], git = null, root = null, now } = input;
    const { research, plan, critique, changes, review } = artifacts;
    const warnings = [...state.warnings];
    for (const parsed of [research, plan, critique, changes, review]) {
        if (parsed) warnings.push(...parsed.warnings.map((text) => `${PHASE_TITLES[parsed.kind === 'critique' ? 'plan' : parsed.kind === 'changes' ? 'implement' : parsed.kind] ?? parsed.kind}: ${text}`));
    }
    const at = (key) => (files[key]?.mtimeMs ? new Date(files[key].mtimeMs).toISOString() : null);
    const sections = {};
    const addSection = (id, doc, title, markdown, key) => {
        if (typeof markdown === 'string' && markdown.trim()) {
            sections[id] = { id, doc, title, markdown, revision: 1, editedBy: 'agent', updatedAt: at(key) ?? now, sourceHash: fingerprint(markdown) };
        }
    };

    // Research
    const evidence = (research?.evidence ?? []).map((row) => {
        const link = linksIn(row.source)[0];
        const url = link?.href ?? /https?:\/\/[^\s)>\]]+/.exec(row.source)?.[0] ?? null;
        return {
            id: row.id,
            kind: row.id.startsWith('W') ? 'web' : 'code',
            claim: plainText(row.claim),
            source: plainText(row.source),
            ...(url && /^https?:\/\//.test(url) ? { url } : {}),
            ...(/^\d{4}-\d{2}-\d{2}/.test(row.retrieved) ? { retrieved: row.retrieved.slice(0, 10) } : {}),
            confidence: lower(row.confidence) ?? 'not recorded',
        };
    });
    const evidenceIds = new Set(evidence.map((item) => item.id));
    const findings = (research?.findings ?? []).map((finding, index) => {
        const state = evidenceStateOf(finding.evidenceState);
        if (!state && finding.evidenceState) warnings.push(`Research: finding "${truncate(finding.title, 60)}" has an unrecognized evidence state.`);
        addSection(`finding-f${index + 1}`, 'research', finding.title, finding.body, 'research');
        return { id: `F${index + 1}`, title: finding.title, state: state ?? 'unresolved', confidence: confidenceOf(finding.confidence), questions: finding.questions, evidence: finding.evidence };
    });
    const researchReused = !research && (/reused|satisfied/i.test(stateDecision(state, 'Research disposition')?.status ?? '') || mismatched.some((item) => item.key === 'research'));
    if (research) {
        addSection('research-summary', 'research', 'Summary', research.summary, 'research');
        addSection('research-unknowns', 'research', 'What you may not know', research.unknowns, 'research');
        addSection('research-recommendation', 'research', 'Recommendation', research.recommendation, 'research');
    } else if (researchReused) {
        const reused = mismatched.find((item) => item.key === 'research')?.path ?? state.artifacts.research;
        const note = stateDecision(state, 'Research disposition')?.evidence;
        addSection('research-summary', 'research', 'Summary', [`This task reused existing evidence instead of running new research${reused ? `: \`${reused}\`` : ''}.`, note ? `\n${note}` : ''].join(''), 'research');
    }

    // Plan
    const active = phaseKey(state.activePhase) ?? (review ? 'review' : changes ? 'implement' : plan ? 'plan' : 'research');
    const running = lower(state.sessionStatus) === 'running';
    const allTasks = (plan?.phases ?? []).flatMap((phase) => phase.tasks);
    const currentTask = active === 'implement' && running ? allTasks.find((task) => !task.checked)?.id ?? null : null;
    const afterNodes = nodeIds(plan?.after);
    const planPhases = (plan?.phases ?? []).map((phase) => {
        const tasks = phase.tasks.map((task) => {
            const sectionId = `task-${task.id.toLowerCase()}`;
            const parts = [task.details];
            if (task.requirements) parts.push('**Requirements**', task.requirements);
            if (realItems(task.references).length) parts.push('**References**', task.references);
            addSection(sectionId, 'plan', `${task.id}: ${task.title}`, parts.filter(Boolean).join('\n\n'), 'plan');
            const guidance = realItems(task.guidance).map(plainText);
            return {
                id: task.id,
                title: task.title,
                goals: joinedText(task.goals),
                requirements: idsIn(task.requirements, /^N?FR-\d{3}$/),
                details: realItems(task.details).map(plainText),
                dependencies: idsIn(task.dependencies, /^P\d{2}(?:-T\d{2})?$/),
                references: realItems(task.references).map(plainText),
                status: task.checked ? 'done' : task.id === currentTask ? 'in-progress' : 'todo',
                sectionId,
                ...(guidance.length ? { guidance } : {}),
            };
        });
        const status = tasks.length
            ? tasks.every((task) => task.status === 'done') ? 'done' : tasks.some((task) => task.status !== 'todo') ? 'in-progress' : 'todo'
            : phase.checked ? 'done' : 'todo';
        return { id: phase.id, title: phase.title, goals: joinedText(phase.goals), status, tasks };
    });
    const dispositions = new Map((plan?.critique.dispositions ?? []).map((row) => [row.finding, row]));
    const critiqueSkipped = /skip/i.test(plan?.critique.status ?? '') || /^skip/i.test(plan?.critique.setting ?? '');
    const verdictOf = (text) => /\b(Pass|Revise|Blocked|Block|Fail)\b/i.exec(plainText(text))?.[1] ?? null;
    if (plan) {
        addSection('plan-summary', 'plan', 'Summary', plan.summary, 'plan');
        addSection('plan-unknowns', 'plan', 'What you may not know', plan.unknowns, 'plan');
    }

    // Implementation
    const changeList = (changes?.entries ?? []).map((entry, index) => ({
        id: `CH-${pad(index + 1)}`,
        taskId: entry.taskId,
        title: entry.title,
        behavior: entry.behavior,
        files: entry.files.map((path) => ({ path, kind: 'changed', additions: null, deletions: null, diff: '' })),
        validation: [],
        validationText: entry.validation,
        related: entry.ids.filter((id) => id !== entry.taskId),
        at: null,
    }));
    const discoveries = [
        ...(changes?.planUpdates ?? []).map((update) => ({ kind: 'plan-change', title: update.title, detail: plainText(update.markdown), taskId: idsIn(`${update.title} ${update.area} ${update.markdown}`, TASK_ID)[0] ?? null })),
        ...(changes?.followUps ?? []).map((item) => ({ kind: 'follow-up', title: truncate(plainText(item), 120), detail: plainText(item).length > 120 ? plainText(item) : '', taskId: idsIn(item, TASK_ID)[0] ?? null })),
    ].map((item, index) => ({ id: `DS-${pad(index + 1)}`, decisionId: null, planUpdate: null, at: null, ...item }));
    const validationRows = (rows, source) => rows.map((row) => {
        const status = validationOf(row.status);
        if (!status) warnings.push(`${source}: validation "${truncate(row.check, 60)}" has an unrecognized status "${row.status}".`);
        return { check: row.check, scope: row.scope ?? '', status: status ?? 'unavailable', summary: plainText(row.summary) };
    });
    const blockers = [...(changes?.blockers ?? []), ...state.blockers.map((item) => item.summary)].filter(Boolean).map((text, index) => ({
        id: `B${index + 1}`,
        taskId: idsIn(text, TASK_ID)[0] ?? null,
        text: plainText(text),
        owner: '',
        clear: '',
    }));
    if (changes) addSection('changes-summary', 'implement', 'Summary', changes.summary, 'changes');

    // Review
    const history = (review?.history ?? []).map((event) => ({ id: event.id, subject: event.subject, status: event.status, owner: event.owner, rationale: plainText(event.rationale), at: null }));
    const decisionFor = (findingId) => {
        for (const event of [...(review?.history ?? [])].reverse()) {
            if (idsIn(event.subject, /^RV-\d{3}$/).includes(findingId)) {
                const decision = findingDecisionOf(event.status);
                if (decision) return decision;
            }
        }
        return 'proposed';
    };
    if (review) {
        addSection('review-summary', 'review', 'Assessment', [review.summary, review.unknowns ? `**What you may not know**\n\n${review.unknowns}` : ''].filter(Boolean).join('\n\n'), 'review');
    }
    const followupNote = review?.disposition || state.nextAction?.action || '';
    addSection('followup-summary', 'followup', 'Follow-up', followupNote, 'state');

    // Decisions
    const toDecision = (row, phase, prefix) => {
        let owner = /^user/i.test(row.owner) ? 'user' : 'agent';
        const status = decisionStatusOf(row.status, owner);
        if (status === 'needs-input') owner = 'user';
        const label = truncate(plainText(row.item), 200);
        const settled = status !== 'needs-input';
        const decision = {
            id: `${prefix}${row.id}`,
            ref: row.id,
            phase,
            owner,
            status,
            title: label,
            question: settled ? '' : plainText(row.rationale) || label,
            context: '',
            rationale: settled ? plainText(row.rationale) : '',
            impact: plainText(row.impact),
            evidence: row.evidence.filter((id) => evidenceIds.has(id)),
            anchor: { phase, rowId: `${phase}-decisions` },
            options: settled ? [{ id: 'a', label: /defer/i.test(row.status) ? `Deferred: ${label}` : label }] : [],
            ...(settled ? { chosen: 'a' } : {}),
            origin: 'artifact',
        };
        return { ...decision, base: fingerprint(decision) };
    };
    const decisions = [
        ...(research?.decisions ?? []).map((row) => toDecision(row, 'research', '')),
        ...(plan?.decisions ?? []).map((row) => toDecision(row, 'plan', 'plan.')),
    ];

    // Phases
    const activeIndex = PHASES.indexOf(active);
    const completed = lower(state.status) === 'completed';
    const reviewSkipped = !review && /skip/i.test(stateDecision(state, 'Review step')?.status ?? '');
    const phaseStatus = (phase, index) => {
        if (index < activeIndex) {
            if (phase === 'research' && researchReused) return 'skipped';
            if (phase === 'review' && reviewSkipped) return 'skipped';
            return 'done';
        }
        if (index === activeIndex) {
            if (lower(state.status) === 'blocked') return 'blocked';
            if (completed && (phase !== 'followup' || !running)) return 'done';
            return 'active';
        }
        return 'upcoming';
    };
    const artifactPath = { research: state.artifacts.research, plan: state.artifacts.plan, implement: state.artifacts.changes, review: state.artifacts.review, followup: input.statePath };
    const updated = { research: at('research'), plan: at('plan'), implement: at('changes'), review: at('review'), followup: at('state') };
    const phases = Object.fromEntries(PHASES.map((phase, index) => [phase, { title: PHASE_TITLES[phase], artifact: artifactPath[phase] ?? null, status: phaseStatus(phase, index), updatedAt: updated[phase] }]));

    const session = {
        format: SESSION_FORMAT,
        version: SESSION_VERSION,
        id: input.id,
        revision: 1,
        updatedAt: now,
        source: {
            kind: 'rpi',
            root,
            taskId: state.taskId,
            statePath: input.statePath,
            artifacts: { ...state.artifacts },
            importedAt: now,
            warnings,
        },
        task: {
            id: state.taskId,
            title: plan?.title || changes?.title || review?.title || research?.title || state.taskId,
            repository: git?.repository ?? null,
            branch: git?.branch ?? null,
            parent: state.parent?.taskId ?? null,
        },
        session: {
            mode: lower(state.mode) ?? 'manual',
            activePhase: active,
            status: lower(state.status) ?? 'active',
            sessionStatus: lower(state.sessionStatus) ?? 'stopped',
            nextAction: state.nextAction?.action || '',
            participation: {
                research: stateDecision(state, 'Research decision participation')?.status ?? null,
                plan: stateDecision(state, 'Planning decision participation')?.status ?? null,
                review: stateDecision(state, 'Review decision participation')?.status ?? null,
                followup: stateDecision(state, 'Follow-up decision participation')?.status ?? null,
            },
            boundary: stateDecision(state, 'Automatic progression boundary')?.status ?? null,
        },
        phases,
        sections,
        research: {
            questions: (research?.questions ?? []).map((question) => ({ id: question.id, text: plainText(question.text), status: questionStatusOf(question.status), findings: findings.filter((finding) => finding.questions.includes(question.id)).map((finding) => finding.id) })),
            findings,
            evidence,
            alternatives: (research?.alternatives ?? []).map((row) => ({ option: row.option, benefits: plainText(row.benefits), costs: plainText(row.costs), evidence: row.evidence, disposition: alternativeOf(row.disposition) })),
            risks: (research?.risks ?? []).map((row, index) => ({ id: `R${index + 1}`, priority: priorityOf(row.priority), type: row.type, text: plainText(row.text), impact: plainText(row.impact), action: plainText(row.action), owner: row.owner })),
            lanes: [],
            readiness: research?.readiness ? { status: readinessOf(research.readiness), text: plainText(research.readiness) } : null,
        },
        plan: plan
            ? {
                phases: planPhases,
                requirements: plan.requirements.map((row) => ({ id: row.id, kind: row.kind, text: plainText(row.text) })),
                diagram: plan.after ? { before: plan.before, after: plan.after, phaseNodes: Object.fromEntries(plan.phases.map((phase) => [phase.id, highlightedNodes(phase, afterNodes)])) } : null,
                critique: critique || plan.critique.status || plan.critique.setting
                    ? {
                        status: critique?.execution || plan.critique.status || 'Not recorded',
                        verdict: critiqueSkipped && !critique ? 'Skipped' : critique?.verdict || verdictOf(plan.critique.latest) || 'Not recorded',
                        setting: (plan.critique.setting || critique?.depth || 'not recorded').split(';')[0].trim(),
                        findings: (critique?.findings ?? []).map((finding) => ({
                            id: finding.id,
                            severity: severityOf(finding.severity),
                            title: finding.title,
                            disposition: critiqueDispositionOf(dispositions.get(finding.id)?.disposition),
                            related: finding.related,
                            response: plainText(dispositions.get(finding.id)?.response ?? ''),
                        })),
                    }
                    : null,
                readiness: plan.readiness ? { status: readinessOf(plan.readiness), text: plainText(plan.readiness) } : null,
            }
            : { phases: [], requirements: [], diagram: null, critique: null, readiness: null },
        implementation: {
            current: currentTask ? { taskId: currentTask, startedAt: null } : null,
            activity: [],
            changes: changeList,
            discoveries,
            alignment: (changes?.alignment ?? []).map((entry, index) => ({ id: `AL-${pad(index + 1)}`, source: entry.source, document: entry.document, status: entry.status, requirement: entry.requirement, owner: entry.owner, marker: entry.marker, change: plainText(entry.change), why: plainText(entry.why), decision: entry.decision, alignment: alignmentOf(entry.alignment) })),
            validation: validationRows(changes?.validation ?? [], 'Changes'),
            blockers,
        },
        review: review
            ? {
                execution: review.execution || null,
                outcome: review.outcome || null,
                depth: null,
                findings: review.findings.map((finding) => ({
                    id: finding.id,
                    severity: severityOf(finding.severity),
                    title: finding.title,
                    summary: '',
                    expected: plainText(finding.expected),
                    observed: finding.observed,
                    impact: plainText(finding.impact),
                    resolution: plainText(finding.resolution),
                    route: routeOf(finding.destination),
                    decision: decisionFor(finding.id),
                    related: finding.related,
                })),
                history,
                validation: validationRows(review.validation, 'Review'),
            }
            : { execution: null, outcome: null, depth: null, findings: [], history: [], validation: [] },
        followUps: {
            items: state.followUps.map((item) => ({
                rank: item.rank,
                id: `FU-${item.rank}`,
                title: plainText(item.task),
                rationale: plainText(item.rationale),
                evidence: item.evidence,
                required: /^required/i.test(item.rationale.trim()),
                status: /assigned to child/i.test(item.task) ? 'in-progress' : 'proposed',
            })),
            lineage: lineage.map((item) => ({ id: item.taskId, title: item.title, relation: item.relation, status: item.status })),
        },
        records: {
            research: research?.other ?? [],
            plan: [...(plan?.other ?? []), ...(critique?.other ?? []).map((record) => ({ ...record, heading: `Critique: ${record.heading}` }))],
            implement: changes?.other ?? [],
            review: review?.other ?? [],
            followup: [],
        },
        decisions,
        feedback: [],
        links: [],
        checklists: {
            research: research || researchReused ? checklistFor('research') : [],
            plan: plan ? checklistFor('plan') : [],
            implement: changes ? checklistFor('implement') : [],
            review: review ? checklistFor('review') : [],
            followup: activeIndex >= PHASES.indexOf('followup') ? checklistFor('followup') : [],
        },
    };
    return { session: validateSession(session), warnings };
}

/** JSON with sorted keys, so key order never counts as a change. */
function stable(value) {
    if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
    if (value && typeof value === 'object') {
        return `{${Object.keys(value).filter((key) => value[key] !== undefined).sort().map((key) => `${JSON.stringify(key)}:${stable(value[key])}`).join(',')}}`;
    }
    return JSON.stringify(value) ?? 'null';
}

/** The document without fields that change on every import, for change detection. */
function comparable(session) {
    const { revision: _revision, updatedAt: _updatedAt, ...rest } = session;
    return stable({ ...rest, source: { ...rest.source, importedAt: null } });
}

/**
 * Merges a fresh import into the stored document. Document data comes from the import;
 * what the person added in the canvas stays:
 * feedback, checklists, research lanes, activity, decisions created in the canvas, and
 * the change count. A section whose source text is unchanged keeps the stored version,
 * including a saved edit still waiting for the agent; a changed section takes the new
 * text and a higher revision, so an open editor sees a conflict on save. An imported
 * decision whose imported content is unchanged keeps its stored answer state. Returns
 * `stored` itself when nothing changed, so the store writes nothing.
 *
 * @param {any | null | undefined} stored
 * @param {any} imported
 * @param {string} now ISO timestamp.
 */
export function mergeImport(stored, imported, now) {
    if (!stored) return imported;
    const sections = {};
    for (const [id, fresh] of Object.entries(imported.sections)) {
        const previous = Object.prototype.hasOwnProperty.call(stored.sections, id) ? stored.sections[id] : null;
        // Text a user edited before edits became suggestions gives way to the file.
        if (previous && previous.sourceHash === fresh.sourceHash && previous.editedBy !== 'user') {
            sections[id] = previous;
        } else {
            sections[id] = previous ? { ...fresh, revision: (previous.revision ?? 0) + 1, updatedAt: now } : fresh;
        }
    }
    const storedDecisions = new Map(stored.decisions.map((decision) => [decision.id, decision]));
    const decisions = imported.decisions.map((fresh) => {
        const previous = storedDecisions.get(fresh.id);
        return previous && previous.origin === 'artifact' && previous.base === fresh.base ? previous : fresh;
    });
    const importedIds = new Set(imported.decisions.map((decision) => decision.id));
    decisions.push(...stored.decisions.filter((decision) => decision.origin !== 'artifact' && !importedIds.has(decision.id)));
    // Labels follow the current checklist; verdicts and notes the person gave carry over by item ID.
    const checklists = Object.fromEntries(Object.entries(imported.checklists).map(([phase, list]) => {
        const kept = new Map((stored.checklists?.[phase] ?? []).map((item) => [item.id, item]));
        return [phase, list.map((item) => {
            const verdict = verdictOf(kept.get(item.id));
            const note = verdict === 'needs-work' ? kept.get(item.id).note : undefined;
            return verdict ? { ...item, verdict, ...(note ? { note } : {}) } : item;
        })];
    }));
    const merged = {
        ...imported,
        ...(stored.scenario ? { scenario: stored.scenario } : {}),
        revision: stored.revision,
        updatedAt: stored.updatedAt,
        sections,
        research: { ...imported.research, lanes: stored.research?.lanes ?? [] },
        implementation: { ...imported.implementation, activity: stored.implementation?.activity ?? [] },
        decisions,
        feedback: stored.feedback,
        checklists,
    };
    if (comparable(merged) === comparable(stored)) return stored;
    return validateSession({ ...merged, revision: stored.revision + 1, updatedAt: now });
}
