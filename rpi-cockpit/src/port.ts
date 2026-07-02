// Resolve the port the cockpit should bind. Precedence, highest first:
//   1. PORT               — assigned by the host pane (Claude Preview, VS Code).
//   2. RPI_COCKPIT_PORT   — our own override for standalone runs.
//   3. 4399               — the stable default.
// A candidate counts only if it is a finite integer in the valid TCP range
// 1..65535. Anything else (empty, NaN, 0, negative, > 65535, fractional) is
// treated as absent and we fall through to the next source.
function validPort(raw: string | undefined): number | null {
  if (raw === undefined || raw === "") return null;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > 65535) return null;
  return n;
}

export function resolvePort(env: Record<string, string | undefined>): number {
  return validPort(env.PORT) ?? validPort(env.RPI_COCKPIT_PORT) ?? 4399;
}
