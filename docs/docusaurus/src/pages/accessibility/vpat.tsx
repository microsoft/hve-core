// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import styles from '../accessibility.module.css';

export default function VpatPage(): React.ReactElement {
  return (
    <Layout
      title="VPAT 2.x accessibility conformance report"
      description="Accessibility conformance report for the HVE Core documentation site"
    >
      <main id="main-content" className={styles.main}>
        <header className={styles.hero}>
          <p className={styles.eyebrow}>Accessibility</p>
          <h1>VPAT 2.x accessibility conformance report</h1>
          <p className={styles.summary}>
            This report summarizes the current conformance posture for the HVE Core documentation site and related public content.
          </p>
          <p className={styles.reviewNote}>
            This VPAT is a self-assessment authored with AI assistance and informed by configured automated accessibility testing. It has not been independently audited; we welcome corrections and support in improving our accessibility standards.
          </p>
        </header>

        <section className={styles.section} aria-labelledby="report-info">
          <h2 id="report-info">Report information</h2>
          <ul>
            <li><strong>Product name:</strong> HVE Core documentation site and related public content</li>
            <li><strong>Conformance target:</strong> WCAG 2.2 Level AA</li>
            <li><strong>Assessment currency:</strong> A date is published only with a current validation projection that identifies the tested revision, scope, methods, and limitations</li>
            <li><strong>Assessment method:</strong> Automated accessibility testing (axe-core across the site), deterministic keyboard and accessibility-tree tests in continuous integration, and advisory local NVDA sampling with AI-assisted review. This is not an independent third-party audit.</li>
            <li><strong>Reporting format:</strong> VPAT 2.x (ACR)</li>
            <li><strong>Status:</strong> Self-assessment; not independently audited</li>
          </ul>
        </section>

        <section className={styles.section} aria-labelledby="standards-scope">
          <h2 id="standards-scope">Standards and scope</h2>
          <p>
            This report covers the public HVE Core documentation experience available at the documentation site and the related public content linked from the site.
            The scope includes core navigation, content pages, search interactions, and footer resources.
          </p>
        </section>

        <section className={styles.section} aria-labelledby="conformance-summary">
          <h2 id="conformance-summary">Conformance summary</h2>
          <table>
            <thead>
              <tr>
                <th scope="col">Standard</th>
                <th scope="col">Level</th>
                <th scope="col">Status</th>
                <th scope="col">Notes</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>WCAG 2.2 A</td>
                <td>A</td>
                <td>Partially Supports</td>
                <td>The site is configured to run automated WCAG 2.x checks across the declared inventory on every release. Automated tooling does not cover every success criterion, and a full manual audit is still pending, so this is not a completed conformance result.</td>
              </tr>
              <tr>
                <td>WCAG 2.2 AA</td>
                <td>AA</td>
                <td>Partially Supports</td>
                <td>Target is WCAG 2.2 Level AA. The site is configured for site-wide automated checks; because automated tooling does not cover every success criterion and manual review is incomplete, this is not a completed conformance result.</td>
              </tr>
            </tbody>
          </table>
        </section>

        <section className={styles.section} aria-labelledby="limitations">
          <h2 id="limitations">Known limitations</h2>
          <p>
            The site continues to improve its accessibility posture. Some legacy examples, third-party content, or older documentation patterns may still present inconsistent interaction patterns or wording until additional remediation is completed.
          </p>
          <p>
            This report is a self-assessment and is not an attestation, certification, or independent audit. It does not constitute a warranty of conformance.
          </p>
          <p>
            Manual and assistive-technology review is incomplete. Screen-reader results come from an advisory sample of representative journeys on a prepared host, not from exhaustive coverage of the site, and advisory sampling is never promoted to a conformance outcome on its own.
          </p>
          <p>
            Statuses in this report describe the capabilities the site is built and configured for, bound to the scope and methods named above. They are not a claim that every criterion has been verified on the current revision, and they are not bound to an assessment date unless a current validation projection publishing that date accompanies them.
          </p>
        </section>

        <section className={styles.section} aria-labelledby="features">
          <h2 id="features">Accessibility features</h2>
          <ul>
            <li>Keyboard-friendly navigation and focus visibility</li>
            <li>Theme controls that support light, dark, and system color settings</li>
            <li>Collapsible sidebar and table-of-contents controls that can be activated by keyboard</li>
            <li>Link and heading structure that supports screen-reader navigation</li>
          </ul>
        </section>

        <section className={styles.section} aria-labelledby="feedback">
          <h2 id="feedback">Feedback and remediation path</h2>
          <p>
            If you experience an accessibility issue, use the feedback link in the site footer or submit a GitHub issue with the accessibility label.
          </p>
          <ul>
            <li>
              <Link to="/accessibility/">View the accessibility statement</Link>
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
