// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/** The stable ID published by the plugin. */
export const CANVAS_ID = 'hve-core-rpi-workflow';
export const PREVIEW_CANVAS_ID = 'hve-core-rpi-workflow-preview';

/**
 * The instance ID of a session's canvas in a new panel. The preview uses its own prefix so it
 * does not reuse an instance reserved for the published canvas or an older project canvas.
 *
 * @param {string} sessionId
 * @param {string} [canvasId]
 * @returns {string}
 */
export function panelInstanceId(sessionId, canvasId = CANVAS_ID) {
    const prefix = canvasId === PREVIEW_CANVAS_ID ? 'rpi-preview-' : 'rpi-';
    return `${prefix}${String(sessionId).slice(0, 8).toLowerCase()}`;
}

/**
 * The provider that the host opened a canvas instance through, from the open request. The instance's
 * panels open through the same provider, so the host opens the same extension.
 *
 * @param {{ extensionId?: unknown } | null | undefined} request the host's open request
 * @returns {string | null}
 */
export function providerOf(request) {
    return typeof request?.extensionId === 'string' && request.extensionId ? request.extensionId : null;
}

/**
 * Whether the host lists an open instance with this ID. This is best effort: a host that cannot list
 * its canvases, or fails to, reads as none open.
 *
 * @param {any} canvas the host's canvas API
 * @param {string} instanceId
 * @returns {Promise<boolean>}
 */
async function isOpen(canvas, instanceId) {
    if (typeof canvas.listOpen !== 'function') return false;
    try {
        const listed = await canvas.listOpen();
        return Array.isArray(listed?.openCanvases) && listed.openCanvases.some((item) => item?.instanceId === instanceId);
    } catch {
        return false;
    }
}

/**
 * Opens a session's RPI canvas in a new panel of the joined session, or reports it focused when
 * the host already lists that instance open. The provider is the one that opened this canvas, read at
 * each open. Throws when the host has no canvas API, when no provider is known, or when the host refuses.
 *
 * @param {{ rpc: () => any, extensionId: () => string | null | undefined, canvasId: string }} deps
 * @returns {(request: { session: string }) => Promise<{ outcome: 'opened' | 'focused', instanceId: string }>}
 */
export function createPanelOpener(deps) {
    return async function openPanel({ session }) {
        const canvas = deps.rpc()?.canvas;
        if (typeof canvas?.open !== 'function') throw new Error('This host cannot open canvas panels.');
        const extensionId = deps.extensionId();
        if (!extensionId) throw new Error('This canvas does not know its provider, so it cannot open a panel.');
        const instanceId = panelInstanceId(session, deps.canvasId);
        const focus = await isOpen(canvas, instanceId);
        await canvas.open({ extensionId, canvasId: deps.canvasId, instanceId, input: { session } });
        return { outcome: focus ? 'focused' : 'opened', instanceId };
    };
}
