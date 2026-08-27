"use strict";
// Firefox Native Messaging stdio framing: each message is a 4-byte
// little-endian length prefix followed by that many bytes of UTF-8 JSON.
// This module only knows about that framing — nothing about what the
// messages mean.

function readMessages(inputStream, onMessage) {
  let buffer = Buffer.alloc(0);

  inputStream.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);

    while (buffer.length >= 4) {
      const length = buffer.readUInt32LE(0);
      if (buffer.length < 4 + length) break;

      const body = buffer.subarray(4, 4 + length);
      buffer = buffer.subarray(4 + length);

      try {
        onMessage(JSON.parse(body.toString("utf8")));
      } catch (err) {
        console.error("[native-host] failed to parse framed message:", err);
      }
    }
  });
}

function writeMessage(outputStream, message) {
  const json = Buffer.from(JSON.stringify(message), "utf8");
  const header = Buffer.alloc(4);
  header.writeUInt32LE(json.length, 0);
  outputStream.write(header);
  outputStream.write(json);
}

module.exports = { readMessages, writeMessage };
