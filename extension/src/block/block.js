// Block: stops playback and swaps the player for the placeholder built
// by block/placeholder.js. Idempotent by construction — once a player
// element is replaced, it no longer exists in the DOM to re-match on a
// redundant call, so there's no separate "already blocked" state to track.
(function () {
  function blockNative(detection, rule) {
    const player = document.getElementById("movie_player");
    if (!player || !player.parentElement) return;

    document.querySelectorAll("video").forEach((video) => {
      video.pause();
      video.addEventListener("play", () => video.pause());
    });

    const reason = window.ytRestrictorPlaceholder.reasonText(rule);
    const placeholder = window.ytRestrictorPlaceholder.makePlaceholder(
      reason,
      player.clientWidth,
      player.clientHeight
    );
    player.replaceWith(placeholder);
    console.log("[YT Restrictor] blocked native player:", detection, rule);
  }

  function blockEmbed(detection, rule) {
    const iframe = detection.element;
    if (!iframe || !iframe.parentElement) return;

    const reason = window.ytRestrictorPlaceholder.reasonText(rule);
    const placeholder = window.ytRestrictorPlaceholder.makePlaceholder(
      reason,
      iframe.clientWidth,
      iframe.clientHeight
    );
    iframe.replaceWith(placeholder);
    console.log("[YT Restrictor] blocked embedded player:", detection, rule);
  }

  window.ytRestrictorBlock = { blockNative, blockEmbed };
})();
