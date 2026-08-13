// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { createHash, randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

import { createCalibrationCheckpoint, validateCalibrationCheckpoint } from './calibration-checkpoint.mjs';
import { processAtPlanCase } from './at-plan-executor.mjs';
import { launchChrome } from './_shared.mjs';
import { resolveRouteUrl } from './route.mjs';
import { captureVisualReviewEvidence } from './visual-review-executor.mjs';

function stripNonAuthoritativePersistedArtifactHashes(value, seen = new WeakMap()) {
  if (value === null || value === undefined) {
    return value;
  }
  if (typeof value !== 'object') {
    return value;
  }
  if (seen.has(value)) {
    return '[Circular]';
  }
  seen.set(value, true);
  if (Array.isArray(value)) {
    const mapped = value.map((entry) => stripNonAuthoritativePersistedArtifactHashes(entry, seen));
    seen.delete(value);
    return mapped;
  }
  const entries = Object.entries(value)
    .filter(([key]) => key !== 'persistedArtifactHash')
    .map(([key, entryValue]) => [key, stripNonAuthoritativePersistedArtifactHashes(entryValue, seen)]);
  seen.delete(value);
  return Object.fromEntries(entries);
}

function buildPersistedEvidencePayload(payload) {
  return stripNonAuthoritativePersistedArtifactHashes(payload);
}

function resolveExistingPersistedArtifact(payload, runRoot = null) {
  const candidateReferences = [];
  const pushReference = (value) => {
    if (typeof value === 'string' && value.trim().length > 0) {
      candidateReferences.push(value.trim());
    }
  };

  pushReference(payload?.evidence?.persistedArtifact);
  pushReference(payload?.persistedArtifact);
  if (Array.isArray(payload?.artifactReferences)) {
    for (const reference of payload.artifactReferences) {
      pushReference(reference);
    }
  }
  if (payload?.artifactHashes && typeof payload.artifactHashes === 'object') {
    for (const reference of Object.keys(payload.artifactHashes)) {
      pushReference(reference);
    }
  }

  const uniqueReferences = [...new Set(candidateReferences)];
  for (const artifactReference of uniqueReferences) {
    const resolvedPath = resolveArtifactPath(artifactReference, runRoot);
    if (resolvedPath && existsSync(resolvedPath)) {
      return {
        artifactReference,
        artifactPath: resolvedPath,
        artifactHash: createHash('sha256').update(readFileSync(resolvedPath)).digest('hex'),
      };
    }
  }
  return null;
}

function isWithinRoot(rootPath, candidatePath) {
  const normalizedRoot = path.resolve(rootPath);
  const normalizedCandidate = path.resolve(candidatePath);
  const relativePath = path.relative(normalizedRoot, normalizedCandidate);
  return Boolean(relativePath && relativePath !== '.' && !relativePath.startsWith('..') && !path.isAbsolute(relativePath));
}

export function resolveContainedArtifactPath(artifactReference, runRoot = null) {
  if (typeof artifactReference !== 'string' || artifactReference.trim().length === 0) {
    return null;
  }
  const normalized = artifactReference.trim();
  if (/^(?:[a-z][a-z\d+.-]*):/i.test(normalized) || normalized.startsWith('//')) {
    return null;
  }
  const baseRoot = runRoot ? path.resolve(runRoot) : process.cwd();
  if (path.isAbsolute(normalized)) {
    return null;
  }
  const resolvedPath = path.resolve(baseRoot, normalized);
  const relativePath = path.relative(baseRoot, resolvedPath);
  if (!relativePath || relativePath === '.' || relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
    return null;
  }
  if (existsSync(resolvedPath)) {
    try {
      const realPath = realpathSync(resolvedPath);
      if (!isWithinRoot(baseRoot, realPath)) {
        return null;
      }
    } catch {
      return null;
    }
  } else {
    const parentPath = path.dirname(resolvedPath);
    if (existsSync(parentPath)) {
      try {
        const realParentPath = realpathSync(parentPath);
        if (!isWithinRoot(baseRoot, realParentPath)) {
          return null;
        }
      } catch {
        return null;
      }
    }
  }
  return resolvedPath;
}

export function resolveArtifactPath(artifactReference, runRoot = null) {
  return resolveContainedArtifactPath(artifactReference, runRoot);
}

