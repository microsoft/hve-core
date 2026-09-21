// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// This file is based on the upstream Docusaurus 3.10.1 component
// @docusaurus/theme-classic/lib/theme/DocSidebarItem/Category/index.js.
import React, {useEffect} from 'react';
import clsx from 'clsx';
import {
  ThemeClassNames,
  useThemeConfig,
  usePrevious,
  Collapsible,
  useCollapsible,
} from '@docusaurus/theme-common';
import {isSamePath} from '@docusaurus/theme-common/internal';
import {
  isActiveSidebarItem,
  useDocSidebarItemsExpandedState,
  useVisibleSidebarItems,
} from '@docusaurus/plugin-content-docs/client';

import {translate} from '@docusaurus/Translate';
import DocSidebarItems from '@theme/DocSidebarItems';
import DocSidebarItemLink from '@theme/DocSidebarItem/Link';

function useAutoExpandActiveCategory({
  isActive,
  collapsed,
  updateCollapsed,
  activePath,
}) {
  const wasActive = usePrevious(isActive);
  const previousActivePath = usePrevious(activePath);
  useEffect(() => {
    const justBecameActive = isActive && !wasActive;
    const stillActiveButPathChanged =
      isActive && wasActive && activePath !== previousActivePath;
    if ((justBecameActive || stillActiveButPathChanged) && collapsed) {
      updateCollapsed(false);
    }
  }, [
    isActive,
    wasActive,
    collapsed,
    updateCollapsed,
    activePath,
    previousActivePath,
  ]);
}

function CategoryLinkLabel({label}) {
  return <span title={label}>{label}</span>;
}

export default function DocSidebarItemCategory(props) {
  const visibleChildren = useVisibleSidebarItems(props.item.items, props.activePath);
  if (visibleChildren.length === 0) {
    return <DocSidebarItemCategoryEmpty {...props} />;
  }
  return <DocSidebarItemCategoryCollapsible {...props} />;
}

function isCategoryWithHref(category) {
  return typeof category.href === 'string';
}

function DocSidebarItemCategoryEmpty({item, ...props}) {
  if (!isCategoryWithHref(item)) {
    return null;
  }
  const {type, collapsed, collapsible, items, linkUnlisted, ...forwardableProps} = item;
  const linkItem = {
    type: 'link',
    ...forwardableProps,
  };
  return <DocSidebarItemLink item={linkItem} {...props} />;
}

function DocSidebarItemCategoryCollapsible({
  item,
  onItemClick,
  activePath,
  level,
  index,
  ...props
}) {
  const {items, label, collapsible, className, href} = item;
  const {
    docs: {
      sidebar: {autoCollapseCategories},
    },
  } = useThemeConfig();
  const isActive = isActiveSidebarItem(item, activePath);
  const isCurrentPage = isSamePath(href, activePath);
  const {collapsed, setCollapsed} = useCollapsible({
    initialState: () => {
      if (!collapsible) {
        return false;
      }
      return isActive ? false : item.collapsed;
    },
  });
  const {expandedItem, setExpandedItem} = useDocSidebarItemsExpandedState();
  const updateCollapsed = (toCollapsed = !collapsed) => {
    setExpandedItem(toCollapsed ? null : index);
    setCollapsed(toCollapsed);
  };

  useAutoExpandActiveCategory({
    isActive,
    collapsed,
    updateCollapsed,
    activePath,
  });

  useEffect(() => {
    if (
      collapsible &&
      expandedItem != null &&
      expandedItem !== index &&
      autoCollapseCategories
    ) {
      setCollapsed(true);
    }
  }, [collapsible, expandedItem, index, setCollapsed, autoCollapseCategories]);

  // The toggle deliberately does not call `onItemClick`. In the mobile sidebar
  // that callback closes the drawer, and upstream relies on the category header
  // navigating to justify closing it. This control only discloses, so closing
  // the drawer would discard the user's place for no navigation. Child document
  // links still call the callback and still close the drawer when they navigate.
  const handleToggleClick = () => {
    updateCollapsed();
  };

  // The name states the action rather than the destination, because the control
  // performs exactly one action and never navigates. It always contains the
  // category label so a screen-reader user can distinguish sibling toggles.
  const toggleAriaLabel =
    !collapsed
      ? translate(
          {
            id: 'theme.DocSidebarItem.collapseCategoryAriaLabel',
            message: "Collapse sidebar category '{label}'",
            description: 'The ARIA label to collapse the sidebar category',
          },
          {label},
        )
      : translate(
          {
            id: 'theme.DocSidebarItem.expandCategoryAriaLabel',
            message: "Expand sidebar category '{label}'",
            description: 'The ARIA label to expand the sidebar category',
          },
          {label},
        );

  return (
    <li
      className={clsx(
        ThemeClassNames.docs.docSidebarItemCategory,
        ThemeClassNames.docs.docSidebarItemCategoryLevel(level),
        'menu__list-item',
        {
          'menu__list-item--collapsed': collapsed,
        },
        className,
      )}>
      <div
        className={clsx('menu__list-item-collapsible', {
          'menu__list-item-collapsible--active': isCurrentPage,
        })}>
        {/*
          A native button, not a link with a button role: it gives Enter and
          Space activation, focusability, and button semantics without any
          JavaScript. `aria-expanded` is the required disclosure state.

          `aria-controls` is deliberately absent. The collapsible target below
          uses `Collapsible lazy`, which renders nothing until the group is
          first opened, so an initially collapsed category has no element to
          reference. Pointing at a missing id is worse than omitting the
          optional attribute, and the simple disclosure pattern does not
          require it.

          The category landing page is not lost: it is rendered as this
          category's first child link.
        */}
        <button
          type="button"
          className={clsx('clean-btn', 'menu__link', {
            'menu__link--sublist': collapsible,
            'menu__link--sublist-caret': collapsible,
            'menu__link--active': isActive,
          })}
          onClick={handleToggleClick}
          aria-expanded={collapsible ? !collapsed : undefined}
          aria-label={toggleAriaLabel}
          {...props}>
          <CategoryLinkLabel label={label} />
        </button>
      </div>
      <Collapsible lazy as="ul" className="menu__list" collapsed={collapsed}>
        <DocSidebarItems
          items={items}
          tabIndex={collapsed ? -1 : 0}
          onItemClick={onItemClick}
          activePath={activePath}
          level={level + 1}
        />
      </Collapsible>
    </li>
  );
}
