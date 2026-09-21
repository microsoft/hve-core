// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import MDXComponents from '@theme-original/MDXComponents';

// Docusaurus renders wide markdown tables as horizontally scrollable. A
// scrollable region must be operable by keyboard so it can be scrolled without
// a pointer (WCAG 2.1.1 / axe scrollable-region-focusable). The focusable
// scroll container is the wrapping <div>, NOT the <table>: putting tabindex on
// the <table> itself makes screen readers treat it as a focusable object and
// breaks native table navigation (Ctrl+Alt+Arrow cell movement). Rendering the
// wrapper and its tabindex at build time keeps the focusable region present in
// the pre-rendered HTML, before hydration, so an on-load accessibility scan
// always sees it.
//
// A focusable element also needs an accessible name, otherwise it is announced
// only as a group with no indication of what it contains. The wrapper is named
// at build time so the pre-rendered markup is complete, then refined on the
// client to include the table's caption when one exists.
//
// The wrapper is a group rather than a region: role="region" is a landmark, and
// landmarks must be uniquely named, so a page with several tables would emit
// duplicate landmarks (axe landmark-unique) and clutter the landmark list a
// screen reader user navigates by. A group carries the accessible name without
// entering the landmark structure.
function Table(props: React.ComponentProps<'table'>): React.ReactElement {
  const wrapperRef = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    const wrapper = wrapperRef.current;
    const caption = wrapper?.querySelector('caption')?.textContent?.trim();
    if (wrapper && caption) {
      wrapper.setAttribute('aria-label', `${caption}, scrollable table`);
    }
  }, []);

  return (
    // The scroll container is non-interactive but must be keyboard focusable
    // (WCAG 2.1.1). jsx-a11y/no-noninteractive-tabindex does not model the
    // scrollable-region case, so it is disabled here with intent.
    <div
      className="tableWrapper"
      ref={wrapperRef}
      role="group"
      aria-label="Scrollable table"
      // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex
      tabIndex={0}
    >
      <table {...props} />
    </div>
  );
}

export default {
  ...MDXComponents,
  table: Table,
};
