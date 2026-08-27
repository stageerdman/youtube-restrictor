// Firefox defines a global `browser` (promise-based WebExtension API).
// Chrome only defines `chrome` (callback-based in MV2, but promise-based
// too when no callback is passed, since Chrome 88). This is the one
// place that picks between them, so every other shared file can just
// call `ytRestrictorRuntime.*` and work unmodified on both. Must be
// loaded first, and must use `globalThis` (not `window`) since it also
// runs inside Chrome's service worker, which has no `window`.
globalThis.ytRestrictorRuntime = typeof browser !== "undefined" ? browser : chrome;
