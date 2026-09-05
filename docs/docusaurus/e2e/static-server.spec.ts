// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { spawn, type ChildProcess } from 'node:child_process';
import { test, expect } from '@playwright/test';

// Regression lock for the e2e static server's not-found handler.
//
// The handler used to serve a buffer read once at process start. Docusaurus
// emits content-hashed asset filenames, so a server left running across a
// rebuild kept returning HTML that referenced deleted bundles. Nothing about
// that failure looked like a server problem: the 404 route simply never
// hydrated, and every accessibility test on it timed out inside the shared
// waitForHydration helper before its own assertion ran. Nine tests reported
// nine different-sounding failures with one shared cause, and the 404 page
// itself was never at fault.
//
// Asserting only that the page's current asset references resolve would not
// catch a reintroduction, because a freshly started server serves correct
// bytes even with startup caching in place. The staleness is only observable
// when the file changes underneath a running server, so this test creates that
// condition directly: mutate the built 404 page, then require the server to
// serve the mutation.
//
// Serial by necessity. The sentinel is written into shared build output, so a
// parallel worker requesting an unknown route mid-test would observe it.
test.describe.configure({ mode: 'serial' });

const currentDir = __dirname;
const notFoundPage = path.resolve(currentDir, '..', 'build', '404.html');

test.describe('e2e static server not-found handler', () => {
  test('serves the current 404 page after it changes on disk', async ({ request }) => {
    const original = fs.readFileSync(notFoundPage);
    const sentinel = `stale-404-guard-${Date.now()}`;

    try {
      // Confirm the sentinel is absent first, so a pass cannot come from the
      // marker having already been present in the build output.
      const before = await request.get('/hve-core/this-page-does-not-exist/');
      expect(before.status(), 'an unknown route should return 404').toBe(404);
      expect(
        await before.text(),
        'the sentinel must not be present before the file is modified',
      ).not.toContain(sentinel);

      // Modify the file underneath the running server. A handler that resolves
      // the page per request picks this up; one that cached at startup cannot.
      fs.writeFileSync(
        notFoundPage,
        original.toString('utf8').replace('</body>', `<!-- ${sentinel} --></body>`),
      );

      const after = await request.get('/hve-core/this-page-does-not-exist/');
      expect(after.status(), 'an unknown route should still return 404').toBe(404);
      expect(
        await after.text(),
        'the not-found handler must read the 404 page per request, not cache it at startup',
      ).toContain(sentinel);
    } finally {
      // Restore the exact original bytes even when an assertion above fails, so
      // a failure here cannot corrupt the build output for later tests.
      fs.writeFileSync(notFoundPage, original);
    }
  });

  test('serves the 404 page as HTML', async ({ request }) => {
    // sendFile derives Content-Type from the file extension rather than the
    // explicit type('html') the previous implementation set, so the resulting
    // header is asserted rather than assumed.
    const response = await request.get('/hve-core/this-page-does-not-exist/');
    expect(response.status()).toBe(404);
    expect(response.headers()['content-type']).toContain('text/html');
  });
});

// The shipped limit is sized for parallel workers sharing one loopback address,
// so enforcement is proved against a second server instance configured with a
// tiny budget. It runs on its own reserved port and never touches the port the
// rest of the suite is using.
test.describe('e2e static server rate limiting', () => {
  test.describe.configure({ mode: 'serial' });

  const windowMs = 2000;
  const limit = 3;
  let server: ChildProcess | undefined;
  let port = 0;
  let origin = '';

  async function reserveLoopbackPort(): Promise<number> {
    return await new Promise<number>((resolve, reject) => {
      const probe = net.createServer();
      probe.once('error', reject);
      probe.listen(0, '127.0.0.1', () => {
        const address = probe.address() as net.AddressInfo;
        probe.close(() => resolve(address.port));
      });
    });
  }

  async function canConnect(target: number): Promise<boolean> {
    return await new Promise<boolean>((resolve) => {
      const socket = net.connect({ port: target, host: '127.0.0.1' });
      socket.once('connect', () => {
        socket.destroy();
        resolve(true);
      });
      socket.once('error', () => {
        socket.destroy();
        resolve(false);
      });
    });
  }

  // A TCP probe rather than an HTTP request, so readiness polling cannot consume
  // the very budget these tests assert on.
  async function waitForPort(target: number, expected: boolean): Promise<void> {
    const deadline = Date.now() + 20_000;
    while (Date.now() < deadline) {
      if ((await canConnect(target)) === expected) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error(`port ${target} never reached connectable=${expected}`);
  }

  test.beforeAll(async () => {
    port = await reserveLoopbackPort();
    origin = `http://127.0.0.1:${port}`;
    server = spawn(process.execPath, [path.resolve(currentDir, 'static-server.mjs')], {
      env: {
        ...process.env,
        PORT: String(port),
        HOST: '127.0.0.1',
        RATE_LIMIT_MAX: String(limit),
        RATE_LIMIT_WINDOW_MS: String(windowMs),
      },
      stdio: 'ignore',
    });
    await waitForPort(port, true);
  });

  test.afterAll(async () => {
    server?.kill();
    server = undefined;
    await waitForPort(port, false);
  });

  test('advertises the standard rate limit policy and omits legacy headers', async () => {
    const response = await fetch(`${origin}/hve-core/`);

    expect(response.status).toBe(200);
    expect(response.headers.get('ratelimit-policy')).toContain(String(limit));
    expect(response.headers.get('x-ratelimit-limit')).toBeNull();
  });

  test('returns 429 past the budget and serves again after the window resets', async () => {
    // Start from a fresh window so the previous test's request cannot shift the count.
    await new Promise((resolve) => setTimeout(resolve, windowMs + 100));

    const statuses: number[] = [];
    for (let attempt = 0; attempt < limit + 1; attempt += 1) {
      const response = await fetch(`${origin}/hve-core/`);
      statuses.push(response.status);
    }

    expect(statuses.slice(0, limit)).toEqual(Array(limit).fill(200));
    expect(statuses[limit]).toBe(429);

    await new Promise((resolve) => setTimeout(resolve, windowMs + 100));
    const recovered = await fetch(`${origin}/hve-core/`);
    expect(recovered.status).toBe(200);
  });
});
