// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import {
    bodyOf,
    checkboxHeading,
    codeBlocks,
    field,
    findSection,
    idsIn,
    labeledFields,
    labelKey,
    linksIn,
    listItems,
    parseDocument,
    plainText,
    sectionsAt,
    severityHeading,
    tableWith,
    titleOf,
    withoutFields,
    withoutTables,
} from './markdown.mjs';

/**
 * Parsers for RPI artifacts: session state, research, plan, plan critique, changes, and
 * review. Each returns plain values with Markdown strings and the artifact's own words
 * for statuses; mapping into the canvas vocabulary happens in assemble.mjs. A missing
 * part comes back empty with a warning, and H2 sections a parser does not model come back
 * as `other` records so nothing is hidden.
 */

const KINDS = [
    ['critique', 'rpi plan critique:'],
    ['plan', 'rpi plan:'],
    ['research', 'task research:'],
    ['changes', 'rpi changes:'],
    ['review', 'review:'],
];

const EVIDENCE_ID = /^[CW]\d{1,3}$/;
const QUESTION_ID = /^Q\d{1,3}$/;
const TASK_ID = /^P\d{2}-T\d{2}$/;
const PLAN_ID = /^(?:P\d{2}(?:-T\d{2})?|FR-\d{3}|NFR-\d{3}|PC-\d{3}|CH-\d{3}|DS-\d{3})$/;
const NONE_RE = /^(?:none|none yet|not applicable|n\/a)\.?$/i;

/**
 * The artifact kind named by the first H1 heading, or null.
 *
 * @param {string} text
 * @returns {'research' | 'plan' | 'critique' | 'changes' | 'review' | null}
 */
export function artifactKind(text) {
    const title = labelKey(titleOf(parseDocument(text)));
    return /** @type {any} */ (KINDS.find(([, prefix]) => title.startsWith(prefix))?.[0] ?? null);
}

const afterColon = (title) => plainText(String(title ?? '').replace(/^[^:]*:\s*/, ''));
const realItems = (block) => listItems(block).filter((item) => !NONE_RE.test(plainText(item)));

function h2(doc, title) {
    return findSection(doc, title, { level: 2 });
}

function bodyOfH2(doc, title, options) {
    const section = h2(doc, title);
    return section ? bodyOf(doc, section, options) : '';
}

/** H2 sections the parser does not model, as Markdown records. */
function others(doc, modeled) {
    const skip = new Set(modeled.map(labelKey));
    return doc.headings
        .filter((heading) => heading.level === 2 && !skip.has(labelKey(heading.title)))
        .map((heading) => ({ heading: plainText(heading.title), markdown: bodyOf(doc, heading) }))
        .filter((record) => record.markdown.trim() !== '');
}

const str = (value) => (typeof value === 'string' && value.trim() ? value.trim() : null);
const objects = (value) => (Array.isArray(value) ? value.filter((item) => item && typeof item === 'object' && !Array.isArray(item)) : []);

/**
 * Normalizes a parsed state file. Unknown keys are ignored and missing keys come back
 * empty, so older or variant state files still load.
 *
 * @param {unknown} raw Parsed JSON.
 */
export function parseState(raw) {
    const doc = raw && typeof raw === 'object' && !Array.isArray(raw) ? /** @type {Record<string, any>} */ (raw) : {};
    const warnings = [];
    const paths = doc.artifact_paths && typeof doc.artifact_paths === 'object' ? doc.artifact_paths : {};
    const parent = doc.parent_task && typeof doc.parent_task === 'object' ? { taskId: str(doc.parent_task.task_id), taskSlug: str(doc.parent_task.task_slug) } : null;
    const ranked = objects(doc.prioritized_follow_ups);
    const followUps = (ranked.length ? ranked : objects(doc.follow_ups)).map((item, index) => ({
        rank: Number.isInteger(item.rank) ? item.rank : index + 1,
        task: str(item.task) ?? str(item.item) ?? str(item.title) ?? '',
        rationale: str(item.rationale) ?? (str(item.owner) ? `Owner: ${item.owner}` : ''),
        evidence: str(item.evidence) ?? str(item.source) ?? '',
    })).filter((item) => item.task);
    if (!str(doc.task_id)) warnings.push('The state file has no task_id.');
    return {
        taskId: str(doc.task_id),
        taskSlug: str(doc.task_slug) ?? str(doc.task_id),
        parent: parent?.taskId ? parent : null,
        mode: str(doc.mode),
        activePhase: str(doc.active_phase),
        status: str(doc.status),
        sessionStatus: str(doc.session_status),
        artifacts: Object.fromEntries(['research', 'plan', 'critique', 'changes', 'review'].map((key) => [key, str(paths[key])])),
        decisions: objects(doc.confirmed_decisions).map((item) => ({ decision: str(item.decision) ?? '', status: str(item.status) ?? '', evidence: str(item.evidence) ?? '' })),
        blockers: objects(doc.blockers).map((item, index) => ({ id: str(item.id) ?? `B${index + 1}`, summary: str(item.summary) ?? '', resolution: str(item.resolution) ?? '' })),
        nextAction: doc.next_action && typeof doc.next_action === 'object' ? { phase: str(doc.next_action.phase), action: str(doc.next_action.action) ?? '' } : null,
        followUps,
        warnings,
    };
}

