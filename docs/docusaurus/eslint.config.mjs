// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import jsxA11yX from 'eslint-plugin-jsx-a11y-x';
import tsParser from '@typescript-eslint/parser';

export default [
  {
    ignores: ['build/**', '.docusaurus/**', 'coverage/**', 'static/**'],
  },
  {
    files: ['src/**/*.{ts,tsx,js,jsx}'],
    ...jsxA11yX.configs.recommended,
    languageOptions: {
      ...jsxA11yX.configs.recommended.languageOptions,
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      ...jsxA11yX.configs.recommended.rules,
      // Pin high-signal accessibility rules at error so they keep blocking CI
      // (lint:a11y) even if the recommended preset relaxes them.
      'jsx-a11y-x/anchor-is-valid': 'error',
      'jsx-a11y-x/interactive-supports-focus': 'error',
      'jsx-a11y-x/no-noninteractive-tabindex': 'error',
      'jsx-a11y-x/label-has-associated-control': 'error',
      'jsx-a11y-x/heading-has-content': 'error',
    },
  },
  {
    files: ['e2e/**/*.{ts,tsx}', '*.config.{ts,js,mjs}', 'sidebars.js'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
  },
];
