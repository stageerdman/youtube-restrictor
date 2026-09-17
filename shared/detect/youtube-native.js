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

  // Channel *display name* (e.g. "Grian"), not its UCxxxx id — this is
  // what blocklist "channels" entries are matched against, kept
  // consistent with embed detection which can only ever get a name (via
  // oEmbed), never an id. Lives in ytInitialPlayerResponse's
  // videoDetails.author, not ytInitialData.
  function extractChannelName() {
    for (const script of document.querySelectorAll("script")) {
      const text = script.textContent;
      if (!text || !text.includes("ytInitialPlayerResponse")) continue;
      const match = text.match(/"author":"((?:[^"\\]|\\.)*)"/);
      if (match) {
        try {
          return JSON.parse(`"${match[1]}"`);
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  function extractTitle() {
    return document.title.replace(/ - YouTube$/, "");
  }

  async function detectAndReport() {
    const videoId = extractVideoId(location.href);
    if (!videoId) return;

    const channelId = extractChannelId();
    let channelName = extractChannelName();
    let title = extractTitle();

    // Bare /embed/ pages (as opposed to a full watch page — this fires
    // there too now that this content script runs in every frame, not
    // just a tab's top frame, so it can see third-party sites' embedded
    // players) ship a stripped-down shell that never populates
    // ytInitialData/ytInitialPlayerResponse, so the DOM extraction above
    // always comes back empty here. Fall back to oEmbed, same as
    // cross-origin <iframe> embeds — see detect/embed-scan.js.
    if (location.pathname.startsWith("/embed/") && !channelName) {
      let metadata = null;
      try {
        metadata = await ytRestrictorRuntime.runtime.sendMessage({
          type: "resolve-embed-metadata",
          videoId,
        });
      } catch (err) {
        // background unreachable — proceed with videoId-only matching
      }
      if (metadata) {
        channelName = metadata.channelName;
        title = metadata.title;
      }
    }

    window.ytRestrictorReport.reportDetection({
      surface: "native",
      videoId,
      channelId,
      channelName,
      title,
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
