// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useEffect, useState } from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

type LevelName = 'L100' | 'L200' | 'L300' | 'L400';

type PublishedFiles = {
  page: string;
  html: string;
  pptx: string;
  mp4: string;
  vtt: string;
};

type LevelEntry = {
  files?: Record<string, unknown>;
  last_failed_attempt?: {
    checks?: Record<string, { result?: string }>;
  };
};

type SiteIndex = {
  schema_version?: string;
  levels?: Partial<Record<LevelName, LevelEntry>>;
};

const levels: Array<{
  name: LevelName;
  audience: string;
  duration: string;
}> = [
  {
    name: 'L100',
    audience: 'New contributors and first-time HVE Core users',
    duration: '4 to 6 min',
  },
  {
    name: 'L200',
    audience: 'Contributors ready to follow a guided task',
    duration: '6 to 8 min',
  },
  {
    name: 'L300',
    audience: 'Engineers choosing an applied workflow',
    duration: '8 to 10 min',
  },
  {
    name: 'L400',
    audience: 'Maintainers and contributors extending HVE Core',
    duration: '10 to 12 min',
  },
];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isSiteIndex(value: unknown): value is SiteIndex {
  if (!isRecord(value) || value.schema_version !== 'demo-material-site/v1' ||
      !isRecord(value.levels)) {
    return false;
  }
  return Object.values(value.levels).every((entry) => {
    if (!isRecord(entry) || (entry.files !== undefined && !isRecord(entry.files))) {
      return false;
    }
    if (entry.last_failed_attempt === undefined) {
      return true;
    }
    if (!isRecord(entry.last_failed_attempt)) {
      return false;
    }
    const checks = entry.last_failed_attempt.checks;
    return checks === undefined || (isRecord(checks) && Object.values(checks).every(
      (check) => isRecord(check) &&
        (check.result === undefined || typeof check.result === 'string'),
    ));
  });
}

function publishedFiles(level: LevelName, entry?: LevelEntry): PublishedFiles | null {
  const expected: PublishedFiles = {
    page: `${level}/index.html`,
    html: `${level}/hve-demo-${level}.html`,
    pptx: `${level}/hve-demo-${level}.pptx`,
    mp4: `${level}/hve-demo-${level}.mp4`,
    vtt: `${level}/hve-demo-${level}.vtt`,
  };
  if (!entry?.files) {
    return null;
  }
  return Object.entries(expected).every(([key, path]) => entry.files?.[key] === path)
    ? expected
    : null;
}

function unavailableReason(entry?: LevelEntry): string {
  const failed = Object.entries(entry?.last_failed_attempt?.checks ?? {}).find(
    ([, check]) => check.result === 'fail',
  );
  return failed ? `Not published (${failed[0]} did not pass)` : 'Not published yet';
}

export default function DemoMaterialCatalog(): React.ReactElement {
  const indexUrl = useBaseUrl('/demo-material/index.json');
  const materialRoot = useBaseUrl('/demo-material/');
  const [index, setIndex] = useState<SiteIndex | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    fetch(indexUrl, { signal: controller.signal, headers: { Accept: 'application/json' } })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Demo material index returned ${response.status}`);
        }
        return response.json() as Promise<unknown>;
      })
      .then((value) => {
        if (!isSiteIndex(value)) {
          throw new Error('Invalid demo material index');
        }
        setIndex(value);
      })
      .catch((error: unknown) => {
        if (!(error instanceof DOMException && error.name === 'AbortError')) {
          setFailed(true);
        }
      });
    return () => controller.abort();
  }, [indexUrl]);

  return (
    <>
      <p className={styles.status} role={failed ? 'alert' : 'status'}>
        {failed
          ? 'Publication status is temporarily unavailable. Download links are hidden.'
          : index
            ? 'Showing currently published demo material.'
            : 'Checking published demo material...'}
      </p>
      <div
        className={styles.tableWrapper}
        role="group"
        aria-label="Published demo material, scrollable table"
        // eslint-disable-next-line jsx-a11y-x/no-noninteractive-tabindex
        tabIndex={0}
      >
        <table>
          <caption>HVE Core demo material publication status</caption>
          <thead>
            <tr>
              <th scope="col">Level</th>
              <th scope="col">Audience</th>
              <th scope="col">Length</th>
              <th scope="col">Published material</th>
            </tr>
          </thead>
          <tbody>
            {levels.map((level) => {
              const entry = index?.levels?.[level.name];
              const files = publishedFiles(level.name, entry);
              return (
                <tr key={level.name}>
                  <th scope="row">{level.name}</th>
                  <td>{level.audience}</td>
                  <td>{level.duration}</td>
                  <td>
                    {files ? (
                      <span className={styles.links}>
                        <a href={`${materialRoot}${files.page}`}>Watch and read transcript</a>
                        <a href={`${materialRoot}${files.html}`}>Present slides</a>
                        <a href={`${materialRoot}${files.pptx}`}>Download deck</a>
                        <a href={`${materialRoot}${files.mp4}`}>Download MP4</a>
                      </span>
                    ) : (
                      <span className={styles.unavailable}>
                        {failed || !index ? 'Status unavailable' : unavailableReason(entry)}
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}