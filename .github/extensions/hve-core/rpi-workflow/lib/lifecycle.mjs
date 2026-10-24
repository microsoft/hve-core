// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * Tracks one page server per canvas instance. Opens for the same instance share one
 * start. A close that arrives while an open prepares its session prevents the server, and
 * a close that arrives while a start is pending stops the server it produced.
 *
 * @template {{ start: () => Promise<string>, stop: () => Promise<void>, listening: boolean }} S
 * @param {{ createServer: (record: { sessionId: string, instanceId: string }) => S, makeError: (code: string, message: string) => Error }} deps
 */
export function createInstanceRegistry(deps) {
    const { createServer, makeError } = deps;
    /** @type {Map<string, { server: S, sessionId: string, instanceId: string, closed: boolean }>} */
    const instances = new Map();
    /** @type {Map<string, { record: { server: S, sessionId: string, instanceId: string, closed: boolean }, promise: Promise<any> }>} */
    const pending = new Map();
    /** @type {Map<string, Set<{ closed: boolean }>>} */
    const preparing = new Map();

    function ensure(instanceId, sessionId) {
        const existing = instances.get(instanceId);
        if (existing?.server.listening) {
            return Promise.resolve(existing);
        }
        if (existing) {
            instances.delete(instanceId);
        }
        const inFlight = pending.get(instanceId);
        if (inFlight) {
            return inFlight.promise;
        }
        const record = { server: /** @type {S} */ (/** @type {unknown} */ (null)), sessionId, instanceId, closed: false };
        record.server = createServer(record);
        const promise = (async () => {
            try {
                await record.server.start();
            } catch {
                throw makeError(record.closed ? 'instance_closed' : 'server_unavailable', record.closed ? 'The canvas closed while it was opening.' : 'The RPI Workflow page could not start.');
            }
            if (record.closed) {
                await record.server.stop();
                throw makeError('instance_closed', 'The canvas closed while it was opening.');
            }
            instances.set(instanceId, record);
            return record;
        })();
        const entry = { record, promise };
        pending.set(instanceId, entry);
        const settle = () => {
            if (pending.get(instanceId) === entry) {
                pending.delete(instanceId);
            }
        };
        promise.then(settle, settle);
        return promise;
    }

    return {
        /**
         * Opens the instance. When `prepare` is given it runs first, and a close during it
         * rejects the open with `instance_closed` before any server starts.
         *
         * @param {{ instanceId: string, sessionId: string, prepare?: () => Promise<unknown> }} request
         */
        open(request) {
            const { instanceId, sessionId, prepare } = request;
            if (!prepare) {
                return ensure(instanceId, sessionId);
            }
            const intent = { closed: false };
            const intents = preparing.get(instanceId) ?? new Set();
            preparing.set(instanceId, intents);
            intents.add(intent);
            return (async () => {
                try {
                    await prepare();
                } finally {
                    intents.delete(intent);
                    if (intents.size === 0 && preparing.get(instanceId) === intents) {
                        preparing.delete(instanceId);
                    }
                }
                if (intent.closed) {
                    throw makeError('instance_closed', 'The canvas closed while it was opening.');
                }
                return ensure(instanceId, sessionId);
            })();
        },

        /** @param {string} instanceId */
        async close(instanceId) {
            for (const intent of preparing.get(instanceId) ?? []) {
                intent.closed = true;
            }
            const inFlight = pending.get(instanceId);
            if (inFlight) {
                inFlight.record.closed = true;
                await inFlight.record.server.stop();
            }
            const record = instances.get(instanceId);
            instances.delete(instanceId);
            if (record) {
                record.closed = true;
                await record.server.stop();
            }
        },

        /** @param {string} instanceId */
        get(instanceId) {
            return instances.get(instanceId);
        },

        get size() {
            return instances.size;
        },
    };
}