/**
 * The named decision recorded in a state, compared without regard to case, or null.
 *
 * @param {ReturnType<typeof parseState>} state
 * @param {string} name
 */
export function stateDecision(state, name) {
    const key = labelKey(name);
    return state.decisions.find((item) => labelKey(item.decision) === key) ?? null;
}

/** @param {string} text */
export function parseResearch(text) {
    const doc = parseDocument(text);
    const warnings = [];
    const summary = bodyOfH2(doc, 'Executive Summary');
    if (!h2(doc, 'Executive Summary')) warnings.push('Research has no Executive Summary section.');
    const findingsSection = h2(doc, 'Findings');
    const findings = findingsSection ? sectionsAt(doc, 3, findingsSection).map((heading) => {
        const body = bodyOf(doc, heading);
        const fields = labeledFields(body);
        return {
            title: plainText(heading.title),
            body: withoutFields(body, ['Questions', 'Evidence state', 'Evidence', 'Confidence and limits']),
            questions: idsIn(field(fields, 'Questions'), QUESTION_ID),
            evidenceState: plainText(field(fields, 'Evidence state')),
            evidence: idsIn(field(fields, 'Evidence'), EVIDENCE_ID),
            confidence: plainText(field(fields, 'Confidence and limits')),
        };
    }) : [];
    const recommendationBody = bodyOfH2(doc, 'Recommendation and Alternatives');
    const alternatives = (tableWith(recommendationBody, ['Option', 'Disposition'])?.rows ?? []).map((row) => ({
        option: plainText(row.option),
        benefits: row.benefits ?? '',
        costs: row['costs and risks'] ?? '',
        evidence: idsIn(row.evidence, EVIDENCE_ID),
        disposition: plainText(row.disposition),
    }));
    const questions = (tableWith(bodyOfH2(doc, 'Scope and Questions'), ['ID', 'Question'])?.rows ?? [])
        .filter((row) => QUESTION_ID.test(row.id))
        .map((row) => ({ id: row.id, text: row.question, source: plainText(row.source), status: plainText(row.status) }));
    const decisions = (tableWith(bodyOfH2(doc, 'Decisions and Feedback'), ['Group', 'Decision or feedback item'])?.rows ?? [])
        .filter((row) => /^D\d{1,3}$/.test(row.group))
        .map((row) => ({ id: row.group, item: row['decision or feedback item'], status: plainText(row.status), owner: plainText(row.owner), rationale: row['rationale or input needed'] ?? '', evidence: idsIn(row.evidence, EVIDENCE_ID), impact: row['impact of answer'] ?? '' }));
    const risks = (tableWith(bodyOfH2(doc, 'Risks and Open Questions'), ['Priority', 'Type'])?.rows ?? []).map((row) => ({
        priority: plainText(row.priority),
        type: plainText(row.type),
        text: row['risk, question, or research item'] ?? '',
        impact: row.impact ?? '',
        action: row['smallest action or evidence needed'] ?? '',
        owner: plainText(row.owner),
    }));
    const readinessRow = (tableWith(bodyOfH2(doc, 'Planning Readiness and Next Step'), ['Field', 'Record'])?.rows ?? []).find((row) => labelKey(row.field) === 'planning readiness');
    const evidence = (tableWith(text, ['ID', 'Claim or finding'])?.rows ?? [])
        .filter((row) => EVIDENCE_ID.test(row.id))
        .map((row) => ({ id: row.id, claim: row['claim or finding'] ?? '', source: row['source or location'] ?? '', retrieved: row['retrieved and version'] ?? '', tool: plainText(row.tool), confidence: plainText(row.confidence), notes: row.notes ?? '' }));
    return {
        kind: 'research',
        title: afterColon(titleOf(doc)),
        summary,
        unknowns: bodyOfH2(doc, 'What You May Not Know'),
        findings,
        recommendation: withoutTables(recommendationBody),
        alternatives,
        questions,
        decisions,
        risks,
        readiness: readinessRow ? readinessRow.record : null,
        evidence,
        other: others(doc, ['Executive Summary', 'What You May Not Know', 'Findings', 'Recommendation and Alternatives', 'Decisions and Feedback', 'Risks and Open Questions']),
        warnings,
    };
}

