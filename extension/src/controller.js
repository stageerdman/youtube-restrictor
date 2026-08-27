// Orchestration only: wires detect -> notify -> match -> block. Contains
// no detection, matching, or blocking logic itself — each of those lives
// in its own module and is independently testable.
(function () {
  function reportDetection(detection) {
    window.ytRestrictorNotify.log(detection);

    const rule = window.ytRestrictorMatch.check(
      detection,
      window.ytRestrictorTestBlocklist
    );
    if (!rule) return;

    if (detection.surface === "native") {
      window.ytRestrictorBlock.blockNative(detection, rule);
    } else if (detection.surface === "embed") {
      window.ytRestrictorBlock.blockEmbed(detection, rule);
    }
  }

  window.ytRestrictorReport = { reportDetection };
})();
