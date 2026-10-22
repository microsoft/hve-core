// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { cp, mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import {
  FixtureApprovalLedger,
  parseApprovalRequest,
  type ApprovalRequestItem,
} from "./approval.mts";
import {
  EXPECTED_CONTEXT_TIER,
  EVALUATION_CASE_IDS,
  EXPECTED_MODEL,
  EXPECTED_REASONING_EFFORT,
  resolveInside,
  sha256,
  stableJson,
  writeJson,
} from "./contracts.mts";
import {
  createEvidenceTools,
  type ApprovalConsumer,
  type ToolDefinition,
} from "./evidence-tools.mts";

export interface ModelInfo {
  readonly id: string;
  readonly supportedReasoningEfforts?: readonly string[];
}

export interface AssistantResponse {
  readonly content: string;
}

export interface ModelSession {
  onEvent(handler: (event: unknown) => void): () => void;
  sendAndWait(prompt: string, timeoutMs: number): Promise<AssistantResponse | undefined>;
  destroy(): Promise<void>;
}

export interface ModelClient {
  start(): Promise<void>;
  stop(): Promise<void>;
  listModels(): Promise<readonly ModelInfo[]>;
  getStatus(): Promise<unknown>;
  createSession(config: SessionCreationConfig): Promise<ModelSession>;
}

export interface SessionCreationConfig {
  readonly sessionId: string;
  readonly workingDirectory: string;
  readonly model: string;
  readonly reasoningEffort: string;
  readonly contextTier: string;
  readonly systemMessage: string;
  readonly tools: readonly ToolDefinition[];
}

export interface TrialArtifact {
  readonly schemaVersion: "1.0.0";
  readonly runId: string;
  readonly caseId: string;
  readonly trial: number;
  readonly requestedProfile: {
    readonly model: string;
    readonly reasoningEffort: string;
    readonly contextTier: string;
  };
  readonly preflight: {
    readonly modelAvailable: boolean;
    readonly reasoningEffortAvailable: boolean;
    readonly clientStatus: unknown;
  };
  readonly firstResponse?: string;
  readonly finalResponse?: string;
  readonly error?: string;
  readonly endReason: "complete" | "error";
  readonly events: readonly unknown[];
  readonly evidenceToolTraces: readonly unknown[];
  readonly approvalLedger?: unknown;
  readonly hashes: Readonly<Record<string, string>>;
  readonly redactionManifest: {
    readonly applied: readonly string[];
    readonly replacements: number;
  };
}

export interface RunTrialOptions {
  readonly repositoryRoot: string;
  readonly runRoot: string;
  readonly runId: string;
  readonly caseId: string;
  readonly trial: number;
  readonly clientFactory?: (workspace: string) => Promise<ModelClient>;
  readonly clock?: () => Date;
  readonly timeoutMs?: number;
}

class DeferredApprovalConsumer implements ApprovalConsumer {
  ledger?: FixtureApprovalLedger;

  consume(
    tool: string,
    operation: string,
    parameters: Readonly<Record<string, unknown>>,
  ): string {
    if (!this.ledger) {
      throw new Error("No simulated approval has been established");
    }
    return this.ledger.consume(tool, operation, parameters);
  }
}

/**
 * Runs one isolated two-turn RCA trial without retries.
 *
 * The first turn may only request enumerated evidence calls. After the request is validated, a
 * separately persisted simulated fixture approval enables exact calls for the second turn.
 */