/** Phases and tasks by rpi markers, or by checkbox headings when markers are missing. */
function planPhases(doc, warnings) {
    let phaseHeadings = doc.headings.filter((heading) => heading.marker?.kind === 'phase');
    let taskOf = (heading) => heading.marker?.kind === 'task';
    if (!phaseHeadings.length) {
        phaseHeadings = doc.headings.filter((heading) => /^P\d{2}$/.test(checkboxHeading(heading.title)?.id ?? ''));
        taskOf = (heading) => TASK_ID.test(checkboxHeading(heading.title)?.id ?? '');
        if (phaseHeadings.length) warnings.push('The plan has no rpi phase markers; phases were read from checkbox headings.');
    }
    return phaseHeadings.map((heading) => {
        const head = checkboxHeading(heading.title);
        const id = heading.marker?.id ?? head?.id;
        if (head && heading.marker && head.id !== heading.marker.id) warnings.push(`Plan phase heading ${head.id} sits under marker ${heading.marker.id}.`);
        const own = bodyOf(doc, heading, { own: true });
        const fields = labeledFields(own);
        const tasks = doc.headings.filter((candidate) => candidate.line > heading.line && candidate.line < heading.end && taskOf(candidate)).map((taskHeading) => {
            const taskHead = checkboxHeading(taskHeading.title);
            const body = bodyOf(doc, taskHeading);
            const taskFields = labeledFields(body);
            return {
                id: taskHeading.marker?.id ?? taskHead?.id,
                title: plainText(taskHead?.title ?? taskHeading.title),
                checked: Boolean(taskHead?.checked),
                goals: field(taskFields, 'Goals'),
                requirements: field(taskFields, 'Requirements'),
                details: field(taskFields, 'Details'),
                guidance: field(taskFields, 'Guidance'),
                references: field(taskFields, 'References'),
                dependencies: field(taskFields, 'Dependencies'),
                body,
            };
        });
        return {
            id,
            title: plainText(head?.title ?? heading.title),
            checked: Boolean(head?.checked),
            goals: field(fields, 'Goals'),
            dependencies: field(fields, 'Dependencies'),
            highlighted: field(fields, 'Highlighted work'),
            diagram: codeBlocks(own, 'mermaid')[0]?.code ?? null,
            tasks,
        };
    });
}

function requirementsFrom(block, kind) {
    const re = new RegExp(`^(${kind}-\\d{3}):\\s*([\\s\\S]*)$`);
    return listItems(block).map((item) => re.exec(item)).filter(Boolean).map((match) => ({ id: match[1], kind, text: match[2].trim() }));
}

