// Background-script only (runtime.connectNative isn't available to
// content scripts). Sends periodic heartbeats to the native host and
// persists any blocklist-update it receives to extension storage, so
// content scripts can read it. No matching or blocking logic here.
(function () {
  const HOST_NAME = "com.stage_ria.ytrestrictor";
  const HEARTBEAT_INTERVAL_MS = 60 * 1000;
  const PROTOCOL_VERSION = "0.1.0";

  let port = null;

  function log(...args) {
    console.log("[YT Restrictor messaging]", ...args);
  }

  function handleMessage(message) {
    if (!message || typeof message !== "object") return;
    if (message.type === "blocklist-update" && message.blocklist) {
      log("received blocklist update:", message.blocklist);
      browser.storage.local.set({ blocklist: message.blocklist });
    }
  }

  function connect() {
    try {
      port = browser.runtime.connectNative(HOST_NAME);
    } catch (err) {
      log("failed to connect to native host:", err.message);
      port = null;
      return;
    }

    port.onMessage.addListener(handleMessage);
    port.onDisconnect.addListener(() => {
      const err = browser.runtime.lastError;
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

  sendHeartbeat();
  setInterval(sendHeartbeat, HEARTBEAT_INTERVAL_MS);
})();
