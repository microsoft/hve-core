// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import MDXComponents from '@theme-original/MDXComponents';

// Docusaurus renders wide markdown tables as horizontally scrollable
// (display: block; overflow: auto). A scrollable region must be operable by
// keyboard so it can be scrolled without a pointer (WCAG 2.1.1 / axe
// scrollable-region-focusable). Rendering the tabindex at build time keeps it
// present in the pre-rendered HTML, before hydration, so an accessibility scan
// on load always sees a focusable scroll region.
function Table(props: React.ComponentProps<'table'>): React.ReactElement {
  return <table {...props} tabIndex={0} />;
}

export default {
  ...MDXComponents,
  table: Table,
};