function persistJsonArtifact(targetPath, payload) {
  const resolvedTargetPath = path.resolve(targetPath);
  mkdirSync(path.dirname(resolvedTargetPath), { recursive: true });
  const serialized = `${JSON.stringify(payload, null, 2)}\n`;
  // Unpredictable temp name so a co-located process cannot pre-create or
  // pre-empt the path, and rename directly over the target so there is never a
  // window in which the artifact is absent.
  const tempPath = `${resolvedTargetPath}.tmp-${randomBytes(16).toString('hex')}`;
  try {
    writeFileSync(tempPath, serialized, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
    renameSync(tempPath, resolvedTargetPath);
  } catch (error) {
    if (existsSync(tempPath)) {
      unlinkSync(tempPath);
    }
    throw error;
  }
  const artifactHash = createHash('sha256').update(serialized).digest('hex');
  return { artifactPath: resolvedTargetPath, artifactHash };
}

function persistSampleEvidence({ runRoot = null, journeyId, ordinal, payload }) {
  const resolvedRunRoot = runRoot ? path.resolve(runRoot) : process.cwd();
  const evidencePath = path.join(resolvedRunRoot, 'journeys', String(journeyId), String(ordinal), 'evidence.json');
  const persisted = persistJsonArtifact(evidencePath, payload);
  const artifactReference = path.relative(resolvedRunRoot, persisted.artifactPath).replace(/\\/g, '/');
  return {
    ...persisted,
    artifactReference,
  };
}

function materializeArtifactEvidence(artifactHashes, runRoot = null) {
  if (!artifactHashes || typeof artifactHashes !== 'object') {
    return { artifactHashes: {}, valid: false };
  }
  const entries = Object.entries(artifactHashes)
    .filter(([artifactReference, artifactHash]) => typeof artifactReference === 'string' && artifactReference.trim().length > 0 && typeof artifactHash === 'string' && artifactHash.trim().length > 0);
  if (entries.length === 0) {
    return { artifactHashes: {}, valid: false };
  }

  const materialized = {};
  for (const [artifactReference] of entries) {
    const resolvedPath = resolveArtifactPath(artifactReference, runRoot);
    if (!resolvedPath || !existsSync(resolvedPath)) {
      continue;
    }
    const actualHash = createHash('sha256').update(readFileSync(resolvedPath)).digest('hex');
    materialized[artifactReference] = actualHash;
  }

  return {
    artifactHashes: materialized,
    valid: Object.keys(materialized).length > 0,
  };
}

// True when at least one recorded artifact still hashes to its recorded digest.
//
// Evidence is only worth trusting if the bytes on disk are the bytes that were
// measured, so a recorded hash that no longer matches counts as no evidence
// rather than as a passing artifact.
function hasMatchingArtifactHashes(artifactHashes, runRoot = null) {
  if (!artifactHashes || typeof artifactHashes !== 'object') {
    return false;
  }
  const entries = Object.entries(artifactHashes).filter(([artifactReference, artifactHash]) => typeof artifactReference === 'string' && artifactReference.trim().length > 0 && typeof artifactHash === 'string' && artifactHash.trim().length > 0);
  if (entries.length === 0) {
    return false;
  }
  let matchedArtifacts = 0;
  for (const [artifactReference, expectedHash] of entries) {
    const resolvedPath = resolveArtifactPath(artifactReference, runRoot);
    if (!resolvedPath || !existsSync(resolvedPath)) {
      continue;
    }
    const actualHash = createHash('sha256').update(readFileSync(resolvedPath)).digest('hex');
    if (actualHash === expectedHash) {
      matchedArtifacts += 1;
    }
  }
  return matchedArtifacts > 0;
}

function normalizeAssertionEntries(result = {}) {
  const entries = [];
  if (Array.isArray(result?.assertions)) {
    entries.push(...result.assertions);
  }
  if (Array.isArray(result?.evidence?.assertions)) {
    entries.push(...result.evidence.assertions);
  }
  return entries;
}

function normalizeRequiredAssertions(result = {}) {
  if (Array.isArray(result?.requiredAssertions) && result.requiredAssertions.length > 0) {
    return result.requiredAssertions;
  }
  if (Array.isArray(result?.journeyAssertions) && result.journeyAssertions.length > 0) {
    return result.journeyAssertions;
  }
  return [];
}

function hasMeaningfulPhraseEvidence(evidence = {}) {
  const rawPhrases = Array.isArray(evidence?.rawPhrases) ? evidence.rawPhrases : [];
  const normalizedPhrases = Array.isArray(evidence?.normalizedPhrases) ? evidence.normalizedPhrases : [];
  return rawPhrases.some((entry) => typeof entry === 'string' && entry.trim().length > 0)
    && normalizedPhrases.some((entry) => typeof entry === 'string' && entry.trim().length > 0);
}

function isRealAtDriver(result = {}, evidence = {}) {
  const driverName = String(result?.driver || evidence?.provenance?.driver || '').toLowerCase();
  const atName = String(result?.at || result?.capability?.at || evidence?.provenance?.at || '').toLowerCase();
  return /guidepup/i.test(driverName) && atName === 'nvda';
}

export function classifyAtCaseResult(result = {}, runRoot = null) {
  const evidence = result?.evidence || {};
  const status = String(result?.status || result?.outcome?.status || '').toLowerCase();
  const explicitClassification = String(result?.classification || '').toLowerCase();
  const synthetic = Boolean(evidence?.synthetic || result?.capability?.synthetic);
  const explicitReason = String(evidence?.reason || result?.reason || '').toLowerCase();
  const assertionEntries = normalizeAssertionEntries(result);
  const requiredAssertions = normalizeRequiredAssertions(result);

  const assertionFailure = assertionEntries.some((entry) => String(entry?.status || '').toLowerCase() === 'fail');
  const invalidAssertion = assertionEntries.some((entry) => {
    const normalizedStatus = String(entry?.status || '').toLowerCase();
    return normalizedStatus !== '' && normalizedStatus !== 'pass' && normalizedStatus !== 'fail';
  });
  const requiredAssertionFailure = requiredAssertions.some((requiredAssertion) => {
    const requiredId = String(requiredAssertion?.id || requiredAssertion?.value || '').trim();
    if (!requiredId) {
      return true;
    }
    const matchingEntry = assertionEntries.find((entry) => String(entry?.id || '').trim() === requiredId);
    return !matchingEntry || String(matchingEntry.status || '').toLowerCase() !== 'pass';
  });

  const hasNonEmptyPhrases = hasMeaningfulPhraseEvidence(evidence);
  const hasPersistedArtifacts = hasMatchingArtifactHashes(result?.artifactHashes, runRoot);
  const capabilitySupported = result?.capability?.supported !== false;
  const isRealDriver = isRealAtDriver(result, evidence);
  const isStrictPass = status === 'pass' && isRealDriver && capabilitySupported && !synthetic && !Boolean(evidence?.synthetic) && hasNonEmptyPhrases && hasPersistedArtifacts && !requiredAssertionFailure && !assertionFailure && !invalidAssertion;

  if (['candidate', 'unsupported', 'unavailable'].includes(status) || ['candidate', 'unsupported', 'unavailable'].includes(explicitClassification)) {
    return 'unavailable';
  }
  if (synthetic || Boolean(evidence?.synthetic) || !capabilitySupported) {
    return 'unavailable';
  }
  if (explicitClassification === 'assertionfailure' || explicitClassification === 'assertion-failure' || assertionFailure || invalidAssertion || requiredAssertionFailure) {
    return 'assertionFailure';
  }
  if (explicitClassification === 'productfailure' || explicitClassification === 'product-failure' || explicitClassification === 'deterministicfailure' || /product|deterministic/.test(explicitReason)) {
    return 'productFailure';
  }
  if (explicitClassification === 'transcriptdrift' || explicitClassification === 'baseline-mismatch' || /baseline|drift|mismatch/.test(explicitReason)) {
    return 'transcriptDrift';
  }
  if (explicitClassification === 'infrastructurefailure' || explicitClassification === 'infrastructure-failure' || /browser|navigation|focus|lifecycle|driver|adapter|chrome|guidepup|launch|page|error/.test(explicitReason) || Boolean(evidence?.error)) {
    return 'infrastructureFailure';
  }
  if (status === 'error' || status === 'fail') {
    return 'infrastructureFailure';
  }
  if (!isRealDriver) {
    return 'infrastructureFailure';
  }
  if (!hasNonEmptyPhrases) {
    return 'infrastructureFailure';
  }
  if (!hasPersistedArtifacts) {
    return 'infrastructureFailure';
  }
  return isStrictPass ? 'pass' : 'infrastructureFailure';
}

function buildProfileFingerprint(config, journey = {}) {
  const explicit = journey?.profileFingerprint || config?.profileFingerprint || config?.approvedProfile || {};
  return {
    locale: 'en-US',
    verbosity: 'default',
    punctuation: 'preserve',
    speechMode: 'default',
    addOnPosture: 'default',
    ...explicit,
  };
}

function normalizeJourney(config, journey, index) {
  const journeyId = String(journey?.journeyId || journey?.id || `journey-${index + 1}`);
  return {
    journeyId,
    title: journey?.title || `Calibration journey ${journeyId}`,
    route: journey?.route || '/',
    surfaceId: journey?.surfaceId || null,
    state: journey?.state || 'desktop',
    trigger: journey?.trigger || { action: 'focus', target: '#search' },
    triggerSequence: Array.isArray(journey?.triggerSequence) && journey.triggerSequence.length > 0
      ? journey.triggerSequence
      : undefined,
    triggerAfterDriverStart: Boolean(journey?.triggerAfterDriverStart),
    postCommandSettleMs: journey?.postCommandSettleMs,
    captureMode: journey?.captureMode,
    commands: Array.isArray(journey?.commands) && journey.commands.length > 0
      ? journey.commands
      : [{ kind: 'keyboard', value: 'Tab' }],
    assertions: Array.isArray(journey?.assertions) && journey.assertions.length > 0
      ? journey.assertions
      : [{ id: 'speech', type: 'contains', value: 'search' }],
    profileFingerprint: buildProfileFingerprint(config, journey),
    metadata: journey?.metadata || {},
    visualStates: Array.isArray(journey?.visualStates) && journey.visualStates.length > 0
      ? journey.visualStates
      : (Array.isArray(config?.calibration?.visualStates) ? config.calibration.visualStates : ['desktop']),
  };
}

// Journeys are defined entirely by the runtime config. There is no built-in
// default set: a harness that invents journeys the operator did not configure
// would report evidence about surfaces nobody asked it to exercise.
export function resolveCalibrationCases(config = {}) {
  const journeys = Array.isArray(config?.calibration?.journeys)
    ? config.calibration.journeys
    : [];
  return journeys.map((journey, index) => normalizeJourney(config, journey, index));
}

export async function defaultRunAtCase({
  journey,
  config,
  runRoot = null,
  ordinal = 0,
  browser = null,
  context = null,
  page = null,
  processAtPlanCaseImpl = processAtPlanCase,
}) {
  const profileFingerprint = journey?.profileFingerprint || buildProfileFingerprint(config, journey);
  const targetUrl = resolveRouteUrl(
    journey?.route || '/',
    config?.baseUrl || 'http://127.0.0.1:3000',
  );
  const surface = {
    id: journey?.surfaceId || journey?.surface?.id || journey?.journeyId || 'surface',
    route: journey?.route || '/',
    selector: journey?.selector || journey?.surface?.selector || null,
    trigger: journey?.trigger || null,
  };
  const matrixCase = {
    caseId: journey?.journeyId,
    mappingId: journey?.journeyId,
    state: journey?.state || 'desktop',
    surface: surface.id,
    targetUrl,
    trigger: journey?.trigger || null,
    triggerSequence: Array.isArray(journey?.triggerSequence) && journey.triggerSequence.length > 0
      ? journey.triggerSequence
      : undefined,
    triggerAfterDriverStart: Boolean(journey?.triggerAfterDriverStart),
    postCommandSettleMs: journey?.postCommandSettleMs,
    captureMode: journey?.captureMode,
    commands: journey?.commands || [],
    assertions: journey?.assertions || [],
    runtimeConfig: {
      ...(config || {}),
      approvedProfile: profileFingerprint,
      triggerAfterDriverStart: Boolean(journey?.triggerAfterDriverStart),
      triggerSequence: Array.isArray(journey?.triggerSequence) && journey.triggerSequence.length > 0
        ? journey.triggerSequence
        : undefined,
    },
    sourceMatrixMetadata: {
      journeyId: journey?.journeyId,
      title: journey?.title,
    },
    at: 'nvda',
    variant: {
      id: journey?.journeyId,
      at: 'nvda',
      commands: journey?.commands || [],
      assertions: journey?.assertions || [],
      automationEligible: true,
    },
  };

  const result = await processAtPlanCaseImpl({
    matrixCase,
    runtimeConfig: matrixCase.runtimeConfig,
    driverName: 'guidepup',
    platform: process.platform,
    browser,
    context,
    page,
    surface,
    state: journey?.state || 'desktop',
  });

  const persistedPayload = buildPersistedEvidencePayload({
    journeyId: journey?.journeyId,
    ordinal,
    surface,
    profileFingerprint,
    result,
    outcome: {
      status: result?.status || 'error',
      expected: (journey?.assertions || []).map((assertion) => assertion?.value || assertion?.id || '').filter(Boolean).join(' | ') || 'Expected AT output to match the calibrated profile.',
      actual: result?.status === 'pass' ? 'Observed AT output matched the calibrated profile.' : (result?.evidence?.error || 'Calibration execution did not complete successfully.'),
      reproduction: `Reproduce the ${journey?.title || journey?.journeyId} calibration journey using the pinned NVDA profile.`,
    },
  });
  const persisted = persistSampleEvidence({
    runRoot,
    journeyId: journey?.journeyId,
    ordinal,
    payload: persistedPayload,
  });

  const evidence = {
    ...(result?.evidence || {}),
    persistedArtifact: persisted.artifactReference,
  };
  const capability = {
    ...(result?.capability || {}),
    supported: result?.capability?.supported ?? true,
    synthetic: result?.capability?.synthetic ?? false,
    at: result?.capability?.at || 'nvda',
  };
  const provenance = {
    ...(result?.provenance || {}),
    ...(result?.evidence?.provenance || {}),
    driver: result?.driver || result?.provenance?.driver || result?.evidence?.provenance?.driver || 'guidepup',
    at: result?.at || result?.capability?.at || result?.provenance?.at || result?.evidence?.provenance?.at || 'nvda',
  };
  const classification = classifyAtCaseResult({
    ...result,
    driver: provenance.driver,
    at: provenance.at,
    capability,
    classification: result?.classification || null,
    requiredAssertions: (journey?.assertions || []).map((assertion) => ({ id: assertion?.id || assertion?.value || null, value: assertion?.value || null })),
    artifactHashes: { [persisted.artifactReference]: persisted.artifactHash },
    evidence: {
      ...evidence,
      provenance,
    },
    provenance,
    outcome: {
      status: result?.status || 'error',
      expected: (journey?.assertions || []).map((assertion) => assertion?.value || assertion?.id || '').filter(Boolean).join(' | ') || 'Expected AT output to match the calibrated profile.',
      actual: result?.status === 'pass' ? 'Observed AT output matched the calibrated profile.' : (result?.evidence?.error || 'Calibration execution did not complete successfully.'),
      reproduction: `Reproduce the ${journey?.title || journey?.journeyId} calibration journey using the pinned NVDA profile.`,
    },
  }, runRoot);

  return {
    journeyId: journey?.journeyId,
    classification,
    profileFingerprint,
    provenance: evidence?.provenance || {
      driver: 'guidepup',
      profileFingerprint,
    },
    artifactHashes: { [persisted.artifactReference]: persisted.artifactHash },
    outcome: {
      status: classification === 'pass' ? 'pass' : (result?.status || 'error'),
      actual: classification === 'pass' ? 'Observed AT output matched the calibrated profile.' : (result?.evidence?.error || 'Calibration execution did not complete successfully.'),
      expected: (journey?.assertions || []).map((assertion) => assertion?.value || assertion?.id || '').filter(Boolean).join(' | ') || 'Expected AT output to match the calibrated profile.',
      reproduction: `Reproduce the ${journey?.title || journey?.journeyId} calibration journey using the pinned NVDA profile.`,
    },
    evidence,
    artifactReferences: [persisted.artifactReference],
  };
}

function normalizeBooleanLike(value) {
  if (value === true) {
    return true;
  }
  if (value === false) {
    return false;
  }
  if (value === undefined || value === null) {
    return null;
  }
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'off', ''].includes(normalized)) {
    return false;
  }
  return null;
}

