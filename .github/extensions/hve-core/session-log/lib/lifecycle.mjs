// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * @typedef {object} LifecycleServer
 * @property {() => Promise<string>} start
 * @property {() => Promise<void>} stop
 * @property {(requested: string | null | undefined) => string | null} select
 * @property {boolean} listening
 */

/**
 * @typedef {object} InstanceRecord
 * @property {LifecycleServer} server
 * @property {string | null} currentSessionId Session that opened the instance.
 * @property {boolean} closed
 */

/**
 * Tracks one page server per canvas instance. Opens for the same instance share one start,
 * and a close that arrives while a start is pending stops the server it produced.
 *
 * @param {object} deps
 * @param {(record: InstanceRecord) => LifecycleServer} deps.createServer Builds a server bound to the record.
 * @param {(code: string, message: string) => Error} deps.makeError Builds host-visible errors.
 */
export function createInstanceRegistry(deps) {
    const { createServer, makeError } = deps;
    /** @type {Map<string, InstanceRecord>} */
    const instances = new Map();
    /** @type {Map<string, { record: InstanceRecord, promise: Promise<InstanceRecord> }>} */
    const pending = new Map();

    /**
     * @param {string} instanceId
     * @param {string | null} currentSessionId
     * @returns {Promise<InstanceRecord>}
     */
    function ensure(instanceId, currentSessionId) {
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
        /** @type {InstanceRecord} */
        const record = { server: /** @type {any} */ (null), currentSessionId, closed: false };
        record.server = createServer(record);
        const promise = (async () => {
            try {
                await record.server.start();
            } catch {
                if (record.closed) {
                    throw makeError('instance_closed', 'The canvas closed while it was opening.');
                }
                throw makeError('server_unavailable', 'The Session Log page could not start.');
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
         * Opens or reuses the instance's server and applies the requested selection.
         * An omitted session keeps the existing selection; `current` follows the opening session.
         *
         * @param {{ instanceId: string, currentSessionId: string | null, sessionId?: string }} request
         * @returns {Promise<InstanceRecord>}
         */
        async open(request) {
            const record = await ensure(request.instanceId, request.currentSessionId);
            if (request.currentSessionId) {
                record.currentSessionId = request.currentSessionId;
            }
            try {
                record.server.select(request.sessionId);
            } catch {
                throw makeError('invalid_input', 'sessionId must be a session ID or "current".');
            }
            return record;
        },

        /**
         * Stops the instance's server, including one whose start is still pending.
         *
         * @param {string} instanceId
         */
        async close(instanceId) {
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

        /**
         * @param {string} instanceId
         * @returns {InstanceRecord | undefined} The open instance, if any.
         */
        get(instanceId) {
            return instances.get(instanceId);
        },

        /** @returns {number} Count of open instances. */
        get size() {
            return instances.size;
        },
    };
}
