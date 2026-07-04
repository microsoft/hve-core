// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3001/hve-core/';
const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: isCI,
  // Locally, fail fast (retries: 0) for a tight iteration loop; in CI keep
  // retries to absorb transient navigation resets. The e2e suite is served by a
  // production-grade static server (e2e/static-server.mjs) that tolerates many
  // concurrent connections, so multiple workers are safe.
  retries: isCI ? 2 : 0,
  workers: isCI ? 2 : 4,
  reporter: isCI
    ? [['github'], ['list'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    // Tracing/video are expensive; keep them off locally and only capture
    // diagnostics in CI.
    trace: isCI ? 'on-first-retry' : 'off',
    video: isCI ? 'retain-on-failure' : 'off',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    },
  ],
  webServer: {
    // In CI the workflow runs `npm run build` as its own step, so the e2e run
    // only needs to serve that output (no redundant second build). Locally,
    // build then serve so a bare `test:e2e` is self-contained; `test:e2e:fast`
    // reuses an already-running server (see serve:preview) and skips both.
    command: isCI ? 'npm run serve:ci' : 'npm run build && npm run serve:ci',
    url: baseURL,
    reuseExistingServer: !isCI,
    timeout: 240000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
