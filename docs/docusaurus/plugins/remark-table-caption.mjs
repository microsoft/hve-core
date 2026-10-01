// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// @ts-check
// remark-directive transform for the `:::table{caption="…"}` container directive.
// Passes the caption text and optional row-header flag to the rendered <table>
// via hProperties data attributes so they survive the mdast -> hast handoff,
// where rehype-table-scope emits the real <caption> element (WAI H39) and
// applies scope="row" to first-column cells when requested.
import { visit } from 'unist-util-visit';

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : undefined;
}

function normalizeBoolean(value) {
  if (value === true || value === 'true' || value === '1' || value === 1) {
    return true;
  }

  if (value === false || value === 'false' || value === '0' || value === 0) {
    return false;
  }

  return undefined;
}

export default function remarkTableCaption() {
  return (tree) => {
    visit(tree, (node, index, parent) => {
      if (!parent || typeof index !== 'number') {
        return;
      }

      if (node.type !== 'containerDirective' || node.name !== 'table') {
        return;
      }

      const tableChild = node.children?.find((child) => child.type === 'table');
      if (!tableChild) {
        return;
      }

      const attributes = node.attributes ?? {};
      const captionText = normalizeText(attributes.caption);
      const rowheader = normalizeBoolean(attributes.rowheader);

      tableChild.data ??= {};
      tableChild.data.hProperties ??= {};
      if (captionText) {
        tableChild.data.hProperties['data-caption'] = captionText;
      }
      if (rowheader === true) {
        tableChild.data.hProperties['data-rowheader'] = 'true';
      }

      // Unwrap the directive: replace it with the bare table so the table
      // renders normally (no leftover container div around it).
      parent.children[index] = tableChild;
    });
  };
}
