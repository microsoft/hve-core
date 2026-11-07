// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import fs from 'node:fs/promises';
import { areaStatus, assess, check, finalizeState, id, mergeResult, newWork, object, PERSPECTIVES, SEVERITIES, stableJson, text, unassignedFiles, validateResult } from './model.mjs';
import { digest, exists, loadReview, readJson, readText, updateState, writeJson, writeText } from './storage.mjs';

export async function schedule(location, revision, request) {
    object(request, ['perspectives', 'scope'], 'schedule', ['areas']);
    check(Array.isArray(request.perspectives) && request.perspectives.length > 0 && request.perspectives.every((entry) => PERSPECTIVES.includes(entry)),
        'Select known perspectives.', 'invalid_input');
    return updateState(location, revision, (state, snapshot) => {
        check(!state.scope || stableJson(state.scope) === stableJson(request.scope), 'A changed scope requires a new snapshot; prior coverage remains in its history.', 'scope_change');
        state.scope = request.scope;
        if (request.areas) {
            check(state.workItems.length === 0, 'Areas with assignments cannot be replaced.', 'scope_change');
            state.areas = request.areas;
            if (Array.isArray(state.areas) && state.areas.every((area) => Array.isArray(area?.fileIds))) {
                const unassigned = unassignedFiles(state, snapshot);
                check(unassigned.length === 0, `Areas must include every captured file; put files no perspective needs in an area and return a reasoned not-applicable result. Unassigned: ${unassigned.join(', ')}.`, 'invalid_input');
            }
        } else if (!state.areas.length) {
            state.areas = [{
                id: 'changes', title: 'Captured changes', fileIds: snapshot.files.map((file) => file.id),
                summary: '', before: '', after: '', impact: [],
            }];
        }
        for (const area of state.areas) {
            for (const perspective of new Set(request.perspectives)) {
                const workId = `${perspective}-${state.workItems.length + 1}`;
                state.workItems.push(newWork(snapshot, area, perspective, workId));
            }
        }
        return finalizeState(state, snapshot);
    });
}

export async function setWork(location, revision, request) {
    object(request, ['workItemId', 'status', 'reason'], 'work update');
    check(['in_progress', 'blocked', 'unavailable', 'skipped'].includes(request.status), 'Use a result to complete work.', 'invalid_input');
    text(request.reason, 'work update reason');
    return updateState(location, revision, (state, snapshot) => {
        const work = state.workItems.find((entry) => entry.id === request.workItemId);
        check(work && work.resultKey === null, 'Work is unknown or already has a result; use a new assignment.', 'invalid_input');
        work.status = request.status;
        work.summary = request.reason;
        return finalizeState(state, snapshot);
    });
}

async function validateSnippets(location, snapshot, result) {
    for (const finding of result.findings) {
        if (!Object.hasOwn(finding, 'snippet')) continue;
        const anchor = finding.anchors[0];
        check(['old', 'new'].includes(anchor.side), 'A snippet requires a line anchor.');
        const file = snapshot.files.find((entry) => entry.id === anchor.fileId);
        const evidence = await readJson(location.root, file.evidencePath);
        const key = anchor.side === 'old' ? 'oldLine' : 'newLine';
        const captured = evidence.lines.filter((line) => line.hunkId === anchor.hunkId && line[key] >= anchor.startLine && line[key] <= anchor.endLine && line[key] !== null).map((line) => line.text).join('\n');
        check(captured === finding.snippet, 'Finding snippet differs from captured evidence.', 'invalid_evidence');
    }
}

export async function writeResult(location, result) {
    const { state, snapshot } = await loadReview(location);
    const work = validateResult(result, state, snapshot);
    await validateSnippets(location, snapshot, result);
    await writeJson(location.root, work.outputPath, result, true);
    return { path: work.outputPath, workItemId: work.id, execution: result.execution };
}

export async function mergeStoredResult(location, revision, request) {
    object(request, ['workItemId'], 'merge request');
    return updateState(location, revision, async (state, snapshot) => {
        const work = state.workItems.find((entry) => entry.id === request.workItemId);
        check(work, 'Unknown work item.', 'invalid_input');
        const result = await readJson(location.root, work.outputPath);
        validateResult(result, state, snapshot);
        await validateSnippets(location, snapshot, result);
        return mergeResult(state, snapshot, result, digest(stableJson(result)));
    });
}

export async function decideFindings(location, revision, request) {
    object(request, ['decisions'], 'finding decisions');
    check(Array.isArray(request.decisions) && request.decisions.length > 0, 'Supply finding decisions.', 'invalid_input');
    return updateState(location, revision, (state, snapshot) => {
        for (const decision of request.decisions) {
            object(decision, ['id', 'disposition', 'reason'], 'decision', ['severity']);
            check(['accepted', 'disputed', 'deferred', 'rejected'].includes(decision.disposition), 'Unknown finding disposition.', 'invalid_input');
            text(decision.reason, 'decision reason');
            const finding = state.findings.find((entry) => entry.id === decision.id);
            check(finding, 'Decision refers to an unknown finding.', 'invalid_input');
            Object.assign(finding, { disposition: decision.disposition, reason: decision.reason });
            if (decision.severity !== undefined) {
                check(SEVERITIES.includes(decision.severity), 'Unknown severity.', 'invalid_input');
                finding.severity = decision.severity;
            }
        }
        return finalizeState(state, snapshot);
    });
}

