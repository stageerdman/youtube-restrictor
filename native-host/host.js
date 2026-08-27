#!/usr/bin/env node
"use strict";
// Entrypoint. The browser (Firefox/Zen or Chrome) spawns this process
// per native-messaging session and talks to it over stdin/stdout using
// the framing in
// src/stdio-framing.js. This file only wires stdio to the socket bridge
// — see CLAUDE.md: native-host is a thin, dumb pipe, no blocklist logic.

const { readMessages, writeMessage } = require("./src/stdio-framing");
const { SocketBridge } = require("./src/socket-bridge");
const SOCKET_PATH = require("./src/socket-path");

function log(...args) {
  // stdout is reserved for the native-messaging protocol; all
  // human-readable logs must go to stderr (visible via Console.app or
  // by running this script directly in a terminal).
  console.error("[native-host]", ...args);
}

const bridge = new SocketBridge(SOCKET_PATH, {
  onMessage: (message) => writeMessage(process.stdout, message),
  onLog: log,
});

bridge.connect();

readMessages(process.stdin, (message) => bridge.send(message));

process.stdin.on("end", () => {
  bridge.close();
  process.exit(0);
});

process.stdin.resume();
