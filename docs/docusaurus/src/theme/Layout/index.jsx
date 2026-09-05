// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, {useEffect} from 'react';
import {useLocation} from '@docusaurus/router';
import Layout from '@theme-original/Layout';

// The container the classic layout renders as the skip link's destination. It is
// a plain div, so on routes whose page supplies no landmark of its own the skip
// link resolves to a non-landmark and there is nothing for it to move focus to.
const SKIP_TO_CONTENT_FALLBACK_ID = '__docusaurus_skipToContent_fallback';

// Whether the first document load has already been observed. This is module
// scope rather than component state on purpose: navigating across a layout
// boundary unmounts and remounts Layout, so an instance-scoped ref would reset
// to its initial value and the route-change effect below would skip focusing
// main content. The guard's intent is "do not steal focus on the initial page
// load", which is a per-document condition. A module-scope flag has exactly
// that lifetime, persisting across remounts and resetting on a full page load.
let hasCompletedInitialLoad = false;

const isSearchRoute = (pathname) => /(^|\/)search\/?$/.test(pathname);

// Move keyboard focus to the main landmark after a route change so that
// activating a navigation link does not reset focus to the skip link.
// WCAG 2.4.3 Focus Order.
export default function LayoutWrapper(props) {
  const {pathname, hash} = useLocation();

  // The upstream search page owns its own Layout, so a landmark cannot be
  // inserted around its content from here without enclosing the header and
  // footer too. Promoting the existing skip-link container to a main landmark
  // on this route reuses the element the skip link already targets, so no
  // competing destination is created. Applied only where the page supplies no
  // landmark of its own; routes that already render <main> are untouched.
  useEffect(() => {
    const fallback = document.getElementById(SKIP_TO_CONTENT_FALLBACK_ID);
    if (!fallback) {
      return undefined;
    }
    if (!isSearchRoute(pathname) || document.querySelector('main')) {
      if (fallback.getAttribute('role') === 'main') {
        fallback.removeAttribute('role');
      }
      return undefined;
    }
    fallback.setAttribute('role', 'main');
    return () => {
      fallback.removeAttribute('role');
    };
  }, [pathname]);

  useEffect(() => {
    // Skip the initial page load and in-page anchor navigation.
    if (!hasCompletedInitialLoad) {
      hasCompletedInitialLoad = true;
      return;
    }
    if (hash) {
      return;
    }

    const main = document.querySelector('main, [role="main"]');
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
