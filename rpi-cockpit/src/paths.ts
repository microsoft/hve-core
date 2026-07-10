// rpi-cockpit/src/paths.ts
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";

// Both the producer (the MCP server) and the consumer (`dist/index.js live`)
// derive the SAME shared dir from the repo root, with no host env interpolation.
// A short hash of the absolute repo root keys the dir so two repos on one host
// never collide, while one repo's two processes always agree on the path.
export function liveStateDir(repoRoot: string): string {
  const hash = crypto.createHash("sha1").update(repoRoot).digest("hex").slice(0, 12);
  return path.join(os.tmpdir(), "rpi-cockpit", "live", hash);
}
