// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// This file is based on the upstream Docusaurus 3.10.1 component
// @docusaurus/theme-classic/lib/theme/DocSidebarItem/Category/index.js.
import React, {useEffect, useMemo, useRef} from 'react';
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
  findFirstSidebarItemLink,
  useDocSidebarItemsExpandedState,
  useVisibleSidebarItems,
} from '@docusaurus/plugin-content-docs/client';
import {useLocation} from '@docusaurus/router';
import Link from '@docusaurus/Link';
import {translate} from '@docusaurus/Translate';
import useIsBrowser from '@docusaurus/useIsBrowser';
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

function useCategoryHrefWithSSRFallback(item) {
  const isBrowser = useIsBrowser();
  return useMemo(() => {
    if (item.href && !item.linkUnlisted) {
      return item.href;
    }
    if (isBrowser || !item.collapsible) {
      return undefined;
    }
    return findFirstSidebarItemLink(item);
  }, [item, isBrowser]);
}

function focusMainContent() {
  const main = document.querySelector('main:first-of-type');
  if (main instanceof HTMLElement) {
    main.setAttribute('tabindex', '-1');
    main.focus();
  }
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
  const hrefWithSSRFallback = useCategoryHrefWithSSRFallback(item);
  const isActive = isActiveSidebarItem(item, activePath);
  const isCurrentPage = isSamePath(href, activePath);
  const location = useLocation();
  const treeItemRef = useRef(null);
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

  useEffect(() => {
    if (location.pathname && treeItemRef.current) {
      const previousPathRef = treeItemRef.current.__previousPath;
      if (previousPathRef && previousPathRef !== location.pathname) {
        focusMainContent();
      }
      treeItemRef.current.__previousPath = location.pathname;
    }
  }, [location.pathname]);

  const handleItemClick = (event) => {
    onItemClick?.(item);
    if (collapsible) {
      if (href) {
        if (isCurrentPage) {
          event.preventDefault();
          updateCollapsed();
        } else {
          updateCollapsed(false);
        }
      } else {
        event.preventDefault();
        updateCollapsed();
      }
    }
  };

  const linkAriaLabel =
    collapsible && !collapsed
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
      ref={treeItemRef}
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
        <Link
          className={clsx('menu__link', {
            'menu__link--sublist': collapsible,
            'menu__link--sublist-caret': !href && collapsible,
            'menu__link--active': isActive,
          })}
          onClick={handleItemClick}
          aria-current={isCurrentPage ? 'page' : undefined}
          aria-expanded={collapsible ? !collapsed : undefined}
          aria-label={linkAriaLabel}
          href={collapsible ? hrefWithSSRFallback ?? '#' : hrefWithSSRFallback}
          {...props}>
          <CategoryLinkLabel label={label} />
        </Link>
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
