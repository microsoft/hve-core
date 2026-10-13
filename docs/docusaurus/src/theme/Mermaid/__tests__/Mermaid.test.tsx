// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { type ReactNode } from 'react';
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';

import Mermaid from '../index';

let mockColorMode: 'light' | 'dark' = 'light';
const mockInitialize = jest.fn();
const mockRender = jest.fn();
const mockThemeConfig = {
  mermaid: {
    options: { securityLevel: 'strict' },
    theme: { light: 'neutral', dark: 'dark' },
  },
};


jest.mock('@docusaurus/ErrorBoundary', () => {
  const ReactModule = jest.requireActual<typeof import('react')>('react');

  return {
    __esModule: true,
    default: class MockErrorBoundary extends ReactModule.Component<
      { children: ReactNode; fallback: (params: { error: Error; tryAgain: () => void }) => ReactNode },
      { error: Error | null; retryKey: number }
    > {
      state = { error: null, retryKey: 0 };

      static getDerivedStateFromError(error: Error) {
        return { error };
      }

      private tryAgain = () => {
        this.setState(({ retryKey }) => ({ error: null, retryKey: retryKey + 1 }));
      };

      render() {
        if (this.state.error) {
          return this.props.fallback({ error: this.state.error, tryAgain: this.tryAgain });
        }

        return ReactModule.createElement(
          ReactModule.Fragment,
          { key: this.state.retryKey },
          this.props.children,
        );
      }
    },
  };
}, { virtual: true });

jest.mock('@docusaurus/theme-common', () => ({
  ErrorBoundaryErrorMessageFallback: ({ error, tryAgain }: { error: Error; tryAgain: () => void }) => (
    <div>
      <p>{error.message}</p>
      <button type="button" onClick={tryAgain}>Try again</button>
    </div>
  ),
  useColorMode: () => ({ colorMode: mockColorMode }),
  useThemeConfig: () => mockThemeConfig,
}));

jest.mock('@docusaurus/theme-mermaid/client', () => ({
  MermaidContainerClassName: 'theme-mermaid',
}));

jest.mock('mermaid', () => ({
  __esModule: true,
  default: {
    initialize: (...args: unknown[]) => mockInitialize(...args),
    render: (...args: unknown[]) => mockRender(...args),
  },
}));

interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void;
  reject: (reason: Error) => void;
}

function deferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void;
  let reject!: (reason: Error) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, reject, resolve };
}

function renderResult(name: string, bindFunctions = jest.fn()) {
  return {
    bindFunctions,
    diagramType: 'flowchart-v2',
    svg: `<svg role="graphics-document" aria-label="${name}" data-render="${name}"></svg>`,
  };
}

beforeEach(() => {
  mockColorMode = 'light';
  mockInitialize.mockClear();
  mockRender.mockReset();
});

test('retains the settled SVG until the active theme replacement succeeds', async () => {
  const firstBind = jest.fn();
  const secondBind = jest.fn();
  const replacement = deferred<ReturnType<typeof renderResult>>();
  mockRender
    .mockResolvedValueOnce(renderResult('light', firstBind))
    .mockReturnValueOnce(replacement.promise);

  const view = render(<Mermaid value="flowchart LR; A --> B" />);
  expect(view.container.querySelector('svg')).toBeNull();
  await waitFor(() => expect(view.container.querySelector('[data-render="light"]')).toBeInTheDocument());
  await waitFor(() => expect(firstBind).toHaveBeenCalledWith(view.container.querySelector('.theme-mermaid')));

  mockColorMode = 'dark';
  view.rerender(<Mermaid value="flowchart LR; A --> B" />);
  await waitFor(() => expect(mockRender).toHaveBeenCalledTimes(2));

  const retainedSettledSvg = view.container.querySelector('[data-render="light"]') !== null;
  const pendingSvgCount = view.container.querySelectorAll('svg').length;

  await act(async () => replacement.resolve(renderResult('dark', secondBind)));
  await waitFor(() => expect(view.container.querySelector('[data-render="dark"]')).toBeInTheDocument());
  expect(view.container.querySelector('[data-render="light"]')).toBeNull();
  expect(retainedSettledSvg).toBe(true);
  expect(pendingSvgCount).toBe(1);
  await waitFor(() => expect(secondBind).toHaveBeenCalledWith(view.container.querySelector('.theme-mermaid')));
});