function normalizeVersionOutput(output) {
  return String(output || '')
    .split(/\r?\n/)
    .map((entry) => entry.trim())
    .find(Boolean) || null;
}

// path.basename follows the host OS separator rules, so a Windows path handed
// to a Linux process keeps its backslashes and returns unchanged. The probe
// resolves paths for a caller-supplied platform, which may differ from the host,
// so split on both separators.
function executableName(candidate) {
  const segments = String(candidate || '').split(/[\\/]/);
  return segments[segments.length - 1] || String(candidate || '');
}

function normalizeChromeVersion(output) {
  const trimmed = normalizeVersionOutput(output);
  if (!trimmed) {
    return null;
  }
  const versionMatch = trimmed.match(/(\d+(?:\.\d+){1,3})/);
  return versionMatch ? versionMatch[1] : null;
}

function probePlaywrightChromeVersion({ env = {}, platform = 'linux', spawn }) {
  if (platform !== 'win32') {
    return null;
  }
  const script = "import('playwright').then(({ chromium }) => { const value = chromium.executablePath(); if (value) console.log(value); }).catch(() => process.exit(1));";
  const probe = spawn(process.execPath, ['-e', script], { encoding: 'utf8' });
  const resolvedPath = normalizeVersionOutput(probe.stdout || probe.stderr || '');
  if (!resolvedPath) {
    return null;
  }
  // Read the version from file metadata rather than executing the browser
  // binary; on Windows a `--version` invocation opens a browser window.
  return probeChromeVersionFromFileMetadata({ executable: resolvedPath, platform, spawn });
}

