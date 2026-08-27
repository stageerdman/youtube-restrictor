"use strict";
// Connects to the menu bar app's Unix socket as a client (the app is the
// long-running side; this host is spawned fresh by the browser per session)
// and forwards messages in both directions. Retries on disconnect since
// the app may not be running yet. No blocklist logic — pure pipe.

const net = require("net");
const { readMessages, writeMessage } = require("./stdio-framing");

const RECONNECT_DELAY_MS = 2000;

class SocketBridge {
  constructor(socketPath, { onMessage, onLog }) {
    this.socketPath = socketPath;
    this.onMessage = onMessage;
    this.onLog = onLog || (() => {});
    this.socket = null;
    this.closed = false;
  }

  connect() {
    if (this.closed) return;

    const socket = net.createConnection(this.socketPath);
    this.socket = socket;

    socket.on("connect", () => this.onLog("connected to", this.socketPath));
    readMessages(socket, (message) => this.onMessage(message));

    socket.on("error", (err) => {
      this.onLog("socket error:", err.message);
    });

    socket.on("close", () => {
      if (this.closed) return;
      this.onLog(`socket closed, retrying in ${RECONNECT_DELAY_MS}ms`);
      setTimeout(() => this.connect(), RECONNECT_DELAY_MS);
    });
  }

  send(message) {
    if (this.socket && this.socket.writable) {
      writeMessage(this.socket, message);
    } else {
      this.onLog("dropped message, not connected to app:", message.type);
    }
  }

  close() {
    this.closed = true;
    if (this.socket) this.socket.destroy();
  }
}

module.exports = { SocketBridge };
