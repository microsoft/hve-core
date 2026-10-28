// Copyright (c) Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { lstat, readdir, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

export async function buildAllDecks({ repoRoot = process.cwd(), check = false } = {}) {
  const root = await realpath(repoRoot);
  const installation = await realpath(path.resolve(scriptDirectory, '..'));
  const relative = path.relative(installation, root);
  if (relative === '' || (!path.isAbsolute(relative) && relative !== '..' && !relative.startsWith(`..${path.sep}`))) {
    throw new Error('The workspace root must be outside the skill installation. Use --repo-root with a trusted workspace.');
  }
  const slides = path.join(root, 'slides');
  const parent = await lstat(slides);
  if (!parent.isDirectory() || parent.isSymbolicLink()) {
    throw new Error('slides must be a real directory, not a file or symbolic link.');
  }
  const entries = await readdir(slides, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isSymbolicLink()) throw new Error(`Refusing symbolic-link entry: ${path.join(slides, entry.name)}`);
  }
  const names = entries.filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  if (!names.length) throw new Error(`No slide decks found in ${slides}. Create a deck with npm run slides:create first.`);

  const outputs = [];
  for (const name of names) {
    const directory = path.join(slides, name);
    try {
      const script = path.join(directory, 'bundle.mjs');
      const entry = await lstat(script);
      if (!entry.isFile() || entry.isSymbolicLink()) throw new Error('bundle.mjs must be a regular file.');
      const module = await import(pathToFileURL(script).href);
      const operation = check ? 'checkBundle' : 'bundleDeck';
      if (typeof module[operation] !== 'function') throw new Error(`bundle.mjs must export a ${operation} function.`);
      const output = await module[operation]();
      const expected = path.join(root, 'docs/slides', `${name}.html`);
      if (output !== expected) throw new Error(`${operation} must return ${expected}.`);
      const file = await lstat(output);
      if (!file.isFile() || file.size === 0) throw new Error(`Expected a nonempty HTML file at ${output}.`);
      outputs.push(output);
    } catch (error) {
      throw new Error(`Failed to bundle slides/${name}: ${error.message}`, { cause: error });
    }
  }
  if (check) {
    const generated = await readdir(path.join(root, 'docs/slides'), { withFileTypes: true });
    for (const entry of generated.filter(entry => entry.name.endsWith('.html'))) {
      if (!entry.isFile() || !names.includes(entry.name.slice(0, -5))) {
        throw new Error(`Unexpected generated slide bundle: ${entry.name}. Every HTML bundle must have a corresponding source deck.`);
      }
    }
  }
  return outputs;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.length === 1 && args[0] === '--help') {
      console.log('Usage: node <loaded-skill-root>/scripts/build-decks.mjs [--repo-root <workspace>] [--check]\nRuns trusted deck programs under slides/ and writes docs/slides/<deck-name>.html. Defaults to the current working directory. --check compares existing HTML. Does not install, serve or publish.');
    } else {
      const options = {};
      for (let index = 0; index < args.length; index += 1) {
        const option = args[index];
        if (option === '--check' && !Object.hasOwn(options, 'check')) options.check = true;
        else if (option === '--repo-root' && !Object.hasOwn(options, 'repoRoot')) {
          const value = args[++index];
          if (!value || value.startsWith('--')) throw new Error('Missing value for --repo-root.');
          options.repoRoot = value;
        } else throw new Error('Only --check, --repo-root or --help is supported; options must not repeat.');
      }
      const check = options.check === true;
      const outputs = await buildAllDecks(options);
      for (const output of outputs) console.log(`${check ? 'Checked' : 'Built'} ${output}`);
      console.log(`${check ? 'Checked' : 'Bundled'} ${outputs.length} deck(s).`);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
