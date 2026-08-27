// MV3 requires a single background entry point (no "background.scripts"
// array like Firefox's MV2 background page), so this just loads the
// shared background files in order via importScripts, same effect as
// Firefox listing them as separate <script>s sharing one global scope.
// Lives outside src/ deliberately: scripts/sync-shared-extension-sources.sh
// wipes and repopulates src/ from shared/ on every run.
importScripts(
  "src/runtime-shim.js",
  "src/messaging/native-client.js",
  "src/messaging/oembed-resolver.js",
  "src/background.js",
);
