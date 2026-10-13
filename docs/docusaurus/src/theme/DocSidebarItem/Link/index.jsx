// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import DocSidebarItemLink from '@theme-original/DocSidebarItem/Link';

// Landing pages share the visible label "Overview". The `accessibleName` sidebar
// custom prop names the section for link-list navigation and must start with the
// visible label (WCAG 2.5.3 Label in Name).
export default function DocSidebarItemLinkWrapper(props) {
  const accessibleName = props.item.customProps?.accessibleName;
  return <DocSidebarItemLink {...props} aria-label={accessibleName} />;
}
