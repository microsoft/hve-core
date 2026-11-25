// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

/**
 * A change map in the format plans used before boxes, tags, and formatted labels: plain labels,
 * `Added:` prefixes, a font line, and a `new` class. The canvas keeps drawing plans written this
 * way, so tests read this frozen copy of the sample's former After diagram rather than the sample.
 */
export const OLDER_AFTER = [
    '%%{init: {"themeVariables": {"fontFamily": "Arial, Helvetica, sans-serif", "fontSize": "16px"}}}%%',
    'flowchart LR',
    '    form["Inspection form"]',
    '    store["Added: draft store"]',
    '    outbox["Added: outbox"]',
    '    sync["Added: sync engine"]',
    '    conflicts["Added: conflict review"]',
    '    uploader["Added: chunk uploader"]',
    '    status["Added: sync status chip"]',
    '    api["src/api/inspections.ts"]',
    '    server["Inspections API"]',
    '    picker["Photo picker"]',
    '    form -->|autosaves to| store',
    '    store -->|enqueues| outbox',
    '    sync -->|drains| outbox',
    '    sync -->|If-Match PUT| api',
    '    api -->|PUT| server',
    '    sync -->|flags| conflicts',
    '    picker -->|queues| uploader',
    '    uploader -->|chunks to| server',
    '    status -->|reads| sync',
    '    classDef new stroke-dasharray: 5 5',
    '    class store,outbox,sync,conflicts,uploader,status new',
].join('\n');
