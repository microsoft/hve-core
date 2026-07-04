// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// Adapted from the Docusaurus 3.10.1 desktop navbar dropdown implementation in
// @docusaurus/theme-classic, which is licensed under the MIT license.
import React, {useEffect, useId, useRef, useState} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';

const resolveMenuItemHref = (childItemProps) => {
  if (childItemProps.to) {
    return childItemProps.to;
  }
  if (childItemProps.href) {
    return childItemProps.href;
  }
  return undefined;
};

export default function DropdownNavbarItemDesktop({
  items,
  position,
  className,
  onClick,
  children,
  label,
  ...props
}) {
  const dropdownRef = useRef(null);
  const toggleRef = useRef(null);
  const itemRefs = useRef([]);
  const menuId = useId();
  const [showDropdown, setShowDropdown] = useState(false);
  const [focusFirstItem, setFocusFirstItem] = useState(false);

  useEffect(() => {
    if (!showDropdown || !focusFirstItem) {
      return undefined;
    }

    const frameId = window.requestAnimationFrame(() => {
      const firstItem = itemRefs.current.find(Boolean);
      if (firstItem instanceof HTMLElement) {
        firstItem.focus({preventScroll: true});
      }
    });

    setFocusFirstItem(false);

    return () => {
      window.cancelAnimationFrame(frameId);
    };
  }, [showDropdown, focusFirstItem]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (!dropdownRef.current || dropdownRef.current.contains(event.target)) {
        return;
      }
      setShowDropdown(false);
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('touchstart', handleClickOutside);
    document.addEventListener('focusin', handleClickOutside);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('touchstart', handleClickOutside);
      document.removeEventListener('focusin', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    if (!showDropdown) {
      return undefined;
    }

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        setShowDropdown(false);
        toggleRef.current?.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [showDropdown]);

  const openDropdown = (reason = 'pointer') => {
    setShowDropdown(true);
    if (reason === 'keyboard' || reason === 'toggle') {
      setFocusFirstItem(true);
    }
  };

  const closeDropdown = (restoreFocus = false) => {
    setShowDropdown(false);
    if (restoreFocus) {
      window.requestAnimationFrame(() => {
        toggleRef.current?.focus();
      });
    }
  };

  const handleToggleClick = (event) => {
    event.preventDefault();
    setShowDropdown((value) => {
      const nextValue = !value;
      if (nextValue) {
        setFocusFirstItem(true);
      }
      return nextValue;
    });

    if (onClick) {
      onClick(event);
    }
  };

  const handleToggleKeyDown = (event) => {
    if (event.key === 'Enter' || event.key === ' ' || event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      openDropdown('keyboard');
    } else if (event.key === 'Escape') {
      event.preventDefault();
      closeDropdown(true);
    }
  };

  const handleMenuItemKeyDown = (event, index) => {
    const menuItems = itemRefs.current.filter(Boolean);
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      const nextIndex = (index + 1) % menuItems.length;
      menuItems[nextIndex]?.focus();
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      const previousIndex = (index - 1 + menuItems.length) % menuItems.length;
      menuItems[previousIndex]?.focus();
    } else if (event.key === 'Home') {
      event.preventDefault();
      menuItems[0]?.focus();
    } else if (event.key === 'End') {
      event.preventDefault();
      menuItems[menuItems.length - 1]?.focus();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      closeDropdown(true);
    }
  };

  return (
    <div
      ref={dropdownRef}
      className={clsx('navbar__item', 'dropdown', 'dropdown--hoverable', {
        'dropdown--right': position === 'right',
        'dropdown--show': showDropdown,
      })}
      onMouseEnter={() => openDropdown('pointer')}
      onMouseLeave={() => setShowDropdown(false)}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) {
          setShowDropdown(false);
        }
      }}>
      <button
        ref={toggleRef}
        type="button"
        className={clsx('navbar__link', className)}
        aria-haspopup="menu"
        aria-expanded={showDropdown}
        aria-controls={menuId}
        onClick={handleToggleClick}
        onKeyDown={handleToggleKeyDown}>
        {children ?? label}
      </button>
      {showDropdown ? (
        <ul
          id={menuId}
          className="dropdown__menu"
          role="menu"
          aria-label={typeof label === 'string' ? label : undefined}>
          {items.map((childItemProps, index) => {
            const childHref = resolveMenuItemHref(childItemProps);
            const childLabel = childItemProps.label ?? childItemProps.children;

            return (
              <li key={index} role="none">
                <Link
                  className="dropdown__link"
                  to={childHref}
                  href={childHref}
                  role="menuitem"
                  tabIndex="-1"
                  ref={(node) => {
                    itemRefs.current[index] = node;
                  }}
                  onClick={() => {
                    setShowDropdown(false);
                    if (childItemProps.onClick) {
                      childItemProps.onClick();
                    }
                  }}
                  onKeyDown={(event) => handleMenuItemKeyDown(event, index)}>
                  {childLabel}
                </Link>
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
}
