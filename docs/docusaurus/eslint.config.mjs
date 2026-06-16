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
