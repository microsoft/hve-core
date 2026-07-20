// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, {useEffect, useRef} from 'react';
import {useLocation} from '@docusaurus/router';
import Layout from '@theme-original/Layout';

// Move keyboard focus to the main landmark after a route change so that
// activating a navigation link does not reset focus to the skip link.
// WCAG 2.4.3 Focus Order.
export default function LayoutWrapper(props) {
  const {pathname, hash} = useLocation();
  const isInitialRender = useRef(true);

  useEffect(() => {
    // Skip the first render (initial page load) and in-page anchor navigation.
    if (isInitialRender.current) {
      isInitialRender.current = false;
      return;
    }
    if (hash) {
      return;
    }

    const main = document.querySelector('main');
    if (main instanceof HTMLElement) {
      if (main.getAttribute('tabindex') !== '-1') {
        main.setAttribute('tabindex', '-1');
      }
      window.requestAnimationFrame(() => {
        main.focus({preventScroll: true});
      });
    }
  }, [pathname, hash]);

  return <Layout {...props} />;
}
