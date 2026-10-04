// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  PARSER_RULE,
  TOOL_NAME,
  assertShellcheckVersion,
  discoverFiles,
  extractRunScripts,
  getManifestShellcheckVersion,
  getParserFindings,
  getShellcheckFindings,
  toSarif,
} from '../validator.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', '..');

function makeRepo(files) {
  const root = mkdtempSync(join(tmpdir(), 'wfv-test-'));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

describe('discoverFiles', () => {
  it('lists workflow YAML files and nested composite actions in a stable order', () => {
    const root = makeRepo({
      '.github/workflows/b.yml': 'x',
      '.github/workflows/a.yaml': 'x',
      '.github/workflows/README.md': 'x',
      '.github/actions/setup/action.yml': 'x',
      '.github/actions/nested/deep/action.yaml': 'x',
      '.github/actions/setup/other.yml': 'x',
    });
    assert.deepEqual(discoverFiles(root), [
      { path: '.github/workflows/a.yaml', kind: 'workflow' },
      { path: '.github/workflows/b.yml', kind: 'workflow' },
      { path: '.github/actions/nested/deep/action.yaml', kind: 'action' },
      { path: '.github/actions/setup/action.yml', kind: 'action' },
    ]);
  });
});

describe('getParserFindings', () => {
  it('accepts a valid workflow, including queue and job.workflow_sha', async () => {
    const content = [
      'on: push',
      'concurrency:',
      '  group: x',
      '  queue: max',
      'jobs:',
      '  a:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - run: echo "${{ job.workflow_sha }}"',
    ].join('\n');
    assert.deepEqual(await getParserFindings('ok.yml', content, 'workflow'), []);
  });

  it('reports an expression syntax error at its line', async () => {
    const content = 'on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo ${{ github.x( }}\n';
    const findings = await getParserFindings('bad.yml', content, 'workflow');
    assert.equal(findings.length, 1);
    assert.equal(findings[0].ruleId, PARSER_RULE);
    assert.equal(findings[0].line, 6);
    assert.match(findings[0].message, /Unexpected symbol/);
  });

  it('reports a needs reference to an unknown job from the conversion stage', async () => {
    const content = 'on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo hi\n  b:\n    needs: missing\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo hi\n';
    const findings = await getParserFindings('needs.yml', content, 'workflow');
    assert.deepEqual(findings.map((finding) => [finding.line, finding.message]), [[8, "Job 'b' depends on unknown job 'missing'."]]);
  });

  it('validates composite actions with the action schema', async () => {
    const valid = 'name: x\ndescription: y\nruns:\n  using: composite\n  steps:\n    - run: echo hi\n      shell: bash\n';
    assert.deepEqual(await getParserFindings('action.yml', valid, 'action'), []);
    const invalid = 'name: x\ndescription: y\nruns:\n  using: composite\n  steps:\n    - unknown-key: 1\n';
    assert.ok((await getParserFindings('action.yml', invalid, 'action')).length > 0);
  });
});

describe('extractRunScripts', () => {
  it('maps block scripts line by line and masks expressions with same-length placeholders', () => {
    const content = [
      'on: push',
      'jobs:',
      '  a:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - run: |',
      '          echo "${{ github.sha }}"',
      '          echo done',
    ].join('\n');
    const [script] = extractRunScripts(content, 'workflow');
    assert.equal(script.dialect, 'bash');
    assert.equal(script.text, `echo "${'_'.repeat('${{ github.sha }}'.length)}"\necho done\n`);
    assert.deepEqual(script.lines.slice(0, 2), [
      { line: 7, column: 11 },
      { line: 8, column: 11 },
    ]);
  });

  it('maps inline and quoted scripts to their own line and column', () => {
    const content = 'on: push\njobs:\n  a:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: echo hi\n      - run: "echo quoted"\n';
    const scripts = extractRunScripts(content, 'workflow');
    assert.deepEqual(scripts.map((script) => script.lines[0]), [
      { line: 6, column: 14 },
      { line: 7, column: 15 },
    ]);
  });

  it('resolves the shell from step, job defaults, and workflow defaults', () => {
    const content = [
      'on: push',
      'defaults:',
      '  run:',
      '    shell: pwsh',
      'jobs:',
      '  pwsh-job:',
      '    runs-on: ubuntu-24.04',
      '    steps:',
      '      - run: Write-Output skipped',
      '      - run: echo step-bash',
      '        shell: bash',
      '  sh-job:',
      '    runs-on: ubuntu-24.04',
      '    defaults:',
      '      run:',
      '        shell: sh -e {0}',
      '    steps:',
      '      - run: echo job-sh',
      '      - run: print("skipped")',
      '        shell: python',
    ].join('\n');
    assert.deepEqual(
      extractRunScripts(content, 'workflow').map((script) => [script.dialect, script.text.trim()]),
      [
        ['bash', 'echo step-bash'],
        ['sh', 'echo job-sh'],
      ],
    );
  });

  it('reads composite action steps and needs an explicit shell there', () => {
    const content = 'name: x\nruns:\n  using: composite\n  steps:\n    - run: echo a\n      shell: bash\n    - run: echo b\n';
    assert.deepEqual(extractRunScripts(content, 'action').map((script) => script.text), ['echo a']);
  });
});

describe('getShellcheckFindings', () => {
  const script = { dialect: 'bash', text: 'echo $x\n', lines: [{ line: 10, column: 11 }] };

  it('maps shellcheck comments to the workflow line and column and passes source arguments', () => {
    let captured;
    const run = (command, args) => {
      captured = { command, args };
      const file = args.at(-1);
      return { status: 1, stdout: JSON.stringify({ comments: [{ file, line: 1, column: 6, level: 'info', code: 2086, message: 'Double quote' }] }) };
    };
    const findings = getShellcheckFindings([{ file: '.github/workflows/w.yml', script }], { shellcheck: '/bin/sc', sourcePath: '/repo', run });
    assert.equal(captured.command, '/bin/sc');
    assert.ok(captured.args.includes('--shell=bash'));
    assert.ok(captured.args.includes('--external-sources'));
    assert.ok(captured.args.includes('--source-path=/repo'));
    assert.deepEqual(findings, [
      { ruleId: 'shellcheck/SC2086', level: 'note', message: 'SC2086: Double quote', file: '.github/workflows/w.yml', line: 10, column: 16 },
    ]);
  });

  it('fails when shellcheck cannot analyze the scripts', () => {
    const run = () => ({ status: 3, stdout: '', stderr: 'bad option' });
    assert.throws(() => getShellcheckFindings([{ file: 'w.yml', script }], { shellcheck: 'sc', run }), /exited 3: bad option/);
  });

  it('returns no findings without scripts and does not run shellcheck', () => {
    assert.deepEqual(getShellcheckFindings([], { shellcheck: 'sc', run: () => assert.fail('should not run') }), []);
  });
});

describe('assertShellcheckVersion', () => {
  it('accepts only the manifest version', () => {
    const run = (version) => () => ({ status: 0, stdout: `ShellCheck\nversion: ${version}\n` });
    assert.equal(assertShellcheckVersion('sc', '0.11.0', run('0.11.0')), '0.11.0');
    assert.throws(() => assertShellcheckVersion('sc', '0.11.0', run('0.9.0')), /is 0\.9\.0/);
    assert.throws(() => assertShellcheckVersion('sc', '0.11.0', () => ({ status: null, error: new Error('ENOENT') })), /could not run/);
  });

  it('reads the shellcheck version from the tool manifest', () => {
    const manifest = JSON.parse(readFileSync(join(repoRoot, 'scripts', 'security', 'tool-checksums.json'), 'utf8'));
    assert.equal(getManifestShellcheckVersion(repoRoot), manifest.tools.find((tool) => tool.name === 'shellcheck').version);
  });
});

describe('toSarif', () => {
  it('builds SARIF with every rule and located results', () => {
    const sarif = toSarif([{ ruleId: 'shellcheck/SC2086', level: 'note', message: 'm', file: 'w.yml', line: 0, column: 0 }], '0.0.0');
    assert.equal(sarif.version, '2.1.0');
    assert.equal(sarif.runs[0].tool.driver.name, TOOL_NAME);
    assert.deepEqual(sarif.runs[0].tool.driver.rules.map((rule) => rule.id), ['shellcheck/SC2086', PARSER_RULE]);
    assert.deepEqual(sarif.runs[0].results[0].locations[0].physicalLocation.region, { startLine: 1, startColumn: 1 });
  });
});

describe('repository', () => {
  it('parses every workflow and composite action with no parser errors', async () => {
    const findings = [];
    for (const file of discoverFiles(repoRoot)) {
      findings.push(...(await getParserFindings(file.path, readFileSync(join(repoRoot, file.path), 'utf8'), file.kind)));
    }
    assert.deepEqual(findings, []);
  });
});