/** @param {string} text */
export function parsePlan(text) {
    const doc = parseDocument(text);
    const warnings = [];
    const metadata = labeledFields(bodyOfH2(doc, 'Task Metadata'));
    const summarySection = h2(doc, 'Executive Summary');
    const unknownsSection = summarySection ? findSection(doc, 'What You May Not Know', { level: 3, within: summarySection }) : null;
    const checklist = h2(doc, 'Phase Checklist');
    const diagram = (title) => {
        const section = checklist ? findSection(doc, title, { level: 3, within: checklist }) : null;
        return section ? codeBlocks(bodyOf(doc, section), 'mermaid')[0]?.code ?? null : null;
    };
    const phases = planPhases(doc, warnings);
    if (!phases.length) warnings.push('The plan has no phases.');
    const decisionsBlock = bodyOfH2(doc, 'User Decisions and Requirements');
    const directionSection = h2(doc, 'User Decisions and Requirements');
    const direction = directionSection ? findSection(doc, 'Confirmed User Direction', { level: 3, within: directionSection }) : null;
    const readinessRows = tableWith(bodyOfH2(doc, 'Planning Readiness and Next Step'), ['Field', 'Record'])?.rows ?? [];
    const readiness = readinessRows.find((row) => labelKey(row.field) === 'planning execution and readiness') ?? readinessRows.find((row) => labelKey(row.field) === 'planning readiness');
    const critiqueBlock = bodyOfH2(doc, 'Critique Disposition');
    const critiqueFields = labeledFields(critiqueBlock);
    return {
        kind: 'plan',
        title: afterColon(titleOf(doc)),
        taskId: plainText(field(metadata, 'Task ID')) || null,
        summary: summarySection ? bodyOf(doc, summarySection, { own: true }) : '',
        unknowns: unknownsSection ? bodyOf(doc, unknownsSection) : '',
        before: diagram('Before'),
        after: diagram('After'),
        phases,
        requirements: [...requirementsFrom(bodyOfH2(doc, 'Functional Requirements'), 'FR'), ...requirementsFrom(bodyOfH2(doc, 'Non-Functional Requirements'), 'NFR')],
        decisions: (tableWith(decisionsBlock, ['Group', 'Decision or feedback item'])?.rows ?? [])
            .filter((row) => /^D\d{1,3}$/.test(row.group))
            .map((row) => ({ id: row.group, item: row['decision or feedback item'], status: plainText(row.status), owner: plainText(row.owner), rationale: row['rationale or input needed'] ?? '', evidence: idsIn(row.evidence), impact: row['planning impact'] ?? '' })),
        direction: direction ? bodyOf(doc, direction) : '',
        readiness: readiness ? readiness.record : null,
        critique: {
            setting: plainText(field(critiqueFields, 'Critique setting and provenance')),
            status: plainText(field(critiqueFields, 'Critique status')),
            latest: field(critiqueFields, 'Latest critique and verdict'),
            dispositions: (tableWith(critiqueBlock, ['Critique run and finding', 'Disposition'])?.rows ?? []).map((row) => ({
                finding: idsIn(row['critique run and finding'], /^PC-\d{3}$/)[0] ?? plainText(row['critique run and finding']),
                disposition: plainText(row.disposition),
                owner: plainText(row['action owner']),
                evidence: row['exact resolving evidence'] ?? '',
                route: plainText(row['decision route']),
                response: row['plan response or residual risk'] ?? '',
            })),
        },
        followUps: realItems(bodyOfH2(doc, 'Follow-Up Items')),
        other: others(doc, ['Task Metadata', 'Executive Summary', 'Phase Checklist', 'User Decisions and Requirements', 'Functional Requirements', 'Non-Functional Requirements', 'Critique Disposition', 'Follow-Up Items', 'Handoff']),
        warnings,
    };
}

/** Findings marked with `kind`, or severity headings under a section when unmarked. */
function markedFindings(doc, kind, sectionTitle) {
    let headings = doc.headings.filter((heading) => heading.marker?.kind === kind);
    if (!headings.length) {
        const section = h2(doc, sectionTitle);
        headings = section ? sectionsAt(doc, 3, section).filter((heading) => severityHeading(heading.title)) : [];
    }
    return headings.map((heading) => {
        const head = severityHeading(heading.title);
        return { heading, id: heading.marker?.id ?? head?.id, severity: head?.severity ?? '', title: plainText(head?.title ?? heading.title), fields: labeledFields(bodyOf(doc, heading)) };
    });
}

