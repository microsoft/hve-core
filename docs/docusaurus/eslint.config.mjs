import jsxA11y from 'eslint-plugin-jsx-a11y';
import tsParser from '@typescript-eslint/parser';

export default [
  {
    ignores: ['build/**', '.docusaurus/**', 'coverage/**', 'static/**'],
  },
  {
    files: ['src/**/*.{ts,tsx,js,jsx}'],
    ...jsxA11y.flatConfigs.recommended,
    languageOptions: {
      ...jsxA11y.flatConfigs.recommended.languageOptions,
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      ...jsxA11y.flatConfigs.recommended.rules,
      // Promote high-signal accessibility rules from warning to error so they
      // block CI (lint:a11y) rather than passing silently.
      'jsx-a11y/anchor-is-valid': 'error',
      'jsx-a11y/interactive-supports-focus': 'error',
      'jsx-a11y/no-noninteractive-tabindex': 'error',
      'jsx-a11y/label-has-associated-control': 'error',
      'jsx-a11y/heading-has-content': 'error',
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
