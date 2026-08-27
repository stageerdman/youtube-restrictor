// Presentation only: builds the blocked-message placeholder element and
// the plain-language reason text. No DOM insertion, no matching logic.
(function () {
  function reasonText(rule) {
    switch (rule.kind) {
      case "videoId":
        return "This video is on your blocklist.";
      case "channelId":
        return "This channel is on your blocklist.";
      case "keyword":
        return `Title matches blocked keyword "${rule.value}".`;
      default:
        return "Blocked.";
    }
  }

  function makePlaceholder(reason, width, height) {
    const container = document.createElement("div");
    container.className = "yt-restrictor-placeholder";
    container.style.cssText = [
      "display:flex",
      "align-items:center",
      "justify-content:center",
      "flex-direction:column",
      "background:#111",
      "color:#eee",
      "font:14px/1.4 -apple-system,BlinkMacSystemFont,sans-serif",
      "text-align:center",
      "padding:16px",
      "box-sizing:border-box",
      width ? `width:${width}px` : "width:100%",
      height ? `height:${height}px` : "height:100%",
    ].join(";");

    const title = document.createElement("div");
    title.style.fontWeight = "600";
    title.style.marginBottom = "6px";
    title.textContent = "Blocked by YouTube Restrictor";

    const detail = document.createElement("div");
    detail.style.opacity = "0.8";
    detail.textContent = reason;

    container.appendChild(title);
    container.appendChild(detail);
    return container;
  }

  window.ytRestrictorPlaceholder = { makePlaceholder, reasonText };
})();
