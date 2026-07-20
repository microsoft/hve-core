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
  { name: 'customization', path: '/hve-core/docs/customization/' },
  { name: 'architecture', path: '/hve-core/docs/architecture/' },
  { name: 'security', path: '/hve-core/docs/security/' },
  { name: 'rpi', path: '/hve-core/docs/rpi/' },
  { name: 'design-thinking', path: '/hve-core/docs/design-thinking/' },
  { name: 'contributing', path: '/hve-core/docs/contributing/' },
  { name: 'templates', path: '/hve-core/docs/templates/' },
  { name: 'agents', path: '/hve-core/docs/agents/' },
  { name: 'hve-guide', path: '/hve-core/docs/hve-guide/' },
  { name: 'content (task-researcher)', path: '/hve-core/docs/rpi/task-researcher/' },
  { name: 'not-found (404)', path: '/hve-core/this-page-does-not-exist/' },
];
