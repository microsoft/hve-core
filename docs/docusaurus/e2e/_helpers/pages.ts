// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

export interface PageSpec {
  name: string;
  path: string;
}

export const PAGES: readonly PageSpec[] = [
  { name: 'home', path: '/hve-core/' },
  { name: 'docs index', path: '/hve-core/docs/' },
  { name: 'getting-started', path: '/hve-core/docs/getting-started/' },
  { name: 'content (task-researcher)', path: '/hve-core/docs/rpi/task-researcher/' },
  { name: 'not-found (404)', path: '/hve-core/this-page-does-not-exist/' },
];
