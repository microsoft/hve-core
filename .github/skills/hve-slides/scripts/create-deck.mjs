// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import { lstat, mkdir, readFile, realpath, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const templateDirectory = path.resolve(scriptDirectory, '../templates/deck');
const defaultRepoRoot = path.resolve(scriptDirectory, '../../../..');
export const templateFiles = Object.freeze([
  '.gitignore', '.npmrc', 'LICENSE', 'README.md', 'package.json', 'package-lock.json',
  'deck.json', 'index.html', 'theme.css', 'components.css', 'content.js',
  'components.js', 'deck.js', 'build.mjs', 'bundle.mjs', 'deck.test.cjs'
]);

async function inspect(file) {
  try {
    return await lstat(file);
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

export function parseArguments(args) {
  if (args.length === 1 && args[0] === '--help') return { help: true };
  const values = {};
  for (let index = 0; index < args.length; index += 2) {
    const option = args[index];
    if (!['--slug', '--title'].includes(option)) throw new Error(`Unknown option: ${option}`);
    const key = option.slice(2);
    if (Object.hasOwn(values, key)) throw new Error(`Repeated option: ${option}`);
    if (!args[index + 1] || args[index + 1].startsWith('--')) throw new Error(`Missing value for ${option}`);
    values[key] = args[index + 1];
  }
  if (!values.slug || !values.title) throw new Error('Both --slug and --title are required.');
  return values;
}

export async function createDeck({ slug, title, repoRoot = defaultRepoRoot }) {
  if (typeof slug !== 'string' || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(slug)
    || /^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])$/.test(slug)) {
    throw new Error('Use a portable lower-kebab-case slug, without paths or reserved device names.');
  }
  if (typeof title !== 'string' || !title.trim() || /[\u0000-\u001f\u007f]/.test(title)) {
    throw new Error('Use a nonempty single-line title.');
  }
  const root = await realpath(repoRoot);
  const slides = path.join(root, 'slides');
  const destination = path.join(slides, slug);
  const parent = await inspect(slides);
  if (parent && (!parent.isDirectory() || parent.isSymbolicLink())) throw new Error('slides must be a real directory, not a file or symbolic link.');
  if (await inspect(destination)) throw new Error(`Refusing to overwrite existing destination: ${destination}`);

  const files = new Map();
  for (const file of templateFiles) {
    const source = path.join(templateDirectory, file);
    const entry = await lstat(source);
    if (!entry.isFile() || entry.isSymbolicLink()) throw new Error(`Template source must be a regular file: ${file}`);
    files.set(file, await readFile(source, 'utf8'));
  }
  const manifest = JSON.parse(files.get('package.json'));
  const lock = JSON.parse(files.get('package-lock.json'));
  const config = JSON.parse(files.get('deck.json'));
  manifest.name = slug;
  lock.name = slug;
  lock.packages[''].name = slug;
  config.title = title.trim();
  files.set('package.json', `${JSON.stringify(manifest, null, 2)}\n`);
  files.set('package-lock.json', `${JSON.stringify(lock, null, 2)}\n`);
  files.set('deck.json', `${JSON.stringify(config, null, 2)}\n`);

  if (!parent) await mkdir(slides);
  if (await realpath(slides) !== slides) throw new Error('The slides directory resolves outside its expected location.');
  // Exclusive creation claims a new directory; individual files are also never overwritten.
  await mkdir(destination);
  try {
    for (const [file, content] of files) await writeFile(path.join(destination, file), content, { encoding: 'utf8', flag: 'wx' });
  } catch (error) {
    throw new Error(`Could not finish ${destination}. The partial directory was left for inspection: ${error.message}`, { cause: error });
  }
  return destination;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = parseArguments(process.argv.slice(2));
    if (args.help) {
      console.log('Usage: node .github/skills/hve-slides/scripts/create-deck.mjs --slug contributor-tour --title "Contributor tour"\nCreates a new slides/<slug> directory. Does not install, serve or publish.');
    } else {
      const destination = await createDeck(args);
      console.log(`Created ${destination}\nNext: npm ci --prefix slides/${args.slug}\nThen: npm run bundle --prefix slides/${args.slug}\nOpen slides/${args.slug}/dist/${args.slug}.html after building. Replace the starter content before presenting.`);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
