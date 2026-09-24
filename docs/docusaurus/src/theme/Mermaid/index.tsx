// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import ErrorBoundary from '@docusaurus/ErrorBoundary';
import { ErrorBoundaryErrorMessageFallback, useColorMode, useThemeConfig } from '@docusaurus/theme-common';
import { MermaidContainerClassName } from '@docusaurus/theme-mermaid/client';
import type { ThemeConfig } from '@docusaurus/theme-mermaid';
import type { Props } from '@theme/Mermaid';
import type { MermaidConfig, RenderResult } from 'mermaid';

import styles from './styles.module.css';

let renderQueue: Promise<void> = Promise.resolve();
let mermaidPromise: Promise<typeof import('mermaid')['default']> | undefined;

function loadMermaid(): Promise<typeof import('mermaid')['default']> {
  mermaidPromise ??= import('mermaid').then((module) => module.default);
  return mermaidPromise;
}

function enqueueRender(id: string, text: string, config: MermaidConfig): Promise<RenderResult> {
  const render = renderQueue.then(async () => {
    const mermaid = await loadMermaid();
    mermaid.initialize(config);

    try {
      return await mermaid.render(id, text);
    } catch (error) {
      document.querySelector(`#d${id}`)?.remove();
      throw error;
    }
  });

  renderQueue = render.then(() => undefined, () => undefined);
  return render;
}

function MermaidRenderer({ value, retryPending }: Props & { retryPending: { current: boolean } }): ReactNode {
  const [id] = useState(() => `mermaid-svg-${Math.round(Math.random() * 10000000)}`);
  const [result, setResult] = useState<RenderResult | null>(null);
  const [error, setError] = useState<unknown>(null);
  const renderGeneration = useRef(0);
  const { colorMode } = useColorMode();
  const mermaidConfig = (useThemeConfig() as unknown as ThemeConfig).mermaid;
  const config = useMemo<MermaidConfig>(
    () => ({ startOnLoad: false, ...mermaidConfig.options, theme: mermaidConfig.theme[colorMode] }),
    [colorMode, mermaidConfig.options, mermaidConfig.theme],
  );

  useEffect(() => {
    let active = true;
    setError(null);

    renderGeneration.current += 1;
    enqueueRender(id + '-' + renderGeneration.current, value, config).then(
      (renderResult) => {
        if (active) {
          setResult(renderResult);
        }
      },
      (renderError: unknown) => {
        if (active) {
          setError(renderError);
        }
      },
    );

    return () => {
      active = false;
    };
  }, [config, id, value]);

  if (error) {
    throw error;
  }
  if (!result) {
    return null;
  }

  return <MermaidRenderResult result={result} retryPending={retryPending} />;
}

function MermaidRenderResult({
  result,
  retryPending,
}: {
  result: RenderResult;
  retryPending: { current: boolean };
}): ReactNode {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    result.bindFunctions?.(containerRef.current!);
    if (retryPending.current) {
      retryPending.current = false;
      const graphic = containerRef.current?.querySelector<SVGElement>('svg[role~="graphics-document"]');
      graphic?.setAttribute('tabindex', '-1');
      graphic?.focus();
    }
  }, [result, retryPending]);

  return (
    <div
      ref={containerRef}
      className={`${MermaidContainerClassName} ${styles.container}`}
      dangerouslySetInnerHTML={{ __html: result.svg }}
    />
  );
}

function MermaidErrorFallback({
  error,
  tryAgain,
  retryPending,
}: {
  error: Error;
  tryAgain: () => void;
  retryPending: { current: boolean };
}): ReactNode {
  const containerRef = useRef<HTMLDivElement>(null);
  const shouldFocusRetry = retryPending.current;

  useEffect(() => {
    if (shouldFocusRetry) {
      retryPending.current = false;
      containerRef.current?.querySelector<HTMLButtonElement>('button')?.focus();
    }
  }, [retryPending, shouldFocusRetry]);

  return (
    <div ref={containerRef} role="alert" aria-atomic="true">
      <ErrorBoundaryErrorMessageFallback
        error={error}
        tryAgain={() => {
          retryPending.current = true;
          tryAgain();
        }}
      />
    </div>
  );
}

export default function Mermaid(props: Props): ReactNode {
  const retryPending = useRef(false);

  return (
    <ErrorBoundary fallback={(params) => (
      <MermaidErrorFallback {...params} retryPending={retryPending} />
    )}>
      <MermaidRenderer {...props} retryPending={retryPending} />
    </ErrorBoundary>
  );
}