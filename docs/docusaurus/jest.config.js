/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'jsdom',
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
    '^@theme/(.*)$': '<rootDir>/src/__mocks__/@theme/$1',
  },
  testPathIgnorePatterns: ['/node_modules/', '/build/'],
};
