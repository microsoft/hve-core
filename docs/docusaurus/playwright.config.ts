import { defineConfig, devices } from '@playwright/test';

const baseURL = 'http://127.0.0.1:3001/hve-core/';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI
    ? [['github'], ['list'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    },
  ],
  webServer: {
    command: 'npm run build && npm run serve:ci',
    url: baseURL,
    // Each step owns its own server lifecycle. In CI the pa11y-ci step runs
    // via start-server-and-test, which starts and then stops `serve:ci`, so
    // nothing is left listening here and Playwright builds and serves its
    // own instance. Locally, `reuseExistingServer: true` reuses an already
    // running dev/serve process instead of failing on a port conflict.
    reuseExistingServer: true,
    timeout: 180000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
