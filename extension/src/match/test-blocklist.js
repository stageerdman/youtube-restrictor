// TEMPORARY (Phase 2 only): a hardcoded test blocklist so the block
// pipeline can be exercised end-to-end without the menu bar app existing
// yet. Phase 4 replaces this with the real blocklist, pushed over native
// messaging per docs/PROTOCOL.md's blocklist-update message, and stored
// the same shape as extension/blocklist.example.json.
(function () {
  window.ytRestrictorTestBlocklist = {
    channelIds: ["UCuAXFkgsw1L7xaCfnd5JJOw"], // "Rick Astley" — public test channel
    videoIds: ["dQw4w9WgXcQ"], // Never Gonna Give You Up — public test video
    keywords: ["shorts"],
  };
})();