/** @param {string} text */
export function parseCritique(text) {
    const doc = parseDocument(text);
    const metadata = labeledFields(bodyOfH2(doc, 'Metadata'));
    const verdict = labeledFields(bodyOfH2(doc, 'Verdict'));
    const findings = markedFindings(doc, 'critique', 'Findings').map(({ id, severity, title, fields }) => ({
        id,
        severity,
        title,
        related: idsIn(field(fields, 'Related IDs'), PLAN_ID),
        relatedText: field(fields, 'Related IDs'),
        evidence: field(fields, 'Evidence'),
        concern: field(fields, 'Concern'),
        impact: field(fields, 'Impact'),
        change: field(fields, 'Smallest useful change'),
        owner: plainText(field(fields, 'Action owner')),
        resolving: field(fields, 'Exact resolving evidence'),
        route: plainText(field(fields, 'Decision route')),
    }));
    return {
        kind: 'critique',
        title: afterColon(titleOf(doc)),
        verdict: plainText(field(verdict, 'Verdict')),
        rationale: field(verdict, 'Rationale'),
        depth: plainText(field(metadata, 'Critique depth')),
        execution: plainText(field(metadata, 'Critique execution')),
        findings,
        other: others(doc, ['Metadata', 'Verdict', 'Findings']),
        warnings: findings.length ? [] : ['The critique has no findings.'],
    };
}

/** Plan updates as H3 entries, or as flat `* Label: text` bullets. */
function planUpdatesFrom(doc) {
    const section = h2(doc, 'Implementation-Time Plan Updates');
    if (!section) return [];
    const entries = sectionsAt(doc, 3, section);
    if (entries.length) {
        return entries.map((heading) => {
            const body = bodyOf(doc, heading);
            const fields = labeledFields(body);
            return { title: plainText(heading.title), area: plainText(field(fields, 'Affected plan area or markers')), markdown: body };
        });
    }
    return realItems(bodyOf(doc, section)).map((item) => {
        const match = /^([^:\n]{1,140}):\s*([\s\S]*)$/.exec(item);
        return match ? { title: plainText(match[1]), area: plainText(match[1]), markdown: match[2].trim() } : { title: plainText(item.split('\n')[0]).slice(0, 120), area: '', markdown: item };
    });
}

function alignmentFrom(doc) {
    const section = h2(doc, 'Business Alignment');
    if (!section) return [];
    return sectionsAt(doc, 3, section).map((heading) => {
        const fields = labeledFields(bodyOf(doc, heading));
        const sourceText = plainText(field(fields, 'Source document'));
        const source = /^(.*?)\s*\(([^,()]+),\s*status\s+([^)]+)\)\s*$/.exec(sourceText);
        return {
            title: plainText(heading.title),
            source: source ? source[1] : sourceText,
            document: source ? source[2].trim() : '',
            status: source ? source[3].trim() : '',
            requirement: plainText(field(fields, 'Cited requirement IDs')),
            owner: plainText(field(fields, 'Owner or deciders')),
            marker: plainText(field(fields, 'Related plan update or marker')),
            change: field(fields, 'What changed'),
            why: field(fields, 'Why'),
            decision: plainText(field(fields, 'User decision')),
            alignment: plainText(field(fields, 'Alignment')),
        };
    });
}

/** @param {string} text */
export function parseChanges(text) {
    const doc = parseDocument(text);
    const status = labeledFields(bodyOfH2(doc, 'Execution Status'));
    const completed = h2(doc, 'Completed Work');
    const entries = completed ? sectionsAt(doc, 3, completed).map((heading) => {
        const fields = labeledFields(bodyOf(doc, heading));
        const related = field(fields, 'Related phase or task');
        const filesBlock = field(fields, 'Files');
        const links = linksIn(filesBlock);
        return {
            title: plainText(heading.title),
            related,
            taskId: idsIn(related, TASK_ID)[0] ?? null,
            ids: idsIn(related),
            files: (links.length ? links.map((link) => plainText(link.text)) : realItems(filesBlock).map(plainText)).filter(Boolean),
            behavior: field(fields, 'Behavior or functionality changed'),
            validation: field(fields, 'Validation'),
        };
    }) : [];
    return {
        kind: 'changes',
        title: afterColon(titleOf(doc)),
        status: {
            status: plainText(field(status, 'Status')),
            scope: plainText(field(status, 'Declared invocation scope')),
            completed: field(status, 'Completed scope markers'),
            remaining: field(status, 'All remaining active-plan markers'),
            basis: field(status, 'Status basis'),
        },
        summary: bodyOfH2(doc, 'Execution Summary'),
        entries,
        planUpdates: planUpdatesFrom(doc),
        alignment: alignmentFrom(doc),
        validation: (tableWith(bodyOfH2(doc, 'Validation Record'), ['Check', 'Status'])?.rows ?? []).map((row) => ({ check: plainText(row.check), scope: plainText(row.scope), status: plainText(row.status), summary: row['evidence or reason'] ?? '' })),
        blockers: realItems(bodyOfH2(doc, 'Blockers')),
        remaining: realItems(bodyOfH2(doc, 'Remaining Work')),
        followUps: realItems(bodyOfH2(doc, 'Follow-Up Items')),
        other: others(doc, ['Metadata', 'Execution Status', 'Execution Summary', 'Completed Work', 'Implementation-Time Plan Updates', 'Business Alignment', 'Validation Record', 'Blockers', 'Remaining Work', 'Follow-Up Items']),
        warnings: completed ? [] : ['The changes record has no Completed Work section.'],
    };
}

