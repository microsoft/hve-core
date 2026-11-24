// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import {
  PromptGrader,
  createDefaultGraderRegistry,
  gradeTrajectory,
  loadGraderPlugin,
} from '@microsoft/vally';
import { z } from 'zod';
import {
  createStrictPromptGrader,
  strictVerdictSchema,
} from '../../evals/graders/strict-prompt.mjs';

const ids = ['target', 'perspectives', 'confirmation', 'honest-scope'];
const pluginPath = fileURLToPath(new URL('../../evals/graders/strict-prompt.mjs', import.meta.url));

function verdict(negative = false) {
  return {
    rubric_scores: Object.fromEntries(ids.map(id => [id, {
      score: negative && id === 'perspectives' ? 0 : 1,
      reasoning: 'Synthetic private grading evidence.',
    }])),
    overall_score: negative ? 0 : 1,
    overall_reasoning: 'Synthetic private overall evidence.',
  };
}

function input() {
  const stimulus = {
    name: 'code-review-branch-diff-standard-profile',
    prompt: 'Synthetic plumbing check, not semantic calibration.',
    tags: { scorecard: 'complete' },
    rubric: ids.map(id => `[${id}] Synthetic criterion.`),
  };
  return {
    stimulus,
    config: { scoring: 'binary', threshold: 0.85, model: 'claude-sonnet-5' },
    trajectory: { id: 'synthetic-control', stimulus, events: [], output: 'Synthetic answer.' },
  };
}

function fakeClient(response = verdict()) {
  const calls = { requests: [], shutdown: 0 };
  const client = {
    supportsWorkspaceDelivery: true,
    async judge(options) {
      calls.requests.push(options);
      assert.ok(options.workspace);
      await access(options.workspace.workingDirectory);
      const value = typeof response === 'function' ? await response(options) : response;
      const parsed = options.tool.parameters.safeParse(value);
      if (!parsed.success) throw new Error('Synthetic invalid form.');
      return {
        args: parsed.data,
        tokenUsage: { inputTokens: 10, outputTokens: 5, model: options.model },
        latencyMs: 1,
        remindersUsed: 0,
        evidenceUsage: { toolCalls: 1, chars: 10, budgetExhausted: false },
      };
    },
    async shutdown() { calls.shutdown++; },
  };
  return { client, calls };
}

test('requires exactly the configured fixed fields, binary marks and overall conjunction', () => {
  assert.equal(strictVerdictSchema.safeParse(verdict()).success, true);
  assert.equal(strictVerdictSchema.safeParse(verdict(true)).success, true);
  const mutations = [
    v => { delete v.rubric_scores.target; },
    v => { v.rubric_scores.extra = { score: 1, reasoning: 'Unexpected.' }; },
    v => { v.rubric_scores.Target = v.rubric_scores.target; delete v.rubric_scores.target; },
    v => { v.rubric_scores = Object.entries(v.rubric_scores); },
    v => { v.rubric_scores.target.score = true; },
    v => { v.rubric_scores.target.score = 0.5; },
    v => { v.rubric_scores.target.score = 2; },
    v => { v.rubric_scores.target.score = -1; },
    v => { v.rubric_scores.target.score = '1'; },
    v => { v.rubric_scores.target.reasoning = ''; },
    v => { v.rubric_scores.target.extra = 'Unexpected.'; },
    v => { v.overall_score = 0; },
    v => { v.overall_score = true; },
    v => { v.overall_reasoning = ''; },
    v => { v.extra = 'Unexpected.'; },
  ];
  for (const mutate of mutations) {
    const value = verdict();
    mutate(value);
    assert.equal(strictVerdictSchema.safeParse(value).success, false);
  }
  const schema = z.toJSONSchema(strictVerdictSchema);
  assert.deepEqual(schema.properties.rubric_scores.required, ids);
  assert.equal(schema.properties.rubric_scores.additionalProperties, false);
});

