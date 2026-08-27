// Background-only: resolves title + channel name for embedded YouTube
// videos via YouTube's public oEmbed endpoint (no API key needed), since
// embedded players are cross-origin iframes the content script can't
// otherwise read anything out of. This is the "YouTube Data API... to
// resolve channel names for embeds" case CLAUDE.md's network-calls
// principle names explicitly. Results are cached for the life of the
// background script; failures (offline, rate-limited) resolve to null
// rather than blocking detection.
(function () {
  const cache = new Map(); // videoId -> { title, channelName } | null
  const FETCH_TIMEOUT_MS = 5000;

  async function resolve(videoId) {
    if (cache.has(videoId)) return cache.get(videoId);

    const watchUrl = `https://www.youtube.com/watch?v=${encodeURIComponent(videoId)}`;
    const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(watchUrl)}&format=json`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    try {
      const response = await fetch(oembedUrl, { signal: controller.signal });
      if (!response.ok) throw new Error(`oembed responded ${response.status}`);
      const data = await response.json();
      const result = {
        title: data.title || null,
        channelName: data.author_name || null,
      };
      cache.set(videoId, result);
      return result;
    } catch (err) {
      console.log("[YT Restrictor oembed] failed to resolve", videoId, err.message);
      cache.set(videoId, null);
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }

  browser.runtime.onMessage.addListener((message) => {
    if (message && message.type === "resolve-embed-metadata") {
      return resolve(message.videoId);
    }
    return undefined;
  });
})();
