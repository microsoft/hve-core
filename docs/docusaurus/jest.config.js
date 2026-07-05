// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: '@happy-dom/jest-environment',
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: {
        jsx: 'react-jsx',
        esModuleInterop: true,
        types: ['jest', '@testing-library/jest-dom'],
      },
      diagnostics: false,
    }],
  },
  moduleNameMapper: {
    '\\.module\\.css$': 'identity-obj-proxy',
    '\\.css$': 'identity-obj-proxy',
    '\\.svg$': '<rootDir>/src/__mocks__/svgMock.js',
    '^@docusaurus/Link$': '<rootDir>/src/__mocks__/@docusaurus/Link',
    '^@docusaurus/useBaseUrl$': '<rootDir>/src/__mocks__/@docusaurus/useBaseUrl',
    '^@docusaurus/useDocusaurusContext$': '<rootDir>/src/__mocks__/@docusaurus/useDocusaurusContext',
    '^@theme/(.*)$': '<rootDir>/src/__mocks__/@theme/$1',
  },
  testPathIgnorePatterns: ['/node_modules/', '/build/', '/e2e/'],
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/__mocks__/**',
    '!src/**/__tests__/**',
    '!src/**/*.test.{ts,tsx}',
    // Static content pages (no logic); rendering is validated by the e2e suite.
    '!src/pages/accessibility.tsx',
    '!src/pages/accessibility/vpat.tsx',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['lcov', 'text-summary'],
  coverageThreshold: {
    global: {
      statements: 55,
      branches: 65,
      functions: 55,
      lines: 60,
    },
  },
};
