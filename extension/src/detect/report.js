// Shared logging helper for all detection modules. Phase 1 only logs;
// later phases will call into src/match/ and src/block/ instead of
// (or in addition to) logging here.
(function () {
  const PREFIX = "[YT Restrictor]";

  function reportDetection(detection) {
    console.log(PREFIX, "detected player:", detection);
  }

  window.ytRestrictorReport = { reportDetection };
})();