test('recovers through the error boundary after an initial rejection', async () => {
  const recovered = renderResult('recovered');
  mockRender
    .mockRejectedValueOnce(new Error('render failed'))
    .mockResolvedValueOnce(recovered);
  const consoleError = jest.spyOn(console, 'error').mockImplementation(() => undefined);
  const focusGraphic = jest.spyOn(SVGElement.prototype, 'focus');

  try {
    const view = render(<Mermaid value="flowchart LR; A --> B" />);
    expect(await screen.findByText('render failed')).toBeInTheDocument();
    expect(screen.getByRole('alert')).toHaveTextContent('render failed');

    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));

    await waitFor(() => {
      const graphic = view.container.querySelector('[data-render="recovered"]');
      expect(graphic).toBeInTheDocument();
      expect(graphic).toHaveAttribute('tabindex', '-1');
      expect(focusGraphic).toHaveBeenCalledTimes(1);
    });
    expect(mockRender).toHaveBeenCalledTimes(2);
  } finally {
    focusGraphic.mockRestore();
    consoleError.mockRestore();
  }
});

test('focuses the retry button when the retry also rejects', async () => {
  mockRender
    .mockRejectedValueOnce(new Error('initial render failed'))
    .mockRejectedValueOnce(new Error('retry render failed'));
  const consoleError = jest.spyOn(console, 'error').mockImplementation(() => undefined);
  const focusRetry = jest.spyOn(HTMLButtonElement.prototype, 'focus');

  try {
    render(<Mermaid value="flowchart LR; A --> B" />);
    expect(await screen.findByText('initial render failed')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent('retry render failed');
      expect(screen.getByRole('button', { name: 'Try again' })).toHaveFocus();
      expect(focusRetry).toHaveBeenCalledTimes(1);
    });
    expect(mockRender).toHaveBeenCalledTimes(2);
  } finally {
    focusRetry.mockRestore();
    consoleError.mockRestore();
  }
});

test('suppresses stale completions after a value change', async () => {
  const stale = deferred<ReturnType<typeof renderResult>>();
  const current = deferred<ReturnType<typeof renderResult>>();
  mockRender
    .mockReturnValueOnce(stale.promise)
    .mockReturnValueOnce(current.promise);

  const view = render(<Mermaid value="flowchart LR; A --> B" />);
  await waitFor(() => expect(mockRender).toHaveBeenCalledTimes(1));
  view.rerender(<Mermaid value="flowchart LR; A --> C" />);

  await act(async () => stale.resolve(renderResult('stale')));
  await waitFor(() => expect(mockRender).toHaveBeenCalledTimes(2));
  expect(view.container.querySelector('svg')).toBeNull();

  await act(async () => current.resolve(renderResult('current')));
  await waitFor(() => expect(view.container.querySelector('[data-render="current"]')).toBeInTheDocument());
  expect(view.container.querySelector('[data-render="stale"]')).toBeNull();
});

test('suppresses a completion after unmount', async () => {
  const pending = deferred<ReturnType<typeof renderResult>>();
  mockRender.mockReturnValueOnce(pending.promise);
  const consoleError = jest.spyOn(console, 'error').mockImplementation(() => undefined);

  try {
    const view = render(<Mermaid value="flowchart LR; A --> B" />);
    await waitFor(() => expect(mockRender).toHaveBeenCalledTimes(1));
    view.unmount();

    await act(async () => pending.resolve(renderResult('unmounted')));
    expect(view.container.querySelector('svg')).toBeNull();
    expect(consoleError).not.toHaveBeenCalled();
  } finally {
    consoleError.mockRestore();
  }
});
