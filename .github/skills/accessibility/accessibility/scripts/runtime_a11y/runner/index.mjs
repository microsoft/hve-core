import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const probeId = process.argv[2];

if (!probeId) {
  console.error('No probe id provided');
  process.exit(1);
}

const modulePath = path.join(path.dirname(fileURLToPath(import.meta.url)), `${probeId}.mjs`);
if (!existsSync(modulePath)) {
  console.error(`Unknown probe module: ${probeId}`);
  process.exit(1);
}

try {
  const mod = await import(pathToFileURL(modulePath).href);
  const runner = mod.runProbe ?? mod.default;
  if (typeof runner !== 'function') {
    throw new Error(`Probe module ${probeId} does not export a runner`);
  }
  await runner();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
