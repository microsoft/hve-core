// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { execFileSync } from 'node:child_process';
import { closeSync, constants, ftruncateSync, mkdirSync, openSync, readdirSync, readFileSync, writeSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '../../..');
const generatedDocsRoot = path.resolve(scriptDirectory, '../.docusaurus/docusaurus-plugin-content-docs/default');
const openingFencePattern = /^\s*(`{3,}|~{3,})(.*)$/;

function normalizePath(filePath) {
  return filePath.replaceAll('\\', '/');
}

export function isDeployedDocumentationFile(filePath) {
  const normalized = normalizePath(filePath);
  const segments = normalized.split('/');
  const basename = segments.at(-1) ?? '';

  return normalized.startsWith('docs/')
    && !normalized.startsWith('docs/docusaurus/')
    && !normalized.startsWith('docs/announcements/')
    && !segments.some((segment, index) => index > 0 && segment.startsWith('_'))
    && /\.(?:md|mdx)$/i.test(basename);
}

export function discoverDocumentationFiles() {
  const output = execFileSync('git', ['ls-files', '--', 'docs'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });

  return output
    .split(/\r?\n/)
    .filter(Boolean)
    .map(normalizePath)
    .filter(isDeployedDocumentationFile)
    .sort();
}

export function groupRouteCases(fences, documents) {
  const routeBySource = new Map(documents.map((document) => [
    document.source.replace(/^@site\/\.\.\//, 'docs/'),
    document.permalink,
  ]));
  const cases = new Map();

  for (const fence of fences) {
    const route = routeBySource.get(fence.file);
    if (!route) {
      throw new Error(`No Docusaurus permalink found for ${fence.file}`);
    }

    const routeCase = cases.get(route);
    if (routeCase) {
      routeCase.diagramCount += 1;
    } else {
      cases.set(route, {
        name: fence.file,
        path: route,
        diagramCount: 1,
      });
    }
  }

  return Array.from(cases.values());
}

export function buildGraphicsReviewTemplate(fences, documents, readSource = (file) => readFileSync(path.join(repositoryRoot, file), 'utf8')) {
  const routeBySource = new Map(documents.map((document) => [
    document.source.replace(/^@site\/\.\.\//, 'docs/'),
    document.permalink,
  ]));
  const fenceCounts = new Map();
  const rows = fences.map((fence, index) => {
    const route = routeBySource.get(fence.file);
    if (!route) {
      throw new Error(`No Docusaurus permalink found for ${fence.file}`);
    }
    const fenceIndex = (fenceCounts.get(fence.file) ?? 0) + 1;
    fenceCounts.set(fence.file, fenceIndex);
    const declaration = activeSourceLines(fence.source).find((line) => line.trim())?.trim() ?? '';
    const family = declaration === 'stateDiagram-v2'
      ? 'stateDiagram'
      : declaration.split(/\s+/, 1)[0];
    const content = readSource(fence.file);
    const precedingLines = content.split(/\r?\n/).slice(0, fence.startLine - 1).reverse();
    const heading = precedingLines
      .map((line) => line.match(/^\s*#{1,6}\s+(.+?)\s*#*\s*$/)?.[1]?.trim())
      .find(Boolean) ?? 'Document context';
    return {
      number: index + 1,
      sourcePath: fence.file,
      fenceLocator: `Mermaid fence ${fenceIndex}`,
      route,
      family,
      title: fence.title,
      description: fence.description,
      contextReference: heading,
    };
  });

  const escapeCell = (value) => String(value).replaceAll('|', '\\|').replace(/\r?\n/g, ' ');
  const tableRows = rows.map((row) => `| ${row.number} | ${escapeCell(row.sourcePath)} | ${row.fenceLocator} | ${escapeCell(row.route)} | ${row.family} | ${escapeCell(row.title)} | ${escapeCell(row.description)} | ${escapeCell(row.contextReference)} | not verified | not verified | not verified | not verified | not verified | not verified | not verified | not verified | not verified |`);

  return `<!-- markdownlint-disable-file -->
# Mermaid Graphics Review Register

## Review Boundary

This register covers all deployed Mermaid diagrams in stable source order. Source metadata and route context are generated observations. A qualified accessibility reviewer must decide equivalent purpose, context sufficiency, atomic or structured representation, reading order where applicable, and whether colour conveys meaning without another cue. The review is informed by the WAI-ARIA Graphics Module (<https://www.w3.org/TR/graphics-aria-1.0/>), SVG Accessibility API Mappings (<https://www.w3.org/TR/svg-aam-1.0/>), and the WAI Complex Images tutorial (<https://www.w3.org/WAI/tutorials/images/complex/>).

| # | Source path | Fence locator | Route | Family | Authored title | Authored description | Surrounding context | Computed role | Computed name | Computed description | Representation decision | Reading-order result | Semantic-colour result | Disposition | Rationale | Reviewer, environment, and review date |
|---|-------------|---------------|-------|--------|----------------|----------------------|---------------------|---------------|---------------|----------------------|-------------------------|----------------------|------------------------|-------------|-----------|----------------------------------------|
${tableRows.join('\n')}

## Human Review

- [ ] Reviewed and validated by a qualified accessibility reviewer
`;
}

export function writeGraphicsReviewTemplate(outputPath, content, check = false) {
  mkdirSync(path.dirname(outputPath), { recursive: true });
  let fileHandle;
  try {
    try {
      fileHandle = openSync(outputPath, check ? constants.O_RDONLY : constants.O_RDWR | constants.O_CREAT);
    } catch (error) {
      if (check && error?.code === 'ENOENT') {
        throw new Error(`Mermaid graphics review template not found: ${outputPath}`);
      }
      throw error;
    }

    const existing = readFileSync(fileHandle, 'utf8').replaceAll('\r\n', '\n');
    if (existing === content) {
      return 'NoDrift';
    }
    if (/\|\s*verified (?:pass|fail)\s*\|/i.test(existing)) {
      throw new Error(`Refusing to overwrite completed human dispositions in ${outputPath}`);
    }
    if (check) {
      throw new Error(`Mermaid graphics review template drift detected: ${outputPath}`);
    }

    ftruncateSync(fileHandle, 0);
    writeSync(fileHandle, content, 0, 'utf8');
    return 'Wrote';
  } finally {
    if (fileHandle !== undefined) {
      closeSync(fileHandle);
    }
  }
}
function discoverGeneratedDocuments() {
  return readdirSync(generatedDocsRoot)
    .filter((file) => file.startsWith('site-') && file.endsWith('.json'))
    .map((file) => JSON.parse(readFileSync(path.join(generatedDocsRoot, file), 'utf8')))
    .filter((document) => typeof document.source === 'string' && typeof document.permalink === 'string');
}

export function extractMermaidFences(content, file = '<memory>') {
  const lines = content.split(/\r?\n/);
  const fences = [];

  for (let index = 0; index < lines.length; index += 1) {
    const openingMatch = lines[index].match(openingFencePattern);
    if (!openingMatch) {
      continue;
    }

    const marker = openingMatch[1][0];
    const minimumLength = openingMatch[1].length;
    const isMermaid = /^mermaid(?:\s+.*)?$/.test(openingMatch[2].trim());
    const closingPattern = new RegExp(`^\\s*${marker}{${minimumLength},}\\s*$`);
    const startLine = index + 1;
    const sourceLines = [];
    let closed = false;

    for (index += 1; index < lines.length; index += 1) {
      if (closingPattern.test(lines[index])) {
        closed = true;
        break;
      }
      if (isMermaid) {
        sourceLines.push(lines[index]);
      }
    }

    if (isMermaid && !closed) {
      throw new Error(`${file}:${startLine}: Mermaid fence is not closed`);
    }

    if (isMermaid) {
      fences.push({
        file,
        startLine,
        source: sourceLines.join('\n'),
      });
    }
  }

  return fences;
}

function activeSourceLines(source) {
  return source.split(/\r?\n/).filter((line) => !/^\s*%%/.test(line));
}

export function validateSourceMetadata(source) {
  const lines = activeSourceLines(source);
  const titleDirectives = [];
  const descriptionDirectives = [];

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const titleMatch = line.match(/^\s*accTitle\s*:\s*(.*)$/);
    if (titleMatch) {
      titleDirectives.push(titleMatch[1].trim());
      continue;
    }

    const descriptionMatch = line.match(/^\s*accDescr\s*:\s*(.*)$/);
    if (descriptionMatch) {
      descriptionDirectives.push(descriptionMatch[1].trim());
      continue;
    }

    if (/^\s*accDescr\s*\{\s*$/.test(line)) {
      const descriptionLines = [];
      let closed = false;
      for (index += 1; index < lines.length; index += 1) {
        if (/^\s*}\s*$/.test(lines[index])) {
          closed = true;
          break;
        }
        descriptionLines.push(lines[index].trim());
      }
      if (!closed) {
        throw new Error('accDescr block is not closed');
      }
      descriptionDirectives.push(descriptionLines.join(' ').trim());
    }
  }

  if (titleDirectives.length !== 1) {
    throw new Error(`expected exactly one active accTitle directive, found ${titleDirectives.length}`);
  }
  if (!titleDirectives[0]) {
    throw new Error('accTitle must contain authored text on the directive line');
  }
  if (descriptionDirectives.length !== 1) {
    throw new Error(`expected exactly one active accDescr directive, found ${descriptionDirectives.length}`);
  }
  if (!descriptionDirectives[0]) {
    throw new Error('accDescr must contain authored text');
  }

  return {
    title: titleDirectives[0],
    description: descriptionDirectives[0],
  };
}

export function collectInventory() {
  const failures = [];
  const fences = [];

  for (const file of discoverDocumentationFiles()) {
    const absolutePath = path.join(repositoryRoot, file);
    for (const fence of extractMermaidFences(readFileSync(absolutePath, 'utf8'), file)) {
      try {
        const metadata = validateSourceMetadata(fence.source);
        fences.push({ ...fence, ...metadata });
      } catch (error) {
        failures.push(`${fence.file}:${fence.startLine}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  return { failures, fences };
}

async function main() {
  const { failures, fences } = collectInventory();
  if (failures.length > 0) {
    console.error(`Mermaid source accessibility validation failed: ${fences.length + failures.length} fences, ${failures.length} failures`);
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exitCode = 1;
    return;
  }

  const reviewTemplateIndex = process.argv.indexOf('--review-template');
  if (reviewTemplateIndex >= 0) {
    const requestedPath = process.argv[reviewTemplateIndex + 1];
    if (!requestedPath || requestedPath.startsWith('--')) {
      throw new Error('--review-template requires an output path');
    }
    const outputPath = path.isAbsolute(requestedPath)
      ? requestedPath
      : path.resolve(repositoryRoot, requestedPath);
    const content = buildGraphicsReviewTemplate(fences, discoverGeneratedDocuments());
    const outcome = writeGraphicsReviewTemplate(outputPath, content, process.argv.includes('--check'));
    console.log(`${outcome === 'NoDrift' ? 'no drift' : 'wrote'}: ${normalizePath(path.relative(repositoryRoot, outputPath))}`);
    return;
  }

  if (process.argv.includes('--routes-json')) {
    process.stdout.write(JSON.stringify(groupRouteCases(fences, discoverGeneratedDocuments())));
    return;
  }

  if (process.argv.includes('--json')) {
    process.stdout.write(JSON.stringify(fences));
    return;
  }

  console.log(`Mermaid source accessibility validation passed: ${fences.length} fences have active authored titles and descriptions`);
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (invokedPath === import.meta.url) {
  await main();
}
