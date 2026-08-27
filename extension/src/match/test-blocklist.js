// TEMPORARY (Phase 2 only, still used as a fallback if the real
// blocklist hasn't arrived yet): a hardcoded test blocklist so the block
// pipeline can be exercised end-to-end without the menu bar app running.
// Same shape as extension/blocklist.example.json.
(function () {
  window.ytRestrictorTestBlocklist = {
    channels: ["Rick Astley"], // public test channel
    videoIds: ["dQw4w9WgXcQ"], // Never Gonna Give You Up — public test video
    keywords: ["shorts"],
  };
})();
