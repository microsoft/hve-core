// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import styles from './accessibility.module.css';

export default function AccessibilityStatementPage(): React.ReactElement {
  return (
    <Layout
      title="Accessibility statement"
      description="Accessibility statement and conformance information for HVE Core documentation and resources"
    >
      <a className={styles.skipLink} href="#main-content">
        Skip to main content
      </a>
      <main id="main-content" className={styles.main}>
        <header className={styles.hero}>
          <p className={styles.eyebrow}>Accessibility</p>
          <h1>Accessibility statement</h1>
          <p className={styles.summary}>
            HVE Core is committed to providing documentation and resources that are usable with common assistive technologies.
            We aim to meet the WCAG 2.2 Level AA conformance target for the documentation site and related public content.
          </p>
          <p className={styles.reviewNote}>
            This statement and its companion VPAT are a self-assessment authored with AI assistance and validated by automated accessibility testing. They have not been independently audited; we welcome corrections.
          </p>
        </header>

        <section className={styles.section} aria-labelledby="conformance-target">
          <h2 id="conformance-target">Conformance target</h2>
          <p>
            The public HVE Core documentation site is intended to meet WCAG 2.2 Level AA.
            Our current goal is to provide equivalent access to core guidance, navigation, and reference content for keyboard and screen-reader users.
          </p>
          <ul>
            <li><strong>Target:</strong> WCAG 2.2 Level AA</li>
            <li><strong>Status:</strong> Self-assessment &mdash; automated accessibility checks pass site-wide and remediation is complete for identified issues; not independently audited</li>
            <li><strong>Assessment date:</strong> 2026-07-03</li>
            <li><strong>Assessment method:</strong> Automated accessibility testing (axe-core across the site) plus keyboard and screen-reader exploration tests in continuous integration, with AI-assisted review. This is not an independent third-party audit.</li>
          </ul>
        </section>

        <section className={styles.section} aria-labelledby="limitations">
          <h2 id="limitations">Known limitations</h2>
          <p>
            We continue to review and improve the site. Some older content and a small number of third-party or legacy examples may still present inconsistent interaction patterns or wording until we complete further remediation.
          </p>
          <p>
            We welcome feedback so we can prioritize fixes and keep the documentation experience usable for more readers.
          </p>
        </section>

        <section className={styles.section} aria-labelledby="features">
          <h2 id="features">Accessibility features</h2>
          <p>
            The site includes several features that support keyboard and screen-reader use.
          </p>
          <ul>
            <li>
              <strong>Color mode:</strong> Use the theme toggle in the header and press Enter or Space to switch between light, dark, and system color settings.
            </li>
            <li>
              <strong>Sidebar collapse:</strong> Use the sidebar toggle in the documentation navigation and press Enter or Space to collapse or expand the panel when it receives focus.
            </li>
            <li>
              <strong>Table of contents controls:</strong> On documentation pages, move to the table-of-contents toggle and press Enter or Space to show or hide the list when it is focused.
            </li>
          </ul>
        </section>

        <section className={styles.section} aria-labelledby="feedback-and-vpat">
          <h2 id="feedback-and-vpat">Feedback and conformance documentation</h2>
          <p>
            If you encounter an accessibility issue, please use the feedback link in the site footer or contact us through the GitHub issue form.
          </p>
          <ul>
            <li>
              <Link to="/accessibility/vpat/">View the VPAT 2.x accessibility conformance report</Link>
            </li>
            <li>
              <a href="https://github.com/microsoft/hve-core/issues/new?labels=accessibility">
                Report an accessibility issue
              </a>
            </li>
          </ul>
        </section>
      </main>
    </Layout>
  );
}