function probeChromeVersionFromFileMetadata({ executable, platform = 'linux', spawn }) {
  if (platform !== 'win32' || !executable) {
    return null;
  }
  const powershellScript = `[System.Diagnostics.FileVersionInfo]::GetVersionInfo('${String(executable).replace(/'/g, "''")}').ProductVersion`;
  const probe = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', powershellScript], { encoding: 'utf8' });
  return normalizeChromeVersion(`${probe.stdout || ''}${probe.stderr || ''}`);
}

function probeChromeVersion({ executable, env = {}, platform = 'linux', spawn }) {
  if (!executable) {
    return null;
  }
  // On Windows, `chrome.exe --version` does not print a version and exit. It
  // launches a browser window against the user's default profile, which steals
  // OS foreground focus from the automation window and survives Playwright
  // teardown because Playwright never owned the process. Read the version from
  // file metadata instead and never execute the browser binary here.
  if (platform === 'win32') {
    return probeChromeVersionFromFileMetadata({ executable, platform, spawn });
  }
  const probe = spawn(executable, ['--version'], { encoding: 'utf8' });
  return normalizeChromeVersion(`${probe.stdout || ''}${probe.stderr || ''}`);
}

export function resolveChromeExecutable({ env = {}, platform = 'linux', spawn }) {
  const candidates = [];
  const explicitCandidates = [
    env.RUNTIME_A11Y_CHROME_PATH,
    env.CHROME_BIN,
    env.PLAYWRIGHT_CHROME_EXECUTABLE_PATH,
    env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
  ].filter((entry) => typeof entry === 'string' && entry.trim().length > 0);
  candidates.push(...explicitCandidates);

  if (platform === 'win32') {
    const localAppData = env.LOCALAPPDATA ? path.join(env.LOCALAPPDATA, 'Google', 'Chrome', 'Application', 'chrome.exe') : null;
    const programFiles = [env.ProgramFiles, env.PROGRAMFILES, env['ProgramFiles'], env['PROGRAMFILES'], 'C:\\Program Files'].find((entry) => typeof entry === 'string' && entry.trim().length > 0);
    const programFilesX86 = [env['ProgramFiles(x86)'], env['PROGRAMFILES(X86)'], 'C:\\Program Files (x86)'].find((entry) => typeof entry === 'string' && entry.trim().length > 0);
    candidates.push(
      localAppData,
      programFiles ? path.join(programFiles, 'Google', 'Chrome', 'Application', 'chrome.exe') : null,
      programFilesX86 ? path.join(programFilesX86, 'Google', 'Chrome', 'Application', 'chrome.exe') : null,
      'chrome.exe',
    );
  } else {
    candidates.push('google-chrome', 'chromium');
  }

  const uniqueCandidates = [];
  const seenCandidates = new Set();
  for (const candidate of candidates) {
    if (!candidate) {
      continue;
    }
    const key = String(candidate);
    if (seenCandidates.has(key)) {
      continue;
    }
    seenCandidates.add(key);
    uniqueCandidates.push(key);
  }

  for (const candidate of uniqueCandidates) {
    const trimmed = String(candidate).trim();
    if (!trimmed) {
      continue;
    }

    const isAbsolutePath = path.isAbsolute(trimmed) || /^[a-z]:[\\/]/i.test(trimmed) || trimmed.includes('/') || trimmed.includes('\\');
    if (isAbsolutePath) {
      if (!existsSync(trimmed)) {
        continue;
      }
      const version = probeChromeVersion({ executable: trimmed, env, platform, spawn });
      if (version) {
        return {
          executable: executableName(trimmed),
          version,
        };
      }
      continue;
    }

    if (platform === 'win32') {
      const playrightVersion = probePlaywrightChromeVersion({ env, platform, spawn });
      if (playrightVersion) {
        return {
          executable: 'chrome.exe',
          version: playrightVersion,
        };
      }
    }

    const lookup = spawn(platform === 'win32' ? 'where.exe' : 'which', [trimmed], { encoding: 'utf8' });
    const resolvedPath = normalizeVersionOutput(lookup.stdout || lookup.stderr || '');
    if (!resolvedPath) {
      continue;
    }

    const version = probeChromeVersion({ executable: resolvedPath, env, platform, spawn });
    if (version) {
      return {
        executable: executableName(resolvedPath),
        version,
      };
    }
  }

  if (platform === 'win32') {
    const playrightVersion = probePlaywrightChromeVersion({ env, platform, spawn });
    if (playrightVersion) {
      return {
        executable: 'chrome.exe',
        version: playrightVersion,
      };
    }
  }

  return {
    executable: null,
    version: null,
  };
}