/** @param {string} text */
export function parseReview(text) {
    const doc = parseDocument(text);
    const summary = labeledFields(bodyOfH2(doc, 'Executive Summary'));
    const record = h2(doc, 'Parent Decision Record');
    const dispositionSection = record ? findSection(doc, 'Current Disposition', { level: 3, within: record }) : null;
    const historySection = record ? findSection(doc, 'Decision History', { level: 3, within: record }) : null;
    const findings = markedFindings(doc, 'review', 'Findings and Proposed Routes').map(({ id, severity, title, fields }) => ({
        id,
        severity,
        title,
        relatedText: field(fields, 'Related scope'),
        related: idsIn(field(fields, 'Related scope'), PLAN_ID),
        expected: field(fields, 'Expected behavior'),
        observed: field(fields, 'Observed behavior and evidence'),
        impact: field(fields, 'Impact'),
        resolution: field(fields, 'Resolution condition'),
        destination: plainText(field(fields, 'Proposed destination')),
        next: field(fields, 'Smallest useful next action'),
    }));
    const history = (historySection ? tableWith(bodyOf(doc, historySection), ['Event', 'Subject'])?.rows ?? [] : []).map((row) => ({
        id: plainText(row.event),
        subject: plainText(row.subject),
        source: plainText(row['decision source']),
        status: plainText(row['status or value']),
        owner: plainText(row.owner),
        next: row['smallest next action'] ?? '',
        rationale: row.rationale ?? '',
    }));
    return {
        kind: 'review',
        title: afterColon(titleOf(doc)),
        summary: bodyOfH2(doc, 'Executive Summary'),
        assessment: field(summary, 'Assessment'),
        execution: plainText(field(summary, 'Review execution')),
        outcome: plainText(field(summary, 'Assessed outcome')),
        unknowns: bodyOfH2(doc, 'What You May Not Know'),
        findings,
        disposition: dispositionSection ? bodyOf(doc, dispositionSection) : '',
        history,
        validation: (tableWith(bodyOfH2(doc, 'Validation Evidence'), ['Command', 'Status'])?.rows ?? []).map((row) => ({ check: plainText(row.command), scope: plainText(row.scope), status: plainText(row.status), summary: row.summary ?? '' })),
        followUps: (tableWith(text, ['Follow-up item', 'Owner or next action'])?.rows ?? []).map((row) => ({ item: row['follow-up item'], why: row['why outside immediate scope'] ?? '', owner: plainText(row['owner or next action']), route: plainText(row['assessment and route']) })),
        other: others(doc, ['Executive Summary', 'What You May Not Know', 'Findings and Proposed Routes', 'Parent Decision Record', 'Validation Evidence']),
        warnings: findings.length || history.length ? [] : ['The review has no findings or decision history.'],
    };
}

/**
 * Parses an artifact by its first heading.
 *
 * @param {string} text
 */
export function parseArtifact(text) {
    switch (artifactKind(text)) {
        case 'research': return parseResearch(text);
        case 'plan': return parsePlan(text);
        case 'critique': return parseCritique(text);
        case 'changes': return parseChanges(text);
        case 'review': return parseReview(text);
        default: return null;
    }
}
