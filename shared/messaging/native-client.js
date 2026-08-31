// Background-script only (runtime.connectNative isn't available to
// content scripts). Sends periodic heartbeats to the native host and
// persists any blocklist-update it receives to extension storage, so
// content scripts can read it. No matching or blocking logic here.
//
// Uses the alarms API rather than setInterval for scheduling: Chrome's
// MV3 service worker gets killed after ~30s idle, which would silently
// stop a setInterval forever, but alarms wake the worker back up. All
// three browsers implement alarms, so this is a no-behavior-change on
// the Firefox/Chrome side.
//
// Safari's WebExtension implementation only supports one-shot
// browser.runtime.sendNativeMessage() request/response — there's no
// persistent connectNative() port. Apple routes sendNativeMessage calls
// to SFSafariExtensionHandler.beginRequest() in the Safari Web
// Extension's native Swift code (menubar-app/SafariExtension/), which
// has one request-in/response-out override point, not a connection
// object to push unsolicited messages on. So on Safari every heartbeat
// doubles as a poll for the current blocklist, arriving as that same
// request's response instead of pushed asynchronously at any time like
// Firefox/Chrome — see docs/PROTOCOL.md's "Safari transport" section.
(function () {
  const HOST_NAME = "com.stage_ria.ytrestrictor";
  const HEARTBEAT_ALARM_NAME = "yt-restrictor-heartbeat";
  const HEARTBEAT_INTERVAL_MINUTES = 1;
  const PROTOCOL_VERSION = "0.1.0";

  const supportsConnectNative =
    typeof ytRestrictorRuntime.runtime.connectNative === "function";

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

  function sendHeartbeatViaPort() {
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

  function sendHeartbeatViaSendNativeMessage() {
    // This path only runs when connectNative is missing, which today
    // means ytRestrictorRuntime is the `browser` namespace (Safari uses
    // it, same as Firefox — see runtime-shim.js), not `chrome`. browser.*
    // APIs are strictly Promise-based with no callback parameter —
    // sendNativeMessage(application, message) takes exactly two
    // arguments. Passing a third callback argument here used to also
    // consume the return value as a Promise, which risked calling
    // handleMessage (and hitting the native handler) twice per heartbeat
    // for what should be a single round trip.
    ytRestrictorRuntime.runtime
      .sendNativeMessage(HOST_NAME, {
        type: "heartbeat",
        version: PROTOCOL_VERSION,
        timestamp: Date.now(),
      })
      .then(handleMessage)
      .catch((err) => {
        log("failed to send heartbeat:", err.message);
      });
  }

  function sendHeartbeat() {
    if (supportsConnectNative) {
      sendHeartbeatViaPort();
    } else {
      sendHeartbeatViaSendNativeMessage();
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
