// Match: pure function from (detection, blocklist) -> matched rule | null.
// No DOM access, no blocking, no logging — just the matching decision.
(function () {
  function normalize(str) {
    return (str || "").toLowerCase().trim();
  }

  function check(detection, blocklist) {
    if (detection.videoId && blocklist.videoIds.includes(detection.videoId)) {
      return { kind: "videoId", value: detection.videoId };
    }

    if (detection.channelName) {
      const channelName = normalize(detection.channelName);
      for (const channel of blocklist.channels) {
        if (normalize(channel) === channelName) {
          return { kind: "channel", value: channel };
        }
      }
    }

    if (detection.title) {
      const title = normalize(detection.title);
      for (const keyword of blocklist.keywords) {
        if (title.includes(normalize(keyword))) {
          return { kind: "keyword", value: keyword };
        }
      }
    }

    return null;
  }

  window.ytRestrictorMatch = { check };
})();
