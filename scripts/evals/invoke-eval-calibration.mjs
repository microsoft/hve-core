// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import YAML from 'yaml';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const digest = bytes => `sha256:${createHash('sha256').update(bytes).digest('hex')}`;

export function prepareCalibration(profilePath, manifestPath, repoRoot = root) {
  const profileBytes = readFileSync(profilePath);
  const profile = JSON.parse(profileBytes);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const acceptance = manifest.acceptance;
  const inventory = acceptance?.inventory;
  if (!inventory || inventory.profileDigest !== digest(profileBytes) ||
      profile.executorModel !== 'gpt-6-luna' || profile.judgeModel !== 'claude-sonnet-5' ||
      profile.vallyVersion !== '0.16.0' || !Array.isArray(profile.calibration) ||
      profile.calibration.length < 2 || profile.calibration.length > 16 ||
      acceptance.checkout !== execFileSync('git', ['rev-parse', 'HEAD'], { cwd: repoRoot, encoding: 'utf8' }).trim()) {
    throw new Error('Calibration profile or checkout mismatch.');
  }
  const packageRoot = path.join(repoRoot, 'node_modules/@microsoft/vally-cli');
  const cliPackage = JSON.parse(readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
  const corePackage = JSON.parse(readFileSync(path.join(repoRoot, 'node_modules/@microsoft/vally/package.json'), 'utf8'));
  if (cliPackage.version !== profile.vallyVersion || corePackage.version !== profile.vallyVersion) {
    throw new Error('Calibration Vally version mismatch.');
  }
  const controls = profile.calibration.map(control => {
    const expected = inventory.calibration.filter(item => item.id === control.id);
    const selection = inventory.selections.find(item => item.specPath === control.specPath && item.requiredStimuli[control.stimulusName]);
    if (expected.length !== 1 || !selection || expected[0].graderName !== control.graderName ||
        expected[0].expectedPass !== control.expectedPass || typeof control.output !== 'string') {
      throw new Error('Calibration control mismatch.');
    }
    const specPath = path.resolve(repoRoot, 'evals', control.specPath);
    if (!specPath.startsWith(path.resolve(repoRoot, 'evals') + path.sep)) throw new Error('Invalid calibration spec path.');
    const bytes = readFileSync(specPath);
    if (digest(bytes) !== selection.specDigest) throw new Error('Calibration spec changed after selection.');
    const spec = YAML.parse(bytes.toString('utf8'));
    const stimulus = spec.stimuli.find(item => item.name === control.stimulusName);
    const grader = stimulus?.graders?.find(item => item.name === control.graderName && item.type === 'prompt');
    if (!grader) throw new Error('Calibration grader is unavailable.');
    const environment = stimulus.agent_environment || stimulus.environment;
    const reference = environment?.files?.find(file => file.dest === '.github/agents/project-planning/backlog-manager.agent.md');
    let referenceText;
    if (reference) {
      const referencePath = path.resolve(path.dirname(specPath), reference.src);
      if (!referencePath.startsWith(path.resolve(repoRoot, '.github') + path.sep)) throw new Error('Invalid calibration reference.');
      referenceText = readFileSync(referencePath, 'utf8').match(/^---\r?\n[\s\S]*?\r?\n---/)?.[0];
      if (!referenceText || referenceText.length > 14000) throw new Error('Calibration declarations are unavailable or exceed the evidence bound.');
    }
    return { ...control, specPath, stimulus, referenceText, judgeModel: profile.judgeModel, criterionCount: stimulus.rubric.length };
  });
  return { acceptance, controls, cli: path.join(packageRoot, cliPackage.bin.vally), judge: profile.judgeModel, version: profile.vallyVersion };
}

export function projectCalibrationGrade(control, raw, exitCode) {
  const failure = { id: control.id, status: 'error', passed: null, score: null, criteria: [] };
  if (exitCode !== 0) return failure;
  try {
    const records = raw.split(/\r?\n/).filter(line => line.trim()).map(line => JSON.parse(line));
    if (records.length !== 1 || records[0].status !== 'success') return failure;
    const grade = records[0].gradeResult;
    if ((grade?.status !== undefined && grade.status !== 'success') || !Array.isArray(grade?.details)) return failure;
    const matches = grade.details.filter(item => item.configuredName === control.graderName);
    if (matches.length !== 1) return failure;
    const result = matches[0];
    if ((result.status !== undefined && result.status !== 'success') || result.graderType !== 'prompt' || typeof result.passed !== 'boolean' ||
      !Number.isFinite(result.score) || result.score < 0 || result.score > 1 ||
      result.metadata?.model !== control.judgeModel || !Array.isArray(result.details) ||
      result.details.length !== control.criterionCount) return failure;
    const criteria = result.details.map((criterion, index) => ({ index, passed: criterion.passed, score: criterion.score }));
    if (criteria.some(criterion => typeof criterion.passed !== 'boolean' || !Number.isFinite(criterion.score) || criterion.score < 0 || criterion.score > 1)) return failure;
    return { id: control.id, status: 'success', passed: result.passed, score: result.score, criteria };
  } catch {
    return failure;
  }
}

export function executeCalibration(prepared, outputPath, runChild = spawnSync) {
  const output = path.resolve(outputPath);
  mkdirSync(path.dirname(output), { recursive: true });
  writeFileSync(`${output}.started`, prepared.acceptance.inventory.profileDigest, { flag: 'wx', mode: 0o600 });
  const privateRoot = mkdtempSync(path.join(process.env.RUNNER_TEMP || tmpdir(), 'vally-calibration-'));
  const results = [];
  for (const control of prepared.controls) {
    const workDir = path.join(privateRoot, control.id);
    mkdirSync(workDir, { mode: 0o700 });
    const events = [];
    if (control.referenceText) {
      for (let offset = 0; offset < control.referenceText.length; offset += 350) {
        const callId = `synthetic-artifact-read-${offset}`;
        events.push({ type: 'tool_call', data: { toolName: 'read_file', toolCallId: callId, simulated: true, arguments: { path: '.github/agents/project-planning/backlog-manager.agent.md', offset } } });
        events.push({ type: 'tool_result', data: { toolName: 'read_file', toolCallId: callId, success: true, result: control.referenceText.slice(offset, offset + 350) } });
      }
    }
    events.push({ type: 'assistant_message', data: { content: control.output } });
    const trajectory = {
      id: control.id, stimulus: { name: control.stimulusName, prompt: control.stimulus.prompt },
      metadata: { executor: 'synthetic-calibration', model: 'synthetic', skillsLoaded: [] },
      events,
      metrics: { wallTimeMs: 0 }, output: control.output, workDir
    };
    const child = runChild(process.execPath, [prepared.cli, 'grade', '--eval-spec', control.specPath, '--judge-model', prepared.judge, '--output', 'jsonl'], {
      cwd: root, input: JSON.stringify({ status: 'success', trajectory, gradeResult: null }),
      encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024
    });
    writeFileSync(path.join(workDir, 'stdout.jsonl'), child.stdout || '', { mode: 0o600 });
    writeFileSync(path.join(workDir, 'stderr.txt'), child.stderr || '', { mode: 0o600 });
    results.push(projectCalibrationGrade(control, child.stdout || '', child.status));
  }
  const safe = {
    schemaVersion: '1.0.0', profileDigest: prepared.acceptance.inventory.profileDigest,
    checkout: prepared.acceptance.checkout, inputDigest: prepared.acceptance.inputDigest,
    judgeModel: prepared.judge, vallyVersion: prepared.version, controls: results
  };
  writeFileSync(output, `${JSON.stringify(safe, null, 2)}\n`, { flag: 'wx' });
  const passed = results.every((result, index) => result.status === 'success' && result.passed === prepared.controls[index].expectedPass);
  return { passed, count: results.length };
}

function main() {
  const { values } = parseArgs({ options: { profile: { type: 'string' }, manifest: { type: 'string' }, output: { type: 'string' }, check: { type: 'boolean', default: false } } });
  if (!values.profile || !values.manifest) throw new Error('Profile and manifest are required.');
  const prepared = prepareCalibration(values.profile, values.manifest);
  if (values.check) {
    console.log(`Calibration configuration valid: ${prepared.controls.length} controls; no model calls.`);
    return;
  }
  if (!values.output) throw new Error('Output is required for calibration execution.');
  const { passed, count } = executeCalibration(prepared, values.output);
  console.log(`Calibration controls: ${count}; expected verdicts matched: ${passed}.`);
  if (!passed) process.exitCode = 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); } catch { console.error('Calibration failed closed; no raw evidence is published.'); process.exitCode = 2; }
}