// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import clsx from 'clsx';
import {useThemeConfig, ThemeClassNames, isMultiColumnFooterLinks} from '@docusaurus/theme-common';
import LinkItem from '@theme-original/Footer/LinkItem';
import FooterLogo from '@theme-original/Footer/Logo';
import FooterCopyright from '@theme-original/Footer/Copyright';
import FooterLayout from '@theme-original/Footer/Layout';

// Derived from @docusaurus/theme-classic/lib/theme/Footer/index.js and
// @docusaurus/theme-classic/lib/theme/Footer/Links/MultiColumn/index.js,
// copyright Facebook, Inc. and affiliates, licensed under the MIT license.
function FooterLinks({links}) {
  if (!links || links.length === 0) {
    return null;
  }

  if (isMultiColumnFooterLinks(links)) {
    return (
      <div className="row footer__links">
        {links.map((column, index) => (
          <div
            key={index}
            className={clsx(
              ThemeClassNames.layout.footer.column,
              'col footer__col',
              column.className,
            )}>
            <h3 className="footer__title">{column.title}</h3>
            <ul className="footer__items clean-list">
              {column.items.map((item, itemIndex) => (
                <li key={itemIndex} className="footer__item">
                  {item.html ? (
                    <div dangerouslySetInnerHTML={{__html: item.html}} />
                  ) : (
                    <LinkItem item={item} />
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="footer__links">
      <ul className="footer__items clean-list">
        {links.map((item, index) => (
          <li key={index} className="footer__item">
            <LinkItem item={item} />
          </li>
        ))}
      </ul>
    </div>
  );
}

export default function FooterWrapper() {
  const {footer} = useThemeConfig();
  if (!footer) {
    return null;
  }

  // Visually-hidden heading for the footer landmark. The footer column titles
  // are <h3>, so without a preceding <h2> the document outline jumps (e.g.
  // h1 -> h3 on sparse pages such as 404). This <h2> keeps the heading order
  // coherent site-wide (WCAG 1.3.1 / axe heading-order).
  const srOnlyStyle = {
    position: 'absolute',
    width: '1px',
    height: '1px',
    padding: 0,
    margin: '-1px',
    overflow: 'hidden',
    clip: 'rect(0, 0, 0, 0)',
    whiteSpace: 'nowrap',
    border: 0,
  };

  const {copyright, links, logo, style} = footer;
  return (
    <FooterLayout
      style={style}
      links={
        links &&
        links.length > 0 && (
          <>
            <h2 style={srOnlyStyle}>Site footer</h2>
            <FooterLinks links={links} />
          </>
        )
      }
      logo={logo && <FooterLogo logo={logo} />}
      copyright={copyright && <FooterCopyright copyright={copyright} />}
    />
  );
}
