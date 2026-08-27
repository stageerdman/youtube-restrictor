#!/usr/bin/env node
"use strict";
// Manual test harness standing in for the not-yet-built menu bar app
// (that's Phase 4). Listens on the same Unix socket the native host
// connects to, logs every message the host forwards (heartbeats), and
// pushes one test blocklist-update a few seconds after connecting so
// you can watch a real browser tab react. Not part of the shipped
// product — see native-host/README.md for how to use this.

const net = require("net");
const fs = require("fs");
const path = require("path");
const { readMessages, writeMessage } = require("../src/stdio-framing");
const SOCKET_PATH = require("../src/socket-path");

const TEST_BLOCKLIST_UPDATE = {
  type: "blocklist-update",
  version: "0.1.0",
  timestamp: Date.now(),
  blocklist: {
    channelIds: [],
    videoIds: ["jNQXAC9IVRw"], // "Me at the zoo" — first video ever on YouTube
    keywords: ["phase-3-test"],
  },
};

fs.mkdirSync(path.dirname(SOCKET_PATH), { recursive: true });
if (fs.existsSync(SOCKET_PATH)) fs.unlinkSync(SOCKET_PATH);

const server = net.createServer((socket) => {
  console.log("[fake-app] native host connected");

  readMessages(socket, (message) => {
    console.log("[fake-app] received:", message);
  });

  const timer = setTimeout(() => {
    console.log("[fake-app] sending test blocklist-update:", TEST_BLOCKLIST_UPDATE);
    writeMessage(socket, TEST_BLOCKLIST_UPDATE);
  }, 3000);

  socket.on("close", () => {
    clearTimeout(timer);
    console.log("[fake-app] native host disconnected");
  });
});

server.listen(SOCKET_PATH, () => {
  console.log("[fake-app] listening on", SOCKET_PATH);
  console.log("[fake-app] waiting for the native host to connect...");
});
