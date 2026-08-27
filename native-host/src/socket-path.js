"use strict";
// Single source of truth for where the host and the (future) menu bar
// app rendezvous. Local Unix domain socket — nothing leaves the machine.

const os = require("os");
const path = require("path");

module.exports = path.join(
  os.homedir(),
  "Library",
  "Application Support",
  "YTRestrictor",
  "host.sock"
);
