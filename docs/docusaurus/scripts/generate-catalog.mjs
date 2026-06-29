#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import matter from 'gray-matter';
import { parse as parseYaml } from 'yaml';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '../../..');
const collectionsDir = path.join(repoRoot, 'collections');
const outputPath = path.join(repoRoot, 'docs', 'docusaurus', 'static', 'catalog.json');
const artifactRoots = [
  path.join(repoRoot, '.github', 'agents'),
  path.join(repoRoot, '.github', 'prompts'),
  path.join(repoRoot, '.github', 'skills'),
  path.join(repoRoot, '.github', 'instructions'),
];

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function normalizeRepoPath(value) {
  return toPosix(value.replace(/^\.\//, '').replace(/^\//, ''));
}

function walkFiles(rootDir) {
  const files = [];

  function visit(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });

    for (const entry of entries) {
      if (entry.name === '.git') {
        continue;
      }

      const fullPath = path.join(currentDir, entry.name);
      const relativePath = toPosix(path.relative(rootDir, fullPath));

      if (entry.isDirectory()) {
        visit(fullPath);
        continue;
      }

      if (!entry.isFile()) {
        continue;
      }

      if (!relativePath.includes('/')) {
        continue;
      }

      const baseName = path.basename(fullPath);
      if (baseName.startsWith('_')) {
        continue;
      }

      if (/test/i.test(baseName)) {
        continue;
      }

      files.push(fullPath);
    }
  }

  visit(rootDir);
  return files;
}

function deriveKind(filePath) {
  const baseName = path.basename(filePath);
  if (baseName.endsWith('.agent.md')) {
    return 'agent';
  }
  if (baseName.endsWith('.prompt.md')) {
    return 'prompt';
  }
  if (baseName.endsWith('.instructions.md')) {
    return 'instruction';
  }
  if (baseName === 'SKILL.md') {
    return 'skill';
  }
  return null;
}

function deriveName(filePath) {
  const baseName = path.basename(filePath);
  const withoutExt = baseName.replace(/\.md$/u, '');
  if (withoutExt === 'SKILL') {
    return path.basename(path.dirname(filePath));
  }
  if (withoutExt.endsWith('.agent')) {
    return withoutExt.replace(/\.agent$/u, '');
  }
  if (withoutExt.endsWith('.prompt')) {
    return withoutExt.replace(/\.prompt$/u, '');
  }
  if (withoutExt.endsWith('.instructions')) {
    return withoutExt.replace(/\.instructions$/u, '');
  }
  return withoutExt;
}

function getHeadings(content) {
  return content
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter((line) => /^#{1,6}\s+/u.test(line))
    .map((line) => line.replace(/^#{1,6}\s+/u, '').trim())
    .filter(Boolean);
}

function getIntro(content) {
  const body = content.replace(/^---[\s\S]*?---\s*/u, '').trim();
  const blocks = body
    .split(/\n\s*\n/u)
    .map((block) => block.trim())
    .filter(Boolean);

  const intro = blocks.find((block) => !/^#{1,6}\s+/u.test(block) && !/^```/u.test(block));
  if (!intro) {
    return '';
  }

  return intro
    .replace(/\[(.*?)\]\([^)]*\)/gu, '$1')
    .replace(/`([^`]+)`/gu, '$1')
    .replace(/[*_~]/gu, '')
    .trim();
}

function loadCollectionEntries() {
  if (!fs.existsSync(collectionsDir)) {
    return [];
  }

  const files = fs.readdirSync(collectionsDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.collection.yml'))
    .map((entry) => path.join(collectionsDir, entry.name));

  const entries = [];

  for (const filePath of files) {
    try {
      const text = fs.readFileSync(filePath, 'utf8');
      const parsed = parseYaml(text) || {};
      const manifestItems = Array.isArray(parsed.items) ? parsed.items : [];
      const collectionName = parsed.name || parsed.id || path.basename(filePath, '.collection.yml');

      for (const item of manifestItems) {
        if (!item || typeof item !== 'object' || typeof item.path !== 'string') {
          continue;
        }

        entries.push({
          path: normalizeRepoPath(item.path),
          kind: item.kind || null,
          maturity: item.maturity || 'stable',
          collection: collectionName,
        });
      }
    } catch (error) {
      console.warn(`[catalog] Could not parse collection manifest ${path.relative(repoRoot, filePath)}: ${error.message}`);
    }
  }

  return entries;
}

function findCollectionMetadata(relativePath, kind, manifestEntries) {
  const normalizedPath = normalizeRepoPath(relativePath);

  for (const entry of manifestEntries) {
    if (entry.kind && entry.kind !== kind) {
      continue;
    }

    if (normalizedPath === entry.path || normalizedPath.startsWith(`${entry.path}/`)) {
      return {
        collection: entry.collection || null,
        maturity: entry.maturity || 'stable',
      };
    }
  }

  return {
    collection: null,
    maturity: 'stable',
  };
}

function createCatalog() {
  const manifestEntries = loadCollectionEntries();
  const items = [];

  for (const rootDir of artifactRoots) {
    const files = walkFiles(rootDir);

    for (const filePath of files) {
      const relativePath = toPosix(path.relative(repoRoot, filePath));
      const kind = deriveKind(filePath);

      if (!kind) {
        continue;
      }

      try {
        const parsed = matter.read(filePath);
        const frontmatter = parsed.data || {};
        const content = parsed.content || '';
        const metadata = findCollectionMetadata(relativePath, kind, manifestEntries);

        const item = {
          id: normalizeRepoPath(relativePath),
          name: frontmatter.name || frontmatter.title || deriveName(filePath),
          description: frontmatter.description || '',
          kind,
          path: normalizeRepoPath(relativePath),
          collection: metadata.collection,
          tags: Array.isArray(frontmatter.tags) ? frontmatter.tags.filter(Boolean) : [],
          maturity: metadata.maturity || 'stable',
          interaction: {
            argumentHint: frontmatter['argument-hint'] || frontmatter.argumentHint || '',
            model: frontmatter.model || '',
            agent: frontmatter.agent || '',
            applyTo: frontmatter.applyTo || '',
          },
          intro: getIntro(content),
          headings: getHeadings(content),
        };

        items.push(item);
      } catch (error) {
        const metadata = findCollectionMetadata(relativePath, kind, manifestEntries);
        items.push({
          id: normalizeRepoPath(relativePath),
          name: deriveName(filePath),
          description: '',
          kind,
          path: normalizeRepoPath(relativePath),
          collection: metadata.collection,
          tags: [],
          maturity: metadata.maturity || 'stable',
          interaction: {
            argumentHint: '',
            model: '',
            agent: '',
            applyTo: '',
          },
          intro: '',
          headings: [],
        });
        console.warn(`[catalog] Using fallback metadata for ${relativePath}: ${error.message}`);
      }
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    items,
  };
}

function main() {
  const catalog = createCatalog();
  const outputDir = path.dirname(outputPath);
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(catalog, null, 2)}\n`, 'utf8');
  console.log(`[catalog] Wrote ${catalog.items.length} items to ${toPosix(path.relative(repoRoot, outputPath))}`);
}

main();
