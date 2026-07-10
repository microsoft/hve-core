// rpi-cockpit/src/url.ts
// Shared loopback predicate. The app frame embeds a TRUSTED iframe of the user's
// app-under-development (scripts + the app's own origin), so the URL it loads must
// be constrained to a loopback http(s) origin. This single predicate is the one
// source of truth: the MCP tool boundary enforces it server-side, and the client
// mirrors the same logic before assigning the iframe src (defense in depth). The
// client copy in public/client.js must stay byte-for-byte equivalent to this.
export function isLoopbackHttpUrl(u: string): boolean {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    const h = url.hostname.toLowerCase();
    return h === "localhost" || h === "127.0.0.1" || h === "[::1]" || h === "::1";
  } catch {
    return false;
  }
}

// Gallery tiles may frame loopback dev servers (http or https) and external
// https sites. External http is rejected. The client mirrors this predicate
// before assigning an iframe src (defense in depth), so keep the two copies
// byte-for-byte equivalent (the copy lives in public/client.js).
export function isGalleryUrl(u: string): boolean {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    if (isLoopbackHttpUrl(u)) return true;
    return url.protocol === "https:";
  } catch {
    return false;
  }
}
