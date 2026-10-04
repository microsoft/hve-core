// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';
import { getCheckFindings } from '../checks.mjs';
import { loadParser, readProbes, runProbes } from '../run-probes.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..', '..', '..');
const probesDir = join(here, '..', 'probes');
const checkoutMetadata = 'name: checkout\ninputs:\n  ref:\n    description: ref\n';
const MAPPED = new Set(['parser', 'pinning', 'runner-policy', 'zizmor']);

function watches() {
  const register = parse(readFileSync(join(repoRoot, 'security', 'upstream-watches.yml'), 'utf8'));
  return new Map(register.watches.filter((watch) => watch.kind === 'probe-outcome').map((watch) => [watch.probe, watch]));
}

describe('capability probes', () => {
  it('register one probe-outcome watch per probe', () => {
    const registered = watches();
    const ids = readProbes().map((probe) => probe.id);
    assert.deepEqual([...registered.keys()].sort(), [...ids].sort());
    for (const probe of readProbes()) {
      assert.equal(registered.get(probe.id).id, `workflow-parser-probe-${probe.id}`);
      assert.equal(registered.get(probe.id).baseline, probe.coveredBy === 'parser' ? 'pass' : 'fail', probe.id);
    }
  });

  it('match their baselines with the pinned parser, so a parser bump that changes coverage fails here', async () => {
    const { parser } = await loadParser(null);
    const outcomes = await runProbes(parser);
    const registered = watches();
    for (const [id, outcome] of Object.entries(outcomes)) {
      assert.equal(outcome, registered.get(id).baseline, `probe ${id} reported ${outcome}; update its watch baseline and the custom check it guards`);
    }
  });

  it('name an existing check for every case the parser misses', () => {
    for (const probe of readProbes()) {
      assert.ok(MAPPED.has(probe.coveredBy) || probe.coveredBy.startsWith('workflow-check/'), `${probe.id}: ${probe.coveredBy}`);
    }
  });

  for (const probe of readProbes().filter((entry) => entry.coveredBy.startsWith('workflow-check/'))) {
    it(`are caught by ${probe.coveredBy} (${probe.id})`, async () => {
      const content = readFileSync(join(probesDir, probe.file), 'utf8');
      const findings = await getCheckFindings(probe.file, content, 'workflow', {
        repoRoot,
        fetchText: async (url) => (url.includes('/actions/checkout/') && url.endsWith('/action.yml') ? checkoutMetadata : null),
      });
      assert.ok(findings.some((finding) => finding.ruleId === probe.coveredBy), JSON.stringify(findings));
    });
  }
});
