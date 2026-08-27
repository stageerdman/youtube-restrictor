// Background-script only (runtime.connectNative isn't available to
// content scripts). Sends periodic heartbeats to the native host and
// persists any blocklist-update it receives to extension storage, so
// content scripts can read it. No matching or blocking logic here.
//
// Uses the alarms API rather than setInterval for scheduling: Chrome's
// MV3 service worker gets killed after ~30s idle, which would silently
// stop a setInterval forever, but alarms wake the worker back up. Both
// Firefox and Chrome implement alarms, so this is a no-behavior-change
// on the Firefox side.
(function () {
  const HOST_NAME = "com.stage_ria.ytrestrictor";
  const HEARTBEAT_ALARM_NAME = "yt-restrictor-heartbeat";
  const HEARTBEAT_INTERVAL_MINUTES = 1;
  const PROTOCOL_VERSION = "0.1.0";

  let port = null;

  function log(...args) {
    console.log("[YT Restrictor messaging]", ...args);
  }

  function handleMessage(message) {
    if (!message || typeof message !== "object") return;
    if (message.type === "blocklist-update" && message.blocklist) {
      log("received blocklist update:", message.blocklist);
      ytRestrictorRuntime.storage.local.set({ blocklist: message.blocklist });
    }
  }

  function connect() {
    try {
      port = ytRestrictorRuntime.runtime.connectNative(HOST_NAME);
    } catch (err) {
      log("failed to connect to native host:", err.message);
      port = null;
      return;
    }

    port.onMessage.addListener(handleMessage);
    port.onDisconnect.addListener(() => {
      const err = ytRestrictorRuntime.runtime.lastError;
      log("native host disconnected", err ? err.message : "");
      port = null;
    });

    log("connected to native host");
  }

  function sendHeartbeat() {
    if (!port) connect();
    if (!port) return;

    try {
      port.postMessage({
        type: "heartbeat",
        version: PROTOCOL_VERSION,
        timestamp: Date.now(),
      });
    } catch (err) {
      log("failed to send heartbeat:", err.message);
      port = null;
    }
  }

  ytRestrictorRuntime.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === HEARTBEAT_ALARM_NAME) sendHeartbeat();
  });
  ytRestrictorRuntime.alarms.create(HEARTBEAT_ALARM_NAME, {
    periodInMinutes: HEARTBEAT_INTERVAL_MINUTES,
  });
  sendHeartbeat();
})();
