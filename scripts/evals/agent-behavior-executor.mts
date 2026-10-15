// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// agent-behavior-executor.mts
//
// Vally executor plugin for the agent-behavior suite. Load it with
// `vally eval --executor-plugin <absolute path to this file> --executor hve-agent-behavior`.
// It wraps the stock Copilot SDK executor and changes nothing for legacy policy
// entries. For candidate and enforced agent contracts it replaces the mounted
// agent copy with a composition of the agent and its source-relative instruction
// imports before the agent runs. For candidate and enforced entries that declare
// a filesystem boundary it compares the whole workspace before and after the
// agent runs. Both results are recorded as host system events.

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type {
    Executor,
    ExecutorOptions,
    ExecutorRegistry,
    Stimulus,
    TracingConfig,
    Trajectory,
    TrajectoryEvent
} from '@microsoft/vally';
import {
    CONTEXT_COMPOSED_EVENT,
    CONTEXT_UNASSESSED_EVENT,
    FILESYSTEM_EVENTS,
    HOST_EVENT_PREFIX,
    INSTRUCTIONS_PATH,
    SnapshotError,
    captureSnapshot,
    compareSnapshots,
    composeContext,
    loadPolicy,
    sha256,
    type FilesystemVerdict,
    type PolicyEntry,
    type Snapshot
} from './agent-behavior-runtime.mts';

/** Registered name selected with `vally eval --executor`. */
export const EXECUTOR_NAME = 'hve-agent-behavior';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DEFAULT_POLICY = path.join(REPO_ROOT, 'evals', 'agent-behavior', 'measurement-policy.json');

const CAPABILITIES = [
    'supportsPreparedWorkspace',
    'supportsMultiTurn',
    'supportsTurnCompletion',
    'supportsSimulation',
    'supportsMcpSimulation',
    'supportsAttachments',
    'supportsEnvVars'
] as const;

/** Construction options; tests supply a fake delegate and fixture repository. */
export interface AgentBehaviorExecutorOptions {
    delegate: Executor;
    /** Repository root used to resolve agent and instruction sources. */
    repoRoot?: string;
    /** Coverage policy path; defaults to the repository's agent-behavior policy. */
    policyPath?: string;
}

/**
 * Captures a workspace snapshot, returning the failure instead of throwing so the
 * trial still reports an explicit unavailable verdict.
 */
async function observe(workDir: string): Promise<Snapshot | SnapshotError> {
    try {
        return await captureSnapshot(workDir);
    } catch (error) {
        return error instanceof SnapshotError ? error : new SnapshotError('read-error', String(error));
    }
}

function unavailable(code: string): FilesystemVerdict {
    return { status: 'unavailable', codes: [code], changeCount: 0, changes: [] };
}

/**
 * Applies host context for one trial and returns the provenance details to record.
 *
 * @throws When the mounted instructions do not match the declared agent source, or
 * the declared context cannot be composed. A throw fails the trial rather than
 * letting it run with unverified context.
 */
function prepareContext(
    stimulus: Stimulus,
    entry: PolicyEntry,
    workDir: string,
    policySha: string,
    repoRoot: string
): Record<string, unknown> {
    const base = { stimulus: stimulus.name, class: entry.class, measurement: entry.measurement, policySha256: policySha };
    if (entry.class !== 'agent-contract' || entry.measurement === 'legacy') {
        return { ...base, assessed: false };
    }
    if (entry.agentSource === undefined) {
        throw new Error(`Policy entry '${stimulus.name}' is ${entry.measurement} but declares no agentSource`);
    }
    const mounted = path.join(workDir, INSTRUCTIONS_PATH);
    let staged: Buffer;
    try {
        staged = readFileSync(mounted);
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
            throw new Error(`Stimulus '${stimulus.name}' did not stage ${INSTRUCTIONS_PATH}`);
        }
        throw error;
    }
    const composed = composeContext(repoRoot, entry.agentSource);
    if (sha256(staged) !== composed.agent.sha256) {
        throw new Error(`Stimulus '${stimulus.name}' staged ${INSTRUCTIONS_PATH} that differs from '${entry.agentSource}'`);
    }
    writeFileSync(mounted, composed.text);
    return {
        ...base,
        assessed: true,
        agent: composed.agent,
        imports: composed.imports,
        composedSha256: composed.composedSha256
    };
}

