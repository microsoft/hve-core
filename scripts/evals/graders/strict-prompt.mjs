// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import {
  PromptGrader,
  createCopilotLlmClient,
} from '@microsoft/vally';
import { z } from 'zod';

/** @type {readonly ['target', 'perspectives', 'confirmation', 'honest-scope']} */
const criterionIds = ['target', 'perspectives', 'confirmation', 'honest-scope'];
const binary = z.union([z.literal(0), z.literal(1)]);
const criterionScore = z.object({
  score: binary,
  reasoning: z.string().min(1),
}).strict();

/** Validates the four required marks and their submitted overall conjunction. */
export const strictVerdictSchema = z.object({
  rubric_scores: z.object({
    target: criterionScore,
    perspectives: criterionScore,
    confirmation: criterionScore,
    'honest-scope': criterionScore,
  }).strict(),
  overall_score: binary,
  overall_reasoning: z.string().min(1),
}).strict().superRefine((verdict, context) => {
  const allPass = criterionIds.every(id => verdict.rubric_scores[id].score === 1);
  if (verdict.overall_score !== Number(allPass)) {
    context.addIssue({ code: 'custom', message: 'criterion-conjunction-mismatch' });
  }
});

/** @param {import('@microsoft/vally').GraderInput} input */
function validateInput(input) {
  const rubric = input.stimulus?.rubric;
  if (input.stimulus?.tags?.scorecard !== 'complete' ||
      input.config?.scoring !== 'binary' || !input.trajectory ||
      !rubric || rubric.length !== criterionIds.length ||
      rubric.some((text, index) => typeof text !== 'string' || !text.startsWith(`[${criterionIds[index]}] `))) {
    throw new Error('Invalid strict prompt configuration.');
  }
  input.signal?.throwIfAborted();
}

/**
 * @param {import('@microsoft/vally').GraderInput} input
 * @param {number} started
 * @returns {import('@microsoft/vally').GraderInput}
 */
function remainingInput(input, started) {
  input.signal?.throwIfAborted();
  if (input.timeoutMs === undefined) return input;
  const remaining = input.timeoutMs - (performance.now() - started);
  if (!Number.isFinite(remaining) || remaining <= 0) {
    throw new Error('Strict prompt grading timed out during startup.');
  }
  return { ...input, timeoutMs: remaining };
}

/**
 * @param {import('@microsoft/vally').LlmClient} client
 * @returns {import('@microsoft/vally').LlmClient}
 */
function strictClient(client) {
  return {
    supportsWorkspaceDelivery: true,
    shutdown: () => client.shutdown(),
    /**
     * @template TArgs
     * @param {import('@microsoft/vally').LlmJudgeOptions<TArgs>} options
     * @returns {Promise<import('@microsoft/vally').LlmJudgeResponse<TArgs>>}
     */
    async judge(options) {
      if (options.tool.name !== 'submit_grade') {
        throw new Error('Unsupported strict prompt verdict tool.');
      }
      const response = await client.judge({
        ...options,
        userMessage: `${options.userMessage}\n\nSubmit rubric_scores as the required four-key object shown in the tool schema, not an array.`,
        tool: { ...options.tool, parameters: strictVerdictSchema },
      });
      const validated = strictVerdictSchema.safeParse(response.args);
      if (!validated.success) throw new Error('Invalid strict prompt verdict form.');
      const verdict = validated.data;
      const projected = options.tool.parameters.safeParse({
        rubric_scores: criterionIds.map(criterion => ({
          criterion,
          ...verdict.rubric_scores[criterion],
        })),
        overall_score: verdict.overall_score,
        overall_reasoning: verdict.overall_reasoning,
      });
      if (!projected.success) throw new Error('Invalid native strict prompt projection.');
      return { ...response, args: projected.data };
    },
  };
}

/**
 * Creates an inert native grader; each grade owns and awaits its client's shutdown.
 * The factory is called only after valid configuration and a non-aborted input.
 * A client returned after cancellation is closed without grading. Native startup
 * itself is not cancellable through the public factory.
 * @param {() => Promise<import('@microsoft/vally').LlmClient>} createClient
 * @returns {import('@microsoft/vally').Grader}
 */
export function createStrictPromptGrader(
  createClient = createCopilotLlmClient,
) {
  return {
    metadata: {
      name: 'strict-prompt',
      description: 'Native prompt grading with a complete four-mark verdict form',
      behavior: { requiresLlmClient: true },
      determinism: 'llm',
      reference: 'reference-free',
      temporalScope: 'trajectory-level',
      costProfile: 'high',
    },
    defaultName: () => 'strict-prompt',
    async grade(input) {
      validateInput(input);
      const started = performance.now();
      remainingInput(input, started);
      const client = await createClient();
      let failed = false;
      /** @type {unknown} */
      let failure;
      /** @type {import('@microsoft/vally').GraderResult | undefined} */
      let result;
      try {
        const remaining = remainingInput(input, started);
        if (client.supportsWorkspaceDelivery !== true) {
          throw new Error('Strict prompt client lacks native evidence delivery.');
        }
        result = await new PromptGrader(strictClient(client)).grade(remaining);
        input.signal?.throwIfAborted();
        return { ...result, name: 'strict-prompt' };
      } catch (error) {
        failed = true;
        failure = error;
        throw error;
      } finally {
        try {
          await client.shutdown();
        } catch (error) {
          if (failed || result?.status === 'error') {
            throw new AggregateError(
              [failed ? failure : new Error('Native strict prompt grading failed.'), error],
              'Strict prompt grading and cleanup failed.',
            );
          }
          throw new Error('Strict prompt client cleanup failed.', { cause: error });
        }
        if (!failed) input.signal?.throwIfAborted();
      }
    },
  };
}

/**
 * Registers the native type without creating a client or replacing built-in graders.
 * @param {import('@microsoft/vally').GraderRegistry} registry
 */
export function registerGraders(registry) {
  registry.register(createStrictPromptGrader());
}