export async function runTrial(options: RunTrialOptions): Promise<TrialArtifact> {
  if (
    !EVALUATION_CASE_IDS.includes(options.caseId as (typeof EVALUATION_CASE_IDS)[number]) ||
    ![1, 2, 3].includes(options.trial)
  ) {
    throw new Error("Trial must use a configured neutral case ID and trial 1 through 3");
  }
  const clock = options.clock ?? (() => new Date());
  const sessionRoot = resolveInside(
    options.runRoot,
    `sessions/${options.caseId}/trial-${options.trial}`,
  );
  await mkdir(sessionRoot, { recursive: true });
  const workspace = await mkdtemp(join(tmpdir(), `rca-eval-${options.caseId}-${options.trial}-`));
  const events: unknown[] = [];
  const hashes: Record<string, string> = {};
  const deferredLedger = new DeferredApprovalConsumer();
  const evidence = createEvidenceTools({
    caseRoot: resolveInside(options.runRoot, `inputs/model-visible/${options.caseId}`),
    ledger: deferredLedger,
    clock,
  });
  let client: ModelClient | undefined;
  let session: ModelSession | undefined;
  let firstResponse: string | undefined;
  let finalResponse: string | undefined;
  let approvalLedger: unknown;
  let errorMessage: string | undefined;
  let clientStatus: unknown = "Unavailable - client did not start";
  let modelAvailable = false;
  let reasoningEffortAvailable = false;

  try {
    const skillText = await stageSkills(options.repositoryRoot, workspace);
    const prompt = buildInitialPrompt(options.caseId, clock());
    hashes.promptSha256 = sha256(prompt);
    hashes.skillBundleSha256 = sha256(skillText);
    hashes.toolContractSha256 = sha256(
      stableJson(
        evidence.tools.map(({ name, description, parameters }) => ({
          name,
          description,
          parameters,
        })),
      ),
    );

    client = await (options.clientFactory ?? createCopilotClient)(workspace);
    await client.start();
    clientStatus = await client.getStatus();
    const models = await client.listModels();
    const model = models.find((candidate) => candidate.id === EXPECTED_MODEL);
    modelAvailable = model !== undefined;
    reasoningEffortAvailable =
      model?.supportedReasoningEfforts?.includes(EXPECTED_REASONING_EFFORT) ?? false;
    if (!modelAvailable || !reasoningEffortAvailable) {
      throw new Error(
        `Exact model profile unavailable: ${EXPECTED_MODEL}/${EXPECTED_REASONING_EFFORT}/${EXPECTED_CONTEXT_TIER}`,
      );
    }

    session = await client.createSession({
      sessionId: `${options.runId}-${options.caseId}-trial-${options.trial}`,
      workingDirectory: workspace,
      model: EXPECTED_MODEL,
      reasoningEffort: EXPECTED_REASONING_EFFORT,
      contextTier: EXPECTED_CONTEXT_TIER,
      systemMessage: skillText,
      tools: evidence.tools,
    });
    const unsubscribe = session.onEvent((event) => events.push(event));
    try {
      firstResponse = (await session.sendAndWait(prompt, options.timeoutMs ?? 180_000))?.content;
      if (!firstResponse) {
        throw new Error("First turn produced no assistant response");
      }
      if (evidence.traces.length > 0) {
        throw new Error("Evidence tool was attempted before fixture approval");
      }
      const request = parseApprovalRequest(firstResponse);
      validateApprovalTargets(request.approvalRequests, options.caseId, evidence.tools);
      deferredLedger.ledger = new FixtureApprovalLedger(request.approvalRequests, clock);
      approvalLedger = deferredLedger.ledger.artifact();
      await writeJson(join(sessionRoot, "fixture-approval-ledger.json"), approvalLedger);

      finalResponse = (
        await session.sendAndWait(
          buildApprovalTurn(deferredLedger.ledger, options.caseId),
          options.timeoutMs ?? 180_000,
        )
      )?.content;
      if (!finalResponse) {
        throw new Error("Approved turn produced no assistant response");
      }
      approvalLedger = deferredLedger.ledger.artifact();
      await writeJson(join(sessionRoot, "fixture-approval-ledger.json"), approvalLedger);
    } finally {
      unsubscribe();
    }
  } catch (error) {
    errorMessage = error instanceof Error ? error.message : String(error);
  } finally {
    if (session) {
      await session.destroy().catch(() => undefined);
    }
    if (client) {
      await client.stop().catch(() => undefined);
    }
    await rm(workspace, { recursive: true, force: true });
  }

  const rawArtifact = {
    schemaVersion: "1.0.0" as const,
    runId: options.runId,
    caseId: options.caseId,
    trial: options.trial,
    requestedProfile: {
      model: EXPECTED_MODEL,
      reasoningEffort: EXPECTED_REASONING_EFFORT,
      contextTier: EXPECTED_CONTEXT_TIER,
    },
    preflight: { modelAvailable, reasoningEffortAvailable, clientStatus },
    firstResponse,
    finalResponse,
    error: errorMessage,
    endReason: errorMessage ? ("error" as const) : ("complete" as const),
    events,
    evidenceToolTraces: evidence.traces,
    approvalLedger,
    hashes,
  };
  const redacted = redactArtifact(rawArtifact, [options.repositoryRoot, process.env.USERPROFILE ?? ""]);
  const artifact: TrialArtifact = {
    ...redacted.value,
    redactionManifest: {
      applied: ["repository-root", "user-home", "credential-patterns"],
      replacements: redacted.replacements,
    },
  };
  await writeJson(join(sessionRoot, "session-artifact.json"), artifact);
  await writeJson(join(sessionRoot, "artifact-hashes.json"), {
    sessionArtifactSha256: sha256(stableJson(artifact)),
    approvalLedgerSha256: approvalLedger ? sha256(stableJson(approvalLedger)) : "Unavailable",
  });
  return artifact;
}