function detectInteractiveDesktop({ env = {}, platform = 'linux', spawn }) {
  const explicitValue = normalizeBooleanLike(env.RUNTIME_A11Y_INTERACTIVE_DESKTOP);
  if (explicitValue !== null) {
    return { ok: explicitValue, source: 'runtime-env' };
  }

  const sessionName = String(env.SESSIONNAME || '').trim();
  const sessionSignals = [env.WT_SESSION, env.TERMINAL_SESSION_ID, env.XDG_SESSION_ID].filter((entry) => typeof entry === 'string' && entry.trim().length > 0);
  if (platform === 'win32') {
    if (sessionName && sessionName.toLowerCase() !== 'services') {
      return { ok: true, source: 'session-name' };
    }
    if (sessionSignals.length > 0) {
      return { ok: true, source: 'session-signals' };
    }
    for (const command of ['powershell.exe', 'pwsh']) {
      const probe = spawn(command, ['-NoProfile', '-NonInteractive', '-Command', '[Environment]::UserInteractive'], { encoding: 'utf8' });
      const output = normalizeVersionOutput(`${probe.stdout || ''}${probe.stderr || ''}`);
      if (!output) {
        continue;
      }
      const normalized = output.toLowerCase();
      if (normalized.includes('true')) {
        return { ok: true, source: 'user-interactive' };
      }
      if (normalized.includes('false')) {
        return { ok: false, source: 'user-interactive' };
      }
    }
    return { ok: false, source: 'unverified' };
  }

  for (const command of ['powershell.exe', 'pwsh']) {
    const probe = spawn(command, ['-NoProfile', '-NonInteractive', '-Command', '[Environment]::UserInteractive'], { encoding: 'utf8' });
    const output = normalizeVersionOutput(`${probe.stdout || ''}${probe.stderr || ''}`);
    if (!output) {
      continue;
    }
    const normalized = output.toLowerCase();
    if (normalized.includes('true')) {
      return { ok: true, source: 'user-interactive' };
    }
    if (normalized.includes('false')) {
      return { ok: false, source: 'user-interactive' };
    }
  }

  return { ok: platform !== 'win32', source: 'unverified' };
}

function normalizeGuidepupVersion(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) {
    return null;
  }
  const match = trimmed.match(/guidepup_nvda_?([^\s]+)|(?:^|[^\d])(\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?)(?:[^\d]|$)/);
  return match ? (match[1] || match[2] || null) : null;
}

function resolveGuidepupRegistryVersion({ platform = 'linux', spawn }) {
  if (platform !== 'win32') {
    return null;
  }
  const regExe = ['C:\\Windows\\System32\\reg.exe', 'reg.exe'].find((entry) => Boolean(entry));
  if (!regExe) {
    return null;
  }
  const registryProbe = spawn(regExe, ['query', 'HKCU\\Software\\Guidepup\\Nvda', '/s'], { encoding: 'utf8' });
  const output = `${registryProbe.stdout || ''}${registryProbe.stderr || ''}`;
  if (!output) {
    return null;
  }
  const version = normalizeGuidepupVersion(output);
  return version;
}

async function resolveGuidepupInstallationPath(moduleApi) {
  if (!moduleApi || typeof moduleApi !== 'object') {
    return null;
  }
  const candidates = [
    moduleApi.getNVDAInstallationPath,
    moduleApi.default?.getNVDAInstallationPath,
    moduleApi.nvda?.getNVDAInstallationPath,
    moduleApi.isNVDAInstalled,
    moduleApi.default?.isNVDAInstalled,
    moduleApi.nvda?.isNVDAInstalled,
  ].filter((entry) => typeof entry === 'function');

  for (const candidate of candidates) {
    try {
      const payload = await candidate();
      if (typeof payload === 'string' && payload.trim().length > 0) {
        return payload.trim();
      }
      if (typeof payload === 'boolean') {
        return payload ? '' : null;
      }
    } catch {
      // Ignore probe failures and fall back to registry-based detection.
    }
  }
  return null;
}

