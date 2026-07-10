// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Navbar from '@theme-original/Navbar';

// Wrap the navbar in a top-level <header> so every page (including custom
// pages such as the home page and the 404 page) exposes exactly one banner
// landmark. The inner <nav> remains the navigation landmark, so both roles
// are present. WCAG 1.3.1 / ARIA landmark completeness.
export default function NavbarWrapper(props) {
  return (
    <header>
      <Navbar {...props} />
    </header>
  );
}
