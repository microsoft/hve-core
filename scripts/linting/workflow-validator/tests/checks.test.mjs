// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { describe, it } from 'node:test';
import { filterPatternProblem, getCheckFindings } from '../checks.mjs';

const SHA = 'b'.repeat(40);

function makeRepo(files = {}) {
  const root = mkdtempSync(join(tmpdir(), 'wfv-checks-'));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

async function check(content, { kind = 'workflow', files = {}, fetchText = async () => null, cacheDir } = {}) {
  const repoRoot = makeRepo(files);
  return getCheckFindings('w.yml', content, kind, { repoRoot, fetchText, cacheDir });
}

const rules = (findings) => findings.map((finding) => finding.ruleId);

describe('expression references', () => {
  it('accepts defined steps, needs, matrix keys, inputs, and known context properties', async () => {
    const content = [
      'on:',
      '  workflow_dispatch:',
      '    inputs:',
      '      Target:',
      '        type: string',
      'jobs:',
      '  first:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - run: echo hi',
      '  second:',
      '    needs: [first]',
      '    runs-on: ubuntu-24.04',
      '    strategy:',
      '      matrix:',
      '        os: [a]',
      '        include:',
      '          - extra: 1',
      '    steps:',
      '      - id: build',
      '        run: echo "${{ inputs.target }} ${{ matrix.os }} ${{ matrix.extra }} ${{ strategy.job-index }}"',
      '      - if: steps.build.outcome == \'success\' && needs.first.result == \'success\'',
      '        run: echo "${{ github.event.issue.number }} ${{ runner.temp }} ${{ job.workflow_sha }} ${{ steps.build.outputs.x }}"',
    ].join('\n');
    assert.deepEqual(await check(content), []);
  });

  it('reports each undefined reference at its column', async () => {
    const content = [
      'on: push',
      'jobs:',
      '  a:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - run: echo "${{ github.nope }} ${{ steps.none.outputs.x }} ${{ needs.none.result }} ${{ matrix.none }} ${{ inputs.none }}"',
    ].join('\n');
    const findings = await check(content);
    assert.deepEqual(rules(findings), [
      'workflow-check/unknown-context-property',
      'workflow-check/undefined-step',
      'workflow-check/undefined-need',
      'workflow-check/undefined-matrix-key',
      'workflow-check/undefined-input',
    ]);
    assert.deepEqual(findings.map((finding) => finding.line), [6, 6, 6, 6, 6]);
    assert.equal(findings[0].column, 24);
  });

  it('reports a bad step or needs property and ignores names inside string literals', async () => {
    const content = [
      'on: push',
      'jobs:',
      '  a:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - id: s',
      '        run: echo hi',
      '      - if: steps.s.result == \'github.nope and steps.x.y\'',
      '        run: echo hi',
    ].join('\n');
    const findings = await check(content);
    assert.deepEqual(rules(findings), ['workflow-check/unknown-context-property']);
    assert.match(findings[0].message, /steps\.s\.result/);
  });

  it('skips matrix keys computed by an expression', async () => {
    const content = [
      'on: push',
      'jobs:',
      '  a:',
      '    runs-on: ubuntu-24.04',
      '    strategy:',
      '      matrix: ${{ fromJSON(\'{"x":[1]}\') }}',
      '    steps:',
      '      - run: echo "${{ matrix.anything }}"',
    ].join('\n');
    assert.deepEqual(await check(content), []);
  });

  it('reports steps, needs, and matrix references outside a job', async () => {
    const content = 'on: push\nrun-name: ${{ steps.a.outputs.x }} ${{ matrix.y }}\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo hi\n';
    assert.deepEqual(rules(await check(content)), ['workflow-check/undefined-step', 'workflow-check/undefined-matrix-key']);
  });

  it('checks composite actions against their declared inputs and step ids', async () => {
    const content = [
      'name: x',
      'inputs:',
      '  token:',
      '    description: t',
      'runs:',
      '  using: composite',
      '  steps:',
      '    - id: one',
      '      run: echo "${{ inputs.token }} ${{ steps.one.outputs.v }} ${{ inputs.other }}"',
      '      shell: bash',
    ].join('\n');
    assert.deepEqual(rules(await check(content, { kind: 'action' })), ['workflow-check/undefined-input']);
  });
});

describe('if: conditions', () => {
  it('reports text outside the expression and accepts a single expression', async () => {
    const workflow = (condition) => `on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - if: ${condition}\n        run: echo hi\n`;
    assert.deepEqual(rules(await check(workflow("${{ github.ref == 'refs/heads/main' }}"))), []);
    assert.deepEqual(rules(await check(workflow("github.ref == 'refs/heads/main'"))), []);
    assert.deepEqual(rules(await check(workflow('${{ false }} && ${{ false }}'))), ['workflow-check/always-true-if']);
    assert.deepEqual(rules(await check(workflow('"${{ github.ref }} == \'refs/heads/main\'"'))), ['workflow-check/always-true-if']);
  });
});

describe('filterPatternProblem', () => {
  it('accepts valid patterns', () => {
    for (const pattern of ['main', 'releases/**', '!docs/**', '**/*.md', 'v[0-9]+.*', 'a\\*b', '[a-z]?']) {
      assert.equal(filterPatternProblem(pattern), null, pattern);
    }
  });

  it('reports invalid patterns', () => {
    assert.match(filterPatternProblem(''), /empty/);
    assert.match(filterPatternProblem('!'), /followed by/);
    assert.match(filterPatternProblem('src/[abc'), /no matching ']'/);
    assert.match(filterPatternProblem('src/abc]'), /no matching '\['/);
    assert.match(filterPatternProblem('[]'), /empty/);
    assert.match(filterPatternProblem('[z-a]'), /reversed/);
    assert.match(filterPatternProblem('trailing\\'), /escape/);
    assert.match(filterPatternProblem(' padded'), /whitespace/);
  });

  it('checks branch, tag, and path filters of every event', async () => {
    const content = "on:\n  pull_request:\n    branches: ['main', '[x']\n    paths-ignore: ['docs/]']\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo hi\n";
    const findings = await check(content);
    assert.deepEqual(rules(findings), ['workflow-check/invalid-path-filter', 'workflow-check/invalid-path-filter']);
    assert.deepEqual(findings.map((finding) => finding.line), [3, 4]);
  });
});

describe('run scripts and env', () => {
  it('reports disabled workflow commands', async () => {
    const content = 'on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: |\n          echo ok\n          echo "::save-state name=a::b"\n';
    const findings = await check(content);
    assert.deepEqual(rules(findings), ['workflow-check/deprecated-workflow-command']);
    assert.equal(findings[0].line, 8);
  });

  it('reports invalid env names at every level', async () => {
    const content = 'on: push\nenv:\n  GOOD_1: a\n  1BAD: b\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    env:\n      bad-name: c\n    steps:\n      - run: echo hi\n        env:\n          "has space": d\n';
    assert.deepEqual(rules(await check(content)), Array(3).fill('workflow-check/invalid-env-name'));
  });
});

describe('action and reusable workflow inputs', () => {
  const step = (uses, withLines) => `on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - uses: ${uses}\n        with:\n${withLines}`;

  it('checks local composite action inputs case-insensitively', async () => {
    const files = { '.github/actions/local/action.yml': 'name: l\ninputs:\n  Known:\n    description: k\nruns:\n  using: composite\n  steps: []\n' };
    for (const prefix of ['./', '$/']) {
      const findings = await check(step(`${prefix}.github/actions/local`, '          known: 1\n          unknown: 2\n'), { files });
      assert.deepEqual(rules(findings), ['workflow-check/unknown-action-input'], prefix);
      assert.match(findings[0].message, /'unknown'/);
    }
  });

  it('reads remote metadata at the pinned commit, allows docker args, and caches by commit', async () => {
    const cacheDir = mkdtempSync(join(tmpdir(), 'wfv-cache-'));
    const fetched = [];
    const fetchText = async (url) => {
      fetched.push(url);
      return url.endsWith('/sub/action.yml') ? 'name: d\ninputs:\n  token:\n    description: t\nruns:\n  using: docker\n  image: Dockerfile\n' : null;
    };
    const content = step(`org/repo/sub@${SHA}`, '          token: x\n          args: y\n          bogus: z\n');
    assert.deepEqual(rules(await check(content, { fetchText, cacheDir })), ['workflow-check/unknown-action-input']);
    assert.deepEqual(fetched, [`https://raw.githubusercontent.com/org/repo/${SHA}/sub/action.yml`]);
    const refetched = [];
    await check(content, { fetchText: async (url) => { refetched.push(url); return null; }, cacheDir });
    assert.deepEqual(refetched, []);
  });

  it('fails closed when metadata cannot be read, and leaves unpinned refs to the pinning check', async () => {
    assert.deepEqual(rules(await check(step(`org/repo@${SHA}`, '          a: 1\n'))), ['workflow-check/action-metadata-unavailable']);
    assert.deepEqual(rules(await check(step('org/repo@v1', '          a: 1\n'))), []);
    assert.deepEqual(rules(await check(step('./.github/actions/missing', '          a: 1\n'))), ['workflow-check/action-metadata-unavailable']);
    assert.deepEqual(rules(await check(step('$/.github/actions/missing', '          a: 1\n'))), ['workflow-check/action-metadata-unavailable']);
  });

  it('checks reusable workflow inputs and secrets, including required ones', async () => {
    const files = {
      '.github/workflows/callee.yml': [
        'on:',
        '  workflow_call:',
        '    inputs:',
        '      needed:',
        '        type: string',
        '        required: true',
        '      optional:',
        '        type: string',
        '        required: true',
        '        default: x',
        '    secrets:',
        '      token:',
        '        required: true',
        'jobs: {}',
      ].join('\n'),
    };
    const caller = (extra, prefix = './') => `on: push\njobs:\n  call:\n    uses: ${prefix}.github/workflows/callee.yml\n${extra}`;
    const findings = await check(caller('    with:\n      bogus: 1\n'), { files });
    assert.deepEqual(rules(findings), ['workflow-check/unknown-action-input', 'workflow-check/missing-required-input', 'workflow-check/missing-required-input']);
    assert.deepEqual(rules(await check(caller('    with:\n      bogus: 1\n', '$/'), { files })), rules(findings));
    assert.deepEqual(rules(await check(caller('    with:\n      needed: 1\n    secrets: inherit\n'), { files })), []);
  });
});
