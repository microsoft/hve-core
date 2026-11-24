// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import { ReviewError } from './model.mjs';

export function createRegistry() {
    const instances = new Map();
    const pending = new Map();
    return {
        get: (instanceId) => instances.get(instanceId),
        get size() { return instances.size; },
        open(instanceId, create) {
            if (instances.has(instanceId)) return Promise.resolve(instances.get(instanceId));
            if (pending.has(instanceId)) return pending.get(instanceId).promise;
            const entry = { closed: false, record: null, promise: null };
            pending.set(instanceId, entry);
            entry.promise = (async () => {
                try {
                    entry.record = await create();
                    if (entry.closed) throw new ReviewError('instance_closed', 'The canvas closed while opening.');
                    await entry.record.server.start();
                    if (entry.closed) throw new ReviewError('instance_closed', 'The canvas closed while opening.');
                    instances.set(instanceId, entry.record);
                    return entry.record;
                } catch (error) {
                    if (entry.record) await entry.record.server.stop();
                    throw error;
                } finally {
                    if (pending.get(instanceId) === entry) pending.delete(instanceId);
                }
            })();
            return entry.promise;
        },
        async close(instanceId) {
            const opening = pending.get(instanceId);
            if (opening) opening.closed = true;
            const current = instances.get(instanceId);
            instances.delete(instanceId);
            if (current) await current.server.stop();
        },
        async closeAll() {
            for (const entry of pending.values()) entry.closed = true;
            await Promise.all([...instances.keys()].map((key) => this.close(key)));
        },
    };
}
