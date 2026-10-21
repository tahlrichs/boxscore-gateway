// Fails the build on a Node version older than the October 2026 security release.
const [major, minor, patch] = process.versions.node.split('.').map(Number);
const ok = major > 24 || (major === 24 && (minor > 22 || (minor === 22 && patch >= 1)));
if (!ok) {
  console.error(`Node ${process.version} has known security vulnerabilities; use 24.22.1 or newer.`);
  process.exit(1);
}
