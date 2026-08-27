// Detects embedded YouTube players on third-party sites: scans iframes
// present at page load and watches for ones injected later (lazy-loaded
// players, infinite-scroll feeds, etc.).
(function () {
  const EMBED_HOST_PATTERN = /(?:^|\.)youtube(?:-nocookie)?\.com$/;

  function extractVideoId(src) {
    try {
      const u = new URL(src, location.href);
      if (!EMBED_HOST_PATTERN.test(u.hostname)) return null;
      const parts = u.pathname.split("/").filter(Boolean);
      const embedIndex = parts.indexOf("embed");
      if (embedIndex === -1) return null;
      return parts[embedIndex + 1] || null;
    } catch (e) {
      return null;
    }
  }

  const seen = new WeakSet();

  async function checkIframe(iframe) {
    if (seen.has(iframe)) return;
    const src = iframe.getAttribute("src");
    if (!src) return;
    const videoId = extractVideoId(src);
    if (!videoId) return;
    seen.add(iframe);

    // Cross-origin iframe — we can't read its title or channel directly,
    // so ask the background script to resolve them (see
    // messaging/oembed-resolver.js). Falls back to null on failure
    // (offline, rate-limited), which still allows videoId-only matches.
    let metadata = null;
    try {
      metadata = await ytRestrictorRuntime.runtime.sendMessage({
        type: "resolve-embed-metadata",
        videoId,
      });
    } catch (err) {
      // background unreachable — proceed with videoId-only matching
    }

    window.ytRestrictorReport.reportDetection({
      surface: "embed",
      videoId,
      channelId: null,
      channelName: metadata ? metadata.channelName : null,
      title: metadata ? metadata.title : null,
      url: src,
      pageUrl: location.href,
      element: iframe,
    });
  }

  function scan(root) {
    root.querySelectorAll("iframe").forEach(checkIframe);
  }

  scan(document);

  new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== Node.ELEMENT_NODE) continue;
        if (node.tagName === "IFRAME") {
          checkIframe(node);
        } else {
          scan(node);
        }
      }
      if (
        mutation.type === "attributes" &&
        mutation.target.tagName === "IFRAME"
      ) {
        checkIframe(mutation.target);
      }
    }
  }).observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["src"],
  });
})();
