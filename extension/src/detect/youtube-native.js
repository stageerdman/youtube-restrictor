// Detects playback on native youtube.com / youtu.be pages. Read-only:
// extracts the video id from the URL and best-effort channel info from
// the page's own ytInitialData blob (parsed from script tag text, never
// executed) so we never run code in the page's JS context.
(function () {
  function extractVideoId(url) {
    try {
      const u = new URL(url);
      if (u.hostname === "youtu.be") {
        return u.pathname.slice(1) || null;
      }
      if (u.pathname.startsWith("/shorts/")) {
        return u.pathname.split("/")[2] || null;
      }
      if (u.pathname === "/watch") {
        return u.searchParams.get("v");
      }
      if (u.pathname.startsWith("/embed/")) {
        return u.pathname.split("/")[2] || null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  function extractChannelId() {
    for (const script of document.querySelectorAll("script")) {
      const text = script.textContent;
      if (!text || !text.includes("ytInitialData")) continue;
      const match = text.match(/"channelId":"(UC[\w-]{22})"/);
      if (match) return match[1];
    }
    return null;
  }

  function detectAndReport() {
    const videoId = extractVideoId(location.href);
    if (!videoId) return;
    window.ytRestrictorReport.reportDetection({
      surface: "native",
      videoId,
      channelId: extractChannelId(),
      url: location.href,
    });
  }

  detectAndReport();

  // YouTube is a SPA — it dispatches this event on navigation without a
  // full page reload (watch -> watch, home -> watch, etc.).
  document.addEventListener("yt-navigate-finish", detectAndReport);

  // Fallback in case yt-navigate-finish isn't available on this surface
  // (e.g. bare /embed/ pages): catch URL changes via history patches.
  let lastUrl = location.href;
  new MutationObserver(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      detectAndReport();
    }
  }).observe(document, { subtree: true, childList: true });
})();
