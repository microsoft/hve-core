// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * The host's canvas API as a fake. `listed` is the canvases it reports open at first, and each panel
 * it opens is listed afterward; `listing`, when given, is what listing returns instead, for a host that
 * answers in another shape. `listError` makes listing fail and `openError` makes opening refuse. Every
 * open is recorded in `opens`.
 *
 * @param {{ listed?: object[], listing?: unknown, listError?: Error | null, openError?: Error | null }} [options]
 */
export function hostCanvas({ listed = [], listing, listError = null, openError = null } = {}) {
    const opens = [];
    const open = [...listed];
    return {
        opens,
        canvas: {
            listOpen: async () => {
                if (listError) throw listError;
                return listing === undefined ? { openCanvases: [...open] } : listing;
            },
            open: async (params) => {
                opens.push(params);
                if (openError) throw openError;
                const instance = { instanceId: params.instanceId, extensionId: params.extensionId, canvasId: params.canvasId };
                open.push(instance);
                return instance;
            },
        },
    };
}
