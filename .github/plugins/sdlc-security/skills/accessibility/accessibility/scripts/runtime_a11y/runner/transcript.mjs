// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// A screen reader speaks everything on screen. On an authenticated surface that
// includes names, email addresses, and account details, so a transcript never
// travels in probe evidence, rendered artifacts, or agent-readable output.
//
// Retention is opt-in because an assertion failure reports only that a match
// failed and never what was actually announced, which leaves a real
// assistive-technology failure undiagnosable without the observed text. When
// enabled, the transcript is written to a restricted local file and referenced
// by digest so the evidence chain stays intact without inlining the content.
const RETAIN_FLAG = 'RUNTIME_A11Y_RETAIN_SR_TRANSCRIPT';
const TRANSCRIPT_ROOT = '.copilot-tracking/accessibility/local-runs/transcripts';
const OWNER_READ_WRITE = 0o600;

export function transcriptRetentionEnabled(env = process.env) {
  return env[RETAIN_FLAG] === '1';
}

export function digestPhrases(phrases) {
  return createHash('sha256').update(JSON.stringify(phrases)).digest('hex');
}

export function retainScreenReaderTranscript(phrases, context = {}, env = process.env) {
  const list = Array.isArray(phrases) ? phrases : [];
  const digest = digestPhrases(list);
  const record = {
    phraseCount: list.length,
    sha256: digest,
    retained: false,
    path: null,
  };

  if (!transcriptRetentionEnabled(env)) {
    return record;
  }

  const root = join(process.cwd(), TRANSCRIPT_ROOT);
  mkdirSync(root, { recursive: true });
  const name = `${digest.slice(0, 16)}.json`;
  const path = join(root, name);
  writeFileSync(
    path,
    JSON.stringify(
      {
        capturedAt: new Date().toISOString(),
        surfaceId: context.surfaceId ?? null,
        state: context.state ?? null,
        sha256: digest,
        phrases: list,
      },
      null,
      2,
    ),
    { encoding: 'utf8', mode: OWNER_READ_WRITE },
  );

  record.retained = true;
  record.path = join(TRANSCRIPT_ROOT, name);
  return record;
}
