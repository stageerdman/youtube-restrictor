// MV3 requires a single background entry point, same as extension-chrome/
// (see that directory's service-worker.js for the fuller explanation).
// Safari 16.4+ supports the same service-worker background type, so this
// file is byte-for-byte the same shape as Chrome's. Lives outside src/
// deliberately: scripts/sync-shared-extension-sources.sh wipes and
// repopulates src/ from shared/ on every run.
importScripts(
  "src/runtime-shim.js",
  "src/messaging/native-client.js",
  "src/messaging/oembed-resolver.js",
  "src/background.js",
);