/**
 * Creates the agent-behavior executor around a delegate.
 *
 * @remarks Capability flags, config validation and tracing configuration are forwarded
 * only when the delegate provides them, so Vally's capability checks see the delegate's
 * real support. Delegate events in the reserved host namespace are removed before host
 * evidence is appended. The policy is read once at construction.
 * @throws When the measurement policy cannot be loaded.
 */
export function createAgentBehaviorExecutor(options: AgentBehaviorExecutorOptions): Executor {
    const { delegate } = options;
    const repoRoot = options.repoRoot ?? REPO_ROOT;
    const policyPath = options.policyPath ?? DEFAULT_POLICY;
    const policy = loadPolicy(policyPath);
    const policySha = sha256(readFileSync(policyPath));

    const executor: Executor & { configureTracing?: (config: TracingConfig) => void } = {
        name: EXECUTOR_NAME,
        async execute(stimulus: Stimulus, executeOptions: ExecutorOptions): Promise<Trajectory> {
            const entry = policy.stimuli[stimulus.name];
            if (entry === undefined) {
                throw new Error(`Stimulus '${stimulus.name}' has no entry in the agent-behavior measurement policy`);
            }
            const workDir = executeOptions.workDir;
            const context = prepareContext(stimulus, entry, workDir, policySha, repoRoot);
            const boundary = entry.measurement === 'legacy' ? undefined : entry.filesystem;
            const baseline = boundary === undefined ? undefined : await observe(workDir);

            const trajectory = await delegate.execute(stimulus, executeOptions);

            const hostEvents: TrajectoryEvent[] = [{
                type: 'system',
                data: { eventType: context.assessed === true ? CONTEXT_COMPOSED_EVENT : CONTEXT_UNASSESSED_EVENT, details: context }
            }];
            if (boundary !== undefined && baseline !== undefined) {
                let verdict: FilesystemVerdict;
                if (baseline instanceof SnapshotError) verdict = unavailable(`baseline-${baseline.code}`);
                else {
                    const final = await observe(workDir);
                    verdict = final instanceof SnapshotError ? unavailable(`final-${final.code}`) : compareSnapshots(baseline, final, boundary);
                }
                hostEvents.push({
                    type: 'system',
                    data: { eventType: FILESYSTEM_EVENTS[verdict.status], details: { stimulus: stimulus.name, policySha256: policySha, ...verdict } }
                });
            }
            trajectory.events = [
                ...trajectory.events.filter(
                    event => !(event.type === 'system' && event.data.eventType.startsWith(HOST_EVENT_PREFIX))
                ),
                ...hostEvents
            ];
            return trajectory;
        },
        shutdown: () => delegate.shutdown()
    };
    for (const capability of CAPABILITIES) {
        if (delegate[capability] !== undefined) executor[capability] = delegate[capability];
    }
    if (typeof delegate.validateConfig === 'function') {
        executor.validateConfig = (config: unknown) => delegate.validateConfig!(config);
    }
    const tracing = (delegate as Partial<{ configureTracing: (config: TracingConfig) => void }>).configureTracing;
    if (typeof tracing === 'function') {
        executor.configureTracing = (config: TracingConfig) => tracing.call(delegate, config);
    }
    return executor;
}

/** Vally executor plugin entry point. */
export async function registerExecutors(registry: ExecutorRegistry): Promise<void> {
    const { CopilotSdkExecutor } = await import('@microsoft/vally/executor');
    registry.register(createAgentBehaviorExecutor({ delegate: new CopilotSdkExecutor() }));
}