export async function detectGuidepupNvda({ platform = 'linux', spawn, importGuidepup }) {
  let guidepupRegistered = false;
  let guidepupCapabilities = [];
  let conflictingNvdaProcess = false;
  let guidepupVersion = null;
  try {
    const importedModule = typeof importGuidepup === 'function' ? await importGuidepup() : null;
    const moduleCandidates = [importedModule, importedModule?.default, importedModule?.nvda, importedModule?.default?.nvda].filter(Boolean);
    const moduleTarget = moduleCandidates.find((entry) => entry && typeof entry === 'object' && typeof entry.start === 'function' && typeof entry.stop === 'function') || null;
    let runtimeTarget = moduleTarget;
    const capabilities = [];
    if (importedModule) {
      for (const entry of [importedModule, importedModule?.default]) {
        if (!entry) {
          continue;
        }
        if (Array.isArray(entry.capabilities)) {
          capabilities.push(...entry.capabilities);
        }
        if (Array.isArray(entry.defaultCapabilities)) {
          capabilities.push(...entry.defaultCapabilities);
        }
      }
    } else if (typeof importGuidepup !== 'function') {
      const fallbackModule = await import('@guidepup/guidepup').catch(() => null);
      const fallbackCandidates = [fallbackModule, fallbackModule?.default, fallbackModule?.nvda, fallbackModule?.default?.nvda].filter(Boolean);
      const fallbackTarget = fallbackCandidates.find((entry) => entry && typeof entry === 'object' && typeof entry.start === 'function' && typeof entry.stop === 'function') || null;
      if (fallbackTarget) {
        runtimeTarget = fallbackTarget;
      }
      for (const entry of [fallbackModule, fallbackModule?.default]) {
        if (!entry) {
          continue;
        }
        if (Array.isArray(entry.capabilities)) {
          capabilities.push(...entry.capabilities);
        }
        if (Array.isArray(entry.defaultCapabilities)) {
          capabilities.push(...entry.defaultCapabilities);
        }
      }
    }
    guidepupCapabilities = capabilities.map((entry) => String(entry)).filter(Boolean);
    const capabilityMatch = guidepupCapabilities.some((entry) => String(entry).toLowerCase().includes('nvda'));
    guidepupRegistered = Boolean(runtimeTarget || capabilityMatch);
    const moduleApi = moduleCandidates.find((entry) => entry && typeof entry === 'object') || null;
    const installationPath = await resolveGuidepupInstallationPath(moduleApi);
    if (installationPath) {
      const candidatePath = installationPath.endsWith('.exe') ? installationPath : path.join(installationPath, 'nvda.exe');
      if (existsSync(candidatePath)) {
        guidepupRegistered = true;
      }
    }
    const versionValue = moduleApi?.version || moduleApi?.default?.version || moduleApi?.nvda?.version || moduleApi?.guidepupVersion || null;
    guidepupVersion = normalizeGuidepupVersion(versionValue);
  } catch {
    guidepupRegistered = false;
    guidepupCapabilities = [];
    guidepupVersion = null;
  }

  if (platform === 'win32') {
    const taskList = spawn('tasklist', ['/FI', 'IMAGENAME eq nvda.exe', '/FO', 'CSV', '/NH'], { encoding: 'utf8' });
    const output = `${taskList.stdout || ''}${taskList.stderr || ''}`;
    conflictingNvdaProcess = output.toLowerCase().includes('nvda.exe');
  }

  if (platform === 'win32' && (!guidepupRegistered || !guidepupVersion)) {
    const registryVersion = resolveGuidepupRegistryVersion({ platform, spawn });
    if (registryVersion) {
      guidepupVersion = registryVersion;
      guidepupRegistered = true;
    }
  }

  return {
    guidepupRegistered,
    guidepupCapabilities,
    conflictingNvdaProcess,
    guidepupVersion,
  };
}

export async function probePrerequisites(config = {}, runtime = null) {
  const executionRuntime = runtime || {
    platform: process.platform,
    env: process.env,
    spawnSync,
  };
  const platform = String(executionRuntime?.platform || process.platform || 'linux').toLowerCase();
  const env = executionRuntime?.env || process.env || {};
  const spawn = executionRuntime?.spawnSync || spawnSync;
  const desktop = detectInteractiveDesktop({ env, platform, spawn });
  const chrome = resolveChromeExecutable({ env, platform, spawn });
  const nvda = await detectGuidepupNvda({ platform, spawn, importGuidepup: executionRuntime?.dependencies?.importGuidepup });
  const reasons = [];
  if (!desktop.ok) {
    reasons.push('Interactive desktop was not available.');
  }
  if (!chrome.executable || !chrome.version) {
    reasons.push('Chrome executable/version was not verified.');
  }
  if (!nvda.guidepupRegistered) {
    reasons.push('NVDA registration for isolated Guidepup execution was not verified.');
  }
  if (nvda.conflictingNvdaProcess) {
    reasons.push('A conflicting normal NVDA process was detected.');
  }

  const ok = Boolean(desktop.ok && chrome.executable && chrome.version && nvda.guidepupRegistered && !nvda.conflictingNvdaProcess);
  return {
    ok,
    desktopUnlocked: desktop.ok,
    nvdaAvailable: Boolean(nvda.guidepupRegistered && !nvda.conflictingNvdaProcess),
    chromeExecutable: chrome.executable,
    chromeVersion: chrome.version,
    guidepupRegistered: nvda.guidepupRegistered,
    guidepupVersion: nvda.guidepupVersion,
    nvdaProcessActive: nvda.conflictingNvdaProcess,
    reasons,
    reason: reasons.length > 0 ? reasons.join(' ') : null,
    metadata: {
      platform,
      chromeExecutable: chrome.executable,
      chromeVersion: chrome.version,
      guidepupCapabilities: nvda.guidepupCapabilities,
      guidepupVersion: nvda.guidepupVersion,
      nvdaProcessActive: nvda.conflictingNvdaProcess,
      interactiveDesktopSignal: desktop.source,
    },
  };
}

