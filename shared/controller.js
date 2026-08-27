// Orchestration only: wires detect -> notify -> match -> block. Contains
// no detection, matching, or blocking logic itself — each of those lives
// in its own module and is independently testable.
(function () {
  async function getActiveBlocklist() {
    try {
      const stored = await ytRestrictorRuntime.storage.local.get("blocklist");
      if (stored && stored.blocklist) return stored.blocklist;
    } catch (err) {
      // storage unavailable — fall back to the hardcoded test blocklist
      // below, same as if nothing had been pushed yet.
    }
    return window.ytRestrictorTestBlocklist;
  }

  async function reportDetection(detection) {
    window.ytRestrictorNotify.log(detection);

    const blocklist = await getActiveBlocklist();
    const rule = window.ytRestrictorMatch.check(detection, blocklist);
    if (!rule) return;

    if (detection.surface === "native") {
      window.ytRestrictorBlock.blockNative(detection, rule);
    } else if (detection.surface === "embed") {
      window.ytRestrictorBlock.blockEmbed(detection, rule);
    }
  }

  window.ytRestrictorReport = { reportDetection };
})();