test('maps validated positive and negative forms through the real native prompt grader once', async () => {
  for (const negative of [false, true]) {
    const { client, calls } = fakeClient(verdict(negative));
    const result = await createStrictPromptGrader(async () => client).grade(input());
    assert.notEqual(result.status, 'error');
    assert.equal(result.passed, !negative);
    assert.equal(result.score, negative ? 0 : 1);
    assert.equal(result.name, 'strict-prompt');
    assert.equal(calls.requests.length, 1);
    assert.equal(calls.shutdown, 1);
    assert.deepEqual(result.metadata.rubric_scores.map(row => row.criterion), ids);
    assert.equal(result.details.length, 4);
    assert.equal(result.metadata.model, 'claude-sonnet-5');
    assert.equal(result.metadata.scoring, 'binary');
    assert.equal(result.metadata.threshold, 0.85);
    assert.equal(result.metadata.rubric_source, 'stimulus');
    assert.equal(result.metadata.token_usage.inputTokens, 10);
    assert.equal(result.metadata.reminders_used, 0);
    await assert.rejects(access(calls.requests[0].workspace.workingDirectory));
  }
});

test('loads and registers the native plugin without creating a client or replacing prompt', async () => {
  let starts = 0;
  const grader = createStrictPromptGrader(async () => {
    starts++;
    throw new Error('A registration must not create a client.');
  });
  assert.equal(grader.metadata.behavior.requiresLlmClient, true);
  assert.equal(grader.defaultName({ prompt: 'Synthetic private text.' }), 'strict-prompt');
  assert.equal(starts, 0);
  const { client } = fakeClient();
  const registry = createDefaultGraderRegistry(client);
  const original = registry.get('prompt');
  await loadGraderPlugin(pluginPath, registry);
  assert.equal(registry.get('prompt'), original);
  assert.equal(registry.get('strict-prompt').metadata.name, 'strict-prompt');
  assert.equal(starts, 0);
});

test('preserves public pipeline model, effort, provider, timeout, signal and native evidence', async () => {
  const { client, calls } = fakeClient();
  const registry = createDefaultGraderRegistry();
  registry.register(createStrictPromptGrader(async () => client));
  const value = input();
  const config = { ...value.config };
  delete config.model;
  const provider = { baseUrl: 'https://example.invalid', apiKeyEnv: 'SYNTHETIC_UNSET_KEY' };
  const result = await gradeTrajectory(value.trajectory, [{
    name: 'branch-standard-profile-contract',
    type: 'strict-prompt',
    config,
  }], {
    registry,
    stimulus: value.stimulus,
    judgeModel: 'claude-sonnet-5',
    judgeReasoningEffort: 'high',
    judgeProvider: provider,
    graderTimeoutMs: 10_000,
  });
  assert.equal(result.passed, true);
  assert.equal(result.details[0].graderType, 'strict-prompt');
  assert.equal(result.details[0].configuredName, 'branch-standard-profile-contract');
  const request = calls.requests[0];
  assert.equal(request.model, 'claude-sonnet-5');
  assert.equal(request.reasoningEffort, 'high');
  assert.deepEqual(request.provider, provider);
  assert.ok(request.timeoutMs > 0 && request.timeoutMs <= 10_000);
  assert.ok(request.signal instanceof AbortSignal);
  assert.ok(request.workspace.evidenceFiles.length > 0);
  assert.ok(request.userMessage.includes('Synthetic criterion.'));
  assert.ok(request.userMessage.includes('four-key object'));
  assert.equal(calls.shutdown, 1);
});