/** Copies the exact RCA skill package into an isolated workspace and returns its prompt bundle. */
export async function stageSkills(repositoryRoot: string, workspace: string): Promise<string> {
  const sourceRoot = join(repositoryRoot, ".github", "skills", "root-cause-analysis");
  const targetRoot = join(workspace, "skills");
  await mkdir(targetRoot, { recursive: true });
  for (const skillName of [
    "root-cause-analysis",
    "causal-evidence-likelihood",
    "statistical-hypothesis-testing",
  ]) {
    await cp(join(sourceRoot, skillName), join(targetRoot, skillName), { recursive: true });
  }
  const skillFiles = [
    join(targetRoot, "root-cause-analysis", "SKILL.md"),
    join(targetRoot, "causal-evidence-likelihood", "SKILL.md"),
    join(targetRoot, "statistical-hypothesis-testing", "SKILL.md"),
  ];
  const contents = await Promise.all(skillFiles.map((path) => readFile(path, "utf8")));
  return [
    "Use the following exact packaged skills for this evaluation. They are authoritative workflow instructions.",
    ...contents,
    "Evaluation constraint: no statistical runtime is available. Repeated telemetry rows from one injected incident are dependent observations, not independent affected and unaffected units.",
    "The only evidence authority comes from separately approved custom evidence tools. Never use filesystem, shell, network, memory, or repository tools.",
  ].join("\n\n");
}

/** Builds the first generic-mode turn, including the exact approval-envelope contract. */
export function buildInitialPrompt(caseId: string, now: Date): string {
  const expiry = new Date(now.getTime() + 15 * 60 * 1000).toISOString();
  const requestedCalls = [
    {
      tool: "read_incident_scope",
      operation: "read",
      parameters: {},
      evidenceSought: "Neutral incident onset, available sources, coverage, and statistical-unit limits",
    },
  ];
  return [
    `Investigate neutral incident ${caseId} using the root-cause-analysis skill in generic mode.`,
    "The incident context and evidence are available only through the custom read-only tools.",
    "The first approval cycle permits only this scope-discovery call:",
    requestedCalls
      .map(
        (call) =>
          `* tool \`${call.tool}\`, operation \`${call.operation}\`, exact parameters \`${JSON.stringify(call.parameters)}\``,
      )
      .join("\n"),
    "Use this exact name, operation, and parameters. Do not request another evidence tool until the scope result is returned.",
    "Before any tool call, end your first response with exactly one fenced JSON object of this form:",
    `\`\`\`json\n${stableJson({
      approvalRequests: requestedCalls.map((call) => ({
          ...call,
          target: caseId,
          scope: "current neutral case only",
          maximumCallCount: 1,
          expectedRisk: "read-only bounded fixture evidence",
          expiresAt: expiry,
      })),
    }).trim()}\n\`\`\``,
    "Do not request a tool class, shell, network client, write, or wildcard.",
    "Do not call a tool in the first turn. After simulated fixture approval, execute the scope call and request one exact adaptive evidence batch as instructed. Do not return the final RCA until that batch is approved and executed.",
  ].join("\n\n");
}

/** Rejects approval requests for any tool or neutral case outside the current trial. */
export function validateApprovalTargets(
  requests: readonly ApprovalRequestItem[],
  caseId: string,
  tools: readonly ToolDefinition[],
): void {
  const allowed = new Set(tools.map((tool) => tool.name));
  for (const request of requests) {
    if (!allowed.has(request.tool) || request.target !== caseId) {
      throw new Error(`Approval request targets an unavailable tool or case: ${request.tool}`);
    }
  }
}

/** Builds the second turn from the separately persisted simulated fixture ledger. */
export function buildApprovalTurn(
  ledger: FixtureApprovalLedger,
  caseId: string,
  phase: "scope" | "final" = "final",
): string {
  const approval = [
    "SIMULATED EVALUATION FIXTURE APPROVAL. This is not live production authorization or authenticated human approval.",
    `The host-authenticated evaluation requester authorized this isolated simulation. For this test only, the harness has verified and independently enforces the exact enumerated calls for ${caseId} recorded in the separate fixture approval ledger.`,
    JSON.stringify(
      ledger.artifact().records.map((record) => ({
        approvalId: record.approvalId,
        tool: record.tool,
        operation: record.operation,
        parameters: record.parameters,
        maximumCallCount: record.maximumCallCount,
        expiresAt: record.expiresAt,
      })),
    ),
  ];
  if (phase === "scope") {
    return [
      ...approval,
      "Execute only the approved read_incident_scope call. Use its available-source metadata and queryGuidance to prepare one adaptive approval envelope.",
      "The adaptive envelope should request exactly two aggregate_metrics calls using the supplied baseline and post-onset epoch-second windows. When logs are available, add one search_logs call over the post-onset epoch-second window with limit 20 and no literal. When traces are available, add one summarize_traces call over the supplied post-onset epoch-millisecond window with limit 20.",
      "End the turn with exactly one fenced JSON approvalRequests object. Do not call those adaptive tools yet and do not return the final RCA.",
    ].join("\n\n");
  }
  return [
    ...approval,
    "Execute the exact fixture calls for this isolated evaluation. Do not treat the fixture as reusable or production authority. Report blocked or unavailable evidence honestly. Return the required eight sections and a non-Complete stop state.",
  ].join("\n\n");
}