export async function assessFindings(location, revision, request) {
    object(request, ['workItemId', 'findings'], 'parent assessment');
    return updateState(location, revision, async (state, snapshot) => {
        const next = assess(state, snapshot, request.workItemId, request.findings);
        await validateSnippets(location, snapshot, request);
        return next;
    });
}

export async function updateContext(location, revision, request) {
    object(request, [], 'context update', ['areas', 'context', 'limitations']);
    return updateState(location, revision, (state, snapshot) => {
        for (const area of request.areas ?? []) {
            object(area, ['id', 'summary', 'before', 'after', 'impact'], 'area description');
            const existing = state.areas.find((entry) => entry.id === area.id);
            check(existing, 'Unknown area.', 'invalid_input');
            Object.assign(existing, area);
        }
        if (request.context) state.context = { ...state.context, ...request.context };
        for (const limitation of request.limitations ?? []) {
            id(limitation.id);
            const index = state.limitations.findIndex((entry) => entry.id === limitation.id);
            if (index < 0) state.limitations.push(limitation);
            else state.limitations[index] = limitation;
        }
        return finalizeState(state, snapshot);
    });
}

const markdownText = (value) => String(value).replace(/[\\`*_[\]<>#]/g, '\\$&');

export async function canonicalDisclaimer() {
    const source = await fs.readFile(new URL('../../../../shared/disclaimer-language/SKILL.md', import.meta.url), 'utf8');
    const block = source.replaceAll('\r\n', '\n').split('\n## Code-Review\n')[1]?.split('\n## ')[0]?.trim();
    check(block?.startsWith('> [!CAUTION]') && block.includes('qualified human reviewer'), 'Canonical Code-Review disclaimer is unavailable.', 'disclaimer_unavailable');
    return block;
}

export async function renderReport(location, revision) {
    const disclaimer = await canonicalDisclaimer();
    const template = (await fs.readFile(new URL('../../templates/review.md', import.meta.url), 'utf8')).replace(/^---\n[\s\S]*?\n---\n+/, '');
    return updateState(location, revision, async (state, snapshot) => {
        let prior;
        if (await exists(location.root, 'review.md')) {
            prior = await readText(location.root, 'review.md');
            check(digest(prior) === state.artifacts.reportDigest, 'The human-editable report changed. Preserve it and reconcile edits before rendering.', 'draft_conflict');
        }
        const coverage = [
            `Review: ${state.reviewId}. Snapshot: ${state.snapshotId}.`,
            `Execution: ${state.status}. Outcome: ${state.outcome ?? 'not available'}.`,
            `Target: ${snapshot.target.kind}; base ${snapshot.target.base ?? 'not applicable'}; head ${snapshot.target.head ?? 'not applicable'}.`,
            ...state.areas.map((area) => `${markdownText(area.title)}: ${areaStatus(state, area.id)}.`),
            ...state.workItems.map((work) => `${work.id} (${work.perspective}): ${work.status}. ${markdownText(work.summary)}`),
        ].join('\n\n');
        const findings = state.findings.map((finding) => {
            const anchors = finding.anchors.map((anchor) => {
                if (anchor.side === 'metadata') return `PR metadata: ${markdownText(anchor.field)}`;
                const file = snapshot.files.find((entry) => entry.id === anchor.fileId);
                return `${markdownText(anchor.side === 'old' ? file.oldPath : file.newPath ?? file.oldPath)} (${anchor.side}${anchor.startLine === null ? '' : ` ${anchor.startLine}-${anchor.endLine}`})`;
            }).join('; ');
            return `### ${finding.id}: ${markdownText(finding.claim)}\n\n${finding.severity}; ${finding.disposition}. ${anchors}.\n\n${markdownText(finding.consequence)}\n\nSuggested change: ${markdownText(finding.remediation)}\n\n${markdownText(finding.reason ?? 'Awaiting parent verification.')}`;
        }).join('\n\n') || 'No findings recorded. See coverage before interpreting this as a completed review.';
        const context = [
            ...state.limitations.map((entry) => `${entry.blocking ? 'Blocking' : 'Limitation'}: ${markdownText(entry.summary)}`),
            ...snapshot.omissions.map(markdownText),
            ...snapshot.discussion.limitations.map(markdownText),
            ...state.workItems.flatMap((work) => work.observations.map(markdownText)),
            ...(state.context ? [markdownText(JSON.stringify(state.context, null, 2))] : []),
        ].join('\n\n') || 'No additional context recorded.';
        const event = state.outcome === 'request_changes' ? 'REQUEST_CHANGES' : state.outcome === 'approve' ? 'APPROVE' : 'COMMENT';
        const draft = snapshot.target.kind === 'pr' ? `## PR comment draft\n\nProposed event: ${event}\n\n${state.outcome ? `Review outcome: ${state.outcome}.` : 'Review is incomplete; no approval is proposed.'} ${state.findings.filter((entry) => entry.disposition !== 'rejected').length} finding(s) require human consideration.\n\n- [ ] Reviewed, edited, and approved this comment for posting to the PR` : '';
        const values = { coverage, findings, context, draft, disclaimer };
        const output = `<!-- markdownlint-disable-file -->\n${template.replace(/\{\{(coverage|findings|context|draft|disclaimer)\}\}/g, (_, key) => values[key])}`;
        if (prior !== undefined) check(await readText(location.root, 'review.md') === prior, 'Report changed during rendering.', 'draft_conflict');
        await writeText(location.root, 'review.md', output, prior === undefined);
        state.artifacts = { report: 'review.md', reportDigest: digest(output) };
        return state;
    });
}
