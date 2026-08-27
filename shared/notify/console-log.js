// Notify: the only thing this module does is surface detections to the
// console. It has no opinion on matching or blocking.
(function () {
  const PREFIX = "[YT Restrictor]";

  function log(detection) {
    console.log(PREFIX, "detected player:", detection);
  }

  window.ytRestrictorNotify = { log };
})();