export async function runDefaultVisualPreflight({ config = {}, runRoot = null, captureVisualReviewEvidenceImpl = captureVisualReviewEvidence } = {}) {
  const resolvedRunRoot = runRoot ? path.resolve(runRoot) : process.cwd();
  const reviewConfig = {
    ...(config || {}),
    baseUrl: config?.baseUrl || process.env.RUNTIME_A11Y_BASE_URL || 'http://127.0.0.1:3000',
    visualReview: {
      routes: [
        { path: '/', surfaceId: 'home' },
        { path: '/search', surfaceId: 'search' },
      ],
      states: ['desktop', 'reflow-320', 'zoom-200', 'text-spacing', 'forced-colors'],
      ...(config?.visualReview || {}),
    },
  };
  const previousRunRoot = process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
  const previousBaseUrl = process.env.RUNTIME_A11Y_BASE_URL;
  process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = resolvedRunRoot;
  if (reviewConfig.baseUrl) {
    process.env.RUNTIME_A11Y_BASE_URL = reviewConfig.baseUrl;
  }
  try {
    const payload = await captureVisualReviewEvidenceImpl(reviewConfig);
    const runs = Array.isArray(payload?.runs) ? payload.runs : [];
    const captureFailures = runs.filter((entry) => Array.isArray(entry?.probeOutcomes) && entry.probeOutcomes.some((outcome) => outcome?.status === 'capture-failure'));
    const summaryPayload = {
      classification: captureFailures.length > 0 ? 'fail' : 'pass',
      routeCount: 2,
      stateCount: 5,
      runCount: runs.length,
      runRoot: resolvedRunRoot,
      runs,
    };
    const summaryPath = path.join(resolvedRunRoot, 'preflight-summary.json');
    const persistedSummary = persistJsonArtifact(summaryPath, summaryPayload);
    const artifactHashes = {
      [path.relative(resolvedRunRoot, summaryPath).replace(/\\/g, '/')]: persistedSummary.artifactHash,
    };
    for (const entry of runs) {
      if (!entry) {
        continue;
      }
      for (const artifactKey of ['screenshotPath', 'measurementPath', 'tracePath']) {
        const relativeArtifactPath = entry?.[artifactKey];
        if (!relativeArtifactPath) {
          continue;
        }
        const artifactPath = path.resolve(resolvedRunRoot, relativeArtifactPath);
        if (!existsSync(artifactPath)) {
          continue;
        }
        const buffer = readFileSync(artifactPath);
        artifactHashes[path.normalize(relativeArtifactPath).replace(/\\/g, '/')] = createHash('sha256').update(buffer).digest('hex');
      }
    }
    return {
      status: captureFailures.length > 0 ? 'fail' : 'pass',
      artifactHashes,
      summary: summaryPayload,
    };
  } catch (error) {
    const summaryPayload = {
      classification: 'fail',
      routeCount: 2,
      stateCount: 5,
      runCount: 0,
      runRoot: resolvedRunRoot,
      runs: [],
      error: error instanceof Error ? error.message : String(error),
    };
    const summaryPath = path.join(resolvedRunRoot, 'preflight-summary.json');
    const persistedSummary = persistJsonArtifact(summaryPath, summaryPayload);
    return {
      status: 'fail',
      artifactHashes: { [path.relative(resolvedRunRoot, summaryPath).replace(/\\/g, '/')]: persistedSummary.artifactHash },
      summary: summaryPayload,
    };
  } finally {
    if (previousRunRoot === undefined) {
      delete process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT;
    } else {
      process.env.RUNTIME_A11Y_VISUAL_REVIEW_RUN_ROOT = previousRunRoot;
    }
    if (previousBaseUrl === undefined) {
      delete process.env.RUNTIME_A11Y_BASE_URL;
    } else {
      process.env.RUNTIME_A11Y_BASE_URL = previousBaseUrl;
    }
  }
}