async function createCopilotClient(workspace: string): Promise<ModelClient> {
  const packageName = "@github/copilot-sdk";
  const sdk = (await import(packageName)) as {
    CopilotClient: new (options: unknown) => {
      start(): Promise<void>;
      stop(): Promise<unknown>;
      listModels(): Promise<readonly ModelInfo[]>;
      getStatus(): Promise<unknown>;
      createSession(config: unknown): Promise<{
        on(handler: (event: unknown) => void): () => void;
        sendAndWait(prompt: string, timeout: number): Promise<
          { data?: { content?: string } } | undefined
        >;
        destroy(): Promise<void>;
      }>;
    };
    defineTool(
      name: string,
      config: {
        description: string;
        parameters: Readonly<Record<string, unknown>>;
        handler: (parameters: Record<string, unknown>) => Promise<string>;
        skipPermission: boolean;
      },
    ): unknown;
  };
  const client = new sdk.CopilotClient({
    mode: "empty",
    workingDirectory: workspace,
    baseDirectory: join(workspace, ".copilot-home"),
    logLevel: "error",
  });
  return {
    start: () => client.start(),
    stop: async () => {
      await client.stop();
    },
    listModels: () => client.listModels(),
    getStatus: () => client.getStatus(),
    createSession: async (config) => {
      const session = await client.createSession({
        sessionId: config.sessionId,
        clientName: "hve-core-rca-evaluation",
        workingDirectory: config.workingDirectory,
        model: config.model,
        reasoningEffort: config.reasoningEffort,
        contextTier: config.contextTier,
        systemMessage: { mode: "append", content: config.systemMessage },
        tools: config.tools.map((tool) =>
          sdk.defineTool(tool.name, {
            description: tool.description,
            parameters: tool.parameters,
            handler: tool.handler,
            skipPermission: true,
          }),
        ),
        availableTools: config.tools.map((tool) => `custom:${tool.name}`),
        excludedTools: ["builtin:*", "mcp:*"],
        onPermissionRequest: async () => ({
          kind: "reject",
          feedback: "Only independently enforced simulated fixture approvals are available.",
        }),
      });
      return {
        onEvent: (handler) => session.on(handler),
        sendAndWait: async (prompt, timeout) => {
          const response = await session.sendAndWait(prompt, timeout);
          const content = response?.data?.content;
          return typeof content === "string" ? { content } : undefined;
        },
        destroy: () => session.destroy(),
      };
    },
  };
}

/** Redacts host paths and credential-shaped values before trace persistence. */
export function redactArtifact<T>(value: T, explicitValues: readonly string[]): {
  readonly value: T;
  readonly replacements: number;
} {
  let text = stableJson(value);
  let replacements = 0;
  for (const secret of explicitValues.filter((item) => item.length >= 4)) {
    const encodedSecret = JSON.stringify(secret).slice(1, -1);
    const next = text.split(encodedSecret).join("[REDACTED_PATH]");
    if (next !== text) {
      replacements += text.split(encodedSecret).length - 1;
      text = next;
    }
  }
  text = text.replace(/[A-Za-z]:\\\\Users\\\\[^\\"/]+/gi, () => {
    replacements += 1;
    return "[REDACTED_HOME]";
  });
  text = text.replace(/\/(?:home|Users)\/[^/\\"']+/g, () => {
    replacements += 1;
    return "[REDACTED_HOME]";
  });
  const patterns = [
    /(?:ghp|github_pat|gho|ghu|ghs)_[A-Za-z0-9_]{20,}/g,
    /(?:Bearer\s+)[A-Za-z0-9._~+/=-]{16,}/gi,
    /(?:api[_-]?key|token|password|secret)["']?\s*[:=]\s*["'][^"']+["']/gi,
  ];
  for (const pattern of patterns) {
    text = text.replace(pattern, () => {
      replacements += 1;
      return "[REDACTED_CREDENTIAL]";
    });
  }
  return { value: JSON.parse(text) as T, replacements };
}