test('owns clients through success, errors, aborted startup and cleanup failure', async () => {
  const before = new AbortController();
  before.abort(new Error('Synthetic pre-start abort.'));
  let starts = 0;
  await assert.rejects(createStrictPromptGrader(async () => {
    starts++;
    return fakeClient().client;
  }).grade({ ...input(), signal: before.signal }), /pre-start abort/);
  assert.equal(starts, 0);
  await assert.rejects(createStrictPromptGrader(async () => {
    throw new Error('Synthetic startup failure.');
  }).grade(input()), /startup failure/);

  const controller = new AbortController();
  const late = fakeClient();
  let finishStartup;
  const startup = new Promise(resolve => { finishStartup = resolve; });
  const pending = createStrictPromptGrader(() => startup).grade({ ...input(), signal: controller.signal });
  controller.abort(new Error('Synthetic late-start abort.'));
  finishStartup(late.client);
  await assert.rejects(pending, /late-start abort/);
  assert.equal(late.calls.requests.length, 0);
  assert.equal(late.calls.shutdown, 1);

  const failed = fakeClient(() => { throw new Error('Synthetic judge failure.'); });
  const result = await createStrictPromptGrader(async () => failed.client).grade(input());
  assert.equal(result.status, 'error');
  assert.equal(failed.calls.shutdown, 1);

  const cleanup = fakeClient();
  cleanup.client.shutdown = async () => {
    cleanup.calls.shutdown++;
    throw new Error('Synthetic cleanup failure.');
  };
  await assert.rejects(createStrictPromptGrader(async () => cleanup.client).grade(input()), /client cleanup failed/);
  assert.equal(cleanup.calls.shutdown, 1);

  const both = fakeClient(() => { throw new Error('Synthetic native failure.'); });
  both.client.shutdown = async () => { throw new Error('Synthetic cleanup failure.'); };
  await assert.rejects(createStrictPromptGrader(async () => both.client).grade(input()),
    error => error instanceof AggregateError && error.errors.length === 2);

  const duringCleanup = new AbortController();
  const interrupted = fakeClient();
  interrupted.client.shutdown = async () => {
    interrupted.calls.shutdown++;
    duringCleanup.abort(new Error('Synthetic cleanup-time abort.'));
  };
  await assert.rejects(createStrictPromptGrader(async () => interrupted.client).grade({
    ...input(), signal: duringCleanup.signal,
  }), /cleanup-time abort/);
  assert.equal(interrupted.calls.shutdown, 1);

  const unsupported = fakeClient();
  unsupported.client.supportsWorkspaceDelivery = false;
  await assert.rejects(createStrictPromptGrader(async () => unsupported.client).grade(input()), /lacks native evidence/);
  assert.equal(unsupported.calls.shutdown, 1);

  const expired = fakeClient();
  let expiredStarts = 0;
  await assert.rejects(createStrictPromptGrader(async () => {
    expiredStarts++;
    return expired.client;
  }).grade({
    ...input(), timeoutMs: 0,
  }), /timed out during startup/);
  assert.equal(expiredStarts, 0);
  assert.equal(expired.calls.requests.length, 0);
  assert.equal(expired.calls.shutdown, 0);

  const timedOut = fakeClient();
  await assert.rejects(createStrictPromptGrader(async () => {
    await new Promise(resolve => setTimeout(resolve, 20));
    return timedOut.client;
  }).grade({ ...input(), timeoutMs: 5 }), /timed out during startup/);
  assert.equal(timedOut.calls.requests.length, 0);
  assert.equal(timedOut.calls.shutdown, 1);
});

test('keeps malformed forms as native errors and leaves non-opted-in prompt behavior isolated', async () => {
  let starts = 0;
  const invalid = input();
  invalid.stimulus.tags.scorecard = 'unknown';
  await assert.rejects(createStrictPromptGrader(async () => {
    starts++;
    return fakeClient().client;
  }).grade(invalid), /Invalid strict prompt configuration/);
  assert.equal(starts, 0);
  for (const mutate of [
    v => { delete v.rubric_scores.target; },
    v => { v.rubric_scores.extra = { score: 1, reasoning: 'Unexpected.' }; },
    v => { v.overall_score = 0; },
  ]) {
    const value = verdict();
    mutate(value);
    const { client, calls } = fakeClient(value);
    const result = await createStrictPromptGrader(async () => client).grade(input());
    assert.equal(result.status, 'error');
    assert.equal(result.passed, false);
    assert.equal(result.metadata.rubric_scores, undefined);
    assert.equal(calls.requests.length, 1);
    assert.equal(calls.shutdown, 1);
  }
  const bypass = fakeClient();
  const extra = verdict();
  extra.rubric_scores.extra = { score: 1, reasoning: 'Untrusted.' };
  bypass.client.judge = async () => ({ args: extra, latencyMs: 1, remindersUsed: 0 });
  const rejected = await createStrictPromptGrader(async () => bypass.client).grade(input());
  assert.equal(rejected.status, 'error');
  assert.equal(rejected.metadata.rubric_scores, undefined);
  assert.equal(bypass.calls.shutdown, 1);
  const client = {
    supportsWorkspaceDelivery: true,
    async judge() {
      return { args: {
        rubric_scores: [{ criterion: 'Independent native criterion', score: 1, reasoning: 'Synthetic.' }],
        overall_score: 1, overall_reasoning: 'Synthetic.',
      }, latencyMs: 1, remindersUsed: 0 };
    },
    async shutdown() {},
  };
  const value = input();
  delete value.stimulus.tags.scorecard;
  const result = await new PromptGrader(client).grade(value);
  assert.notEqual(result.status, 'error');
  assert.equal(result.details.length, 1);
});