export async function runRealCalibrationSession({
  config = {},
  runRoot = null,
  probePrerequisites: probePrerequisitesHandler = null,
  runVisualPreflight: runVisualPreflightHandler = null,
  runAtCase: runAtCaseHandler = null,
  launchBrowser = launchChrome,
} = {}) {
  const journeys = resolveCalibrationCases(config);
  const resolvedRunRoot = runRoot ? path.resolve(runRoot) : null;
  const checkpoints = [];
  const browserTeardown = {
    pageCloseStatus: 'skipped',
    pageCloseError: null,
    browserCloseStatus: 'skipped',
    browserCloseError: null,
    browserConnectedAfterClose: null,
  };
  const prerequisites = typeof probePrerequisitesHandler === 'function'
    ? await probePrerequisitesHandler({ config, runRoot: resolvedRunRoot })
    : await probePrerequisites({ config, runRoot: resolvedRunRoot });

  if (!prerequisites?.nvdaAvailable || !prerequisites?.desktopUnlocked) {
    return {
      config,
      journeys,
      checkpoints,
      aggregate: {
        status: 'incomplete',
        reason: 'Calibration prerequisites were not met.',
        completedCount: 0,
      },
      runRoot,
      state: { journeys: [] },
      browserTeardown,
    };
  }

  let visualPreflight = null;
  if (typeof runVisualPreflightHandler === 'function') {
    visualPreflight = await runVisualPreflightHandler({ config, runRoot: resolvedRunRoot });
  } else {
    visualPreflight = await runDefaultVisualPreflight({ config, runRoot: resolvedRunRoot });
  }

  const visualPreflightStatus = visualPreflight?.summary?.classification === 'pass' || visualPreflight?.status === 'pass' ? 'pass' : 'fail';

  let sharedBrowser = null;
  let sharedContext = null;
  let sharedPage = null;
  try {
    if (journeys.length > 0) {
      sharedBrowser = await launchBrowser({ headless: false });
      // Use the browser's default context so there is exactly one Chrome window.
      // newContext() creates an incognito window that competes with the default
      // New Tab window for OS foreground focus, causing NVDA to read the wrong
      // surface.  newPage() opens a tab in the default (already-focused) window.
      sharedPage = await sharedBrowser.newPage();
      sharedContext = typeof sharedPage.context === 'function' ? sharedPage.context() : null;
    }

    for (const journey of journeys) {
      const executor = typeof runAtCaseHandler === 'function' ? runAtCaseHandler : defaultRunAtCase;
      const payload = await executor({
        journeyId: journey.journeyId,
        journey,
        ordinal: 0,
        runRoot: resolvedRunRoot,
        config,
        browser: sharedBrowser,
        context: sharedContext,
        page: sharedPage,
      });

    const persistedPayload = buildPersistedEvidencePayload({
      journeyId: journey.journeyId,
      ordinal: 0,
      classification: payload?.classification,
      profileFingerprint: payload?.profileFingerprint || buildProfileFingerprint(config, journey),
      provenance: payload?.provenance || { driver: 'guidepup' },
      evidence: payload?.evidence || {},
      outcome: payload?.outcome || {},
    });
    const existingPersistedArtifact = resolvedRunRoot
      ? resolveExistingPersistedArtifact({
        ...persistedPayload,
        artifactHashes: payload?.artifactHashes || {},
      }, resolvedRunRoot)
      : null;
    const persistedEvidence = existingPersistedArtifact
      ? existingPersistedArtifact
      : (resolvedRunRoot
        ? persistSampleEvidence({
          runRoot: resolvedRunRoot,
          journeyId: journey.journeyId,
          ordinal: 0,
          payload: persistedPayload,
        })
        : null);

    const artifactHashes = { ...(payload?.artifactHashes || {}) };
    if (persistedEvidence) {
      artifactHashes[persistedEvidence.artifactReference] = persistedEvidence.artifactHash;
    }

    const materialized = materializeArtifactEvidence(artifactHashes, resolvedRunRoot);
    const hasValidEvidence = materialized.valid && hasMatchingArtifactHashes(materialized.artifactHashes, resolvedRunRoot);
    const evidence = {
      ...(payload?.evidence || {}),
      provenance: {
        ...(payload?.evidence?.provenance || {}),
        ...(payload?.provenance || {}),
        driver: payload?.driver || payload?.provenance?.driver || payload?.evidence?.provenance?.driver || 'guidepup',
        at: payload?.at || payload?.provenance?.at || payload?.evidence?.provenance?.at || 'nvda',
      },
    };
    const capability = {
      ...(payload?.capability || {}),
      supported: payload?.capability?.supported ?? true,
      synthetic: payload?.capability?.synthetic ?? false,
      at: payload?.capability?.at || 'nvda',
    };
    const provenance = {
      ...(payload?.provenance || {}),
      ...(evidence.provenance || {}),
      driver: payload?.driver || payload?.provenance?.driver || payload?.evidence?.provenance?.driver || 'guidepup',
      at: payload?.at || payload?.provenance?.at || payload?.evidence?.provenance?.at || 'nvda',
    };
    const classification = classifyAtCaseResult({
      ...payload,
      driver: provenance.driver,
      at: provenance.at,
      capability,
      classification: payload?.classification,
      artifactHashes: materialized.artifactHashes,
      evidence,
      provenance,
      outcome: payload?.outcome || {},
      requiredAssertions: (journey?.assertions || []).map((assertion) => ({ id: assertion?.id || assertion?.value || null, value: assertion?.value || null })),
    }, resolvedRunRoot);

      if (classification === 'pass' && hasValidEvidence) {
        const checkpoint = createCalibrationCheckpoint({
          journeyId: journey.journeyId,
          ordinal: 0,
          profileFingerprint: payload?.profileFingerprint || buildProfileFingerprint(config, journey),
          provenance: payload?.provenance || { driver: 'guidepup' },
          artifactHashes: materialized.artifactHashes,
          classification,
        });
        // Accept a checkpoint only when its own hash verifies. A checkpoint that
        // fails verification is discarded rather than counted as evidence.
        if (validateCalibrationCheckpoint(checkpoint)) {
          checkpoints.push(checkpoint);
        }
      }
    }
  } finally {
    if (sharedPage && typeof sharedPage.close === 'function') {
      try {
        await sharedPage.close();
        browserTeardown.pageCloseStatus = 'closed';
      } catch (error) {
        browserTeardown.pageCloseStatus = 'failed';
        browserTeardown.pageCloseError = error instanceof Error ? error.message : String(error);
      }
    }
    if (sharedBrowser && typeof sharedBrowser.close === 'function') {
      try {
        await sharedBrowser.close();
        browserTeardown.browserCloseStatus = 'closed';
      } catch (error) {
        browserTeardown.browserCloseStatus = 'failed';
        browserTeardown.browserCloseError = error instanceof Error ? error.message : String(error);
      }
    }
    if (sharedBrowser && typeof sharedBrowser.isConnected === 'function') {
      try {
        browserTeardown.browserConnectedAfterClose = sharedBrowser.isConnected();
      } catch {
        browserTeardown.browserConnectedAfterClose = null;
      }
    }
  }

  const aggregate = {
    status: visualPreflightStatus === 'fail' || checkpoints.length !== journeys.length ? 'unsuccessful' : 'successful',
    reason: visualPreflightStatus === 'fail' ? 'Visual preflight did not complete successfully.' : (checkpoints.length === journeys.length ? 'Calibration completed for the requested journeys.' : 'Calibration did not complete successfully because some journeys lacked accepted evidence.'),
    completedCount: checkpoints.length,
  };

  return {
    config,
    journeys,
    checkpoints,
    aggregate,
    runRoot,
    state: { journeys: checkpoints.map((checkpoint) => ({ journeyId: checkpoint.journeyId, classification: checkpoint.classification })) },
    visualPreflight,
    browserTeardown,
  };
}

function readInputPayload() {
  if (process.env.RUNTIME_A11Y_CONFIG) {
    return JSON.parse(process.env.RUNTIME_A11Y_CONFIG);
  }
  const raw = readFileSync(0, 'utf8').trim();
  if (!raw) {
    return null;
  }
  return JSON.parse(raw);
}

export async function main() {
  const config = readInputPayload();
  if (!config || typeof config !== 'object') {
    throw new Error('No configuration payload received.');
  }
  const runRoot = process.env.RUNTIME_A11Y_RUN_ROOT
    ? path.resolve(process.env.RUNTIME_A11Y_RUN_ROOT)
    : null;
  const session = await runRealCalibrationSession({
    config,
    runRoot,
  });
  const document = {
    tool: 'runtime_a11y',
    command: 'run-calibration',
    runAt: new Date().toISOString(),
    baseUrl: config?.baseUrl || '',
    journeys: session.journeys.map((journey) => journey.journeyId),
    visualStates: config?.calibration?.visualStates || [],
    runRoot: runRoot || null,
    aggregate: session.aggregate,
    checkpoints: session.checkpoints,
    state: session.state,
    browserTeardown: session.browserTeardown,
  };
  process.stdout.write(`${JSON.stringify(document, null, 2)}\n`);
  return document;
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  main().catch((error) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}
