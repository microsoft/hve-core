// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, {useId} from 'react';
import clsx from 'clsx';
import {useCollapsible, Collapsible} from '@docusaurus/theme-common';
import Translate from '@docusaurus/Translate';
import TOCItems from '@theme/TOCItems';
import styles from '@docusaurus/theme-classic/lib/theme/TOCCollapsible/styles.module.css';

// Derived from @docusaurus/theme-classic/lib/theme/TOCCollapsible/index.js,
// copyright Facebook, Inc. and affiliates, licensed under the MIT license.
export default function TOCCollapsibleWrapper({
  toc,
  className,
  minHeadingLevel,
  maxHeadingLevel,
}) {
  const {collapsed, toggleCollapsed} = useCollapsible({initialState: true});
  const tocRegionId = useId();

  return (
    <div className={clsx('table-of-contents', className)}>
      <h3 className="table-of-contents__title">In this article</h3>
      <div
        className={clsx(
          styles.tocCollapsible,
          !collapsed && styles.tocCollapsibleExpanded,
        )}>
        <button
          type="button"
          className={clsx(
            'clean-btn',
            styles.tocCollapsibleButton,
            !collapsed && styles.tocCollapsibleButtonExpanded,
          )}
          aria-controls={tocRegionId}
          aria-expanded={!collapsed}
          onClick={toggleCollapsed}>
          <Translate
            id="theme.TOCCollapsible.toggleButtonLabel"
            description="The label used by the button on the collapsible TOC component">
            On this page
          </Translate>
        </button>
        <div id={tocRegionId}>
          <Collapsible
            lazy
            className={styles.tocCollapsibleContent}
            collapsed={collapsed}>
            <TOCItems
              toc={toc}
              minHeadingLevel={minHeadingLevel}
              maxHeadingLevel={maxHeadingLevel}
            />
          </Collapsible>
        </div>
      </div>
    </div>
  );
}
