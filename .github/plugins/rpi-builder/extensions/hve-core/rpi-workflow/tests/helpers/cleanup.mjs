// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/** Canvas servers the current test started; a listening one would keep the test process running. */
const servers = new Set();

/**
 * Registers a server to stop after the current test, even when an assertion fails first.
 *
 * @template {{ stop: () => Promise<void> }} T
 * @param {T} server
 * @returns {T} the same server
 */
export function track(server) {
    servers.add(server);
    return server;
}

/** Stops every tracked server; use as an `afterEach` hook. Stopping a server twice is harmless. */
export async function stopTracked() {
    const open = [...servers];
    servers.clear();
    await Promise.all(open.map((server) => server.stop()));
}
