const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const paint = source.slice(source.indexOf("function paintStatus()"), source.indexOf("function renderTabs()"));
test("capture errors remain visible when the status is repainted", () => {
  const context = { state: { phase: "error", error: "sample transfer timed out" }, statusEl: {}, runBtn: {}, stopBtn: {}, commandBusy: false, settings: {}, document: { getElementById: () => null }, isLive: () => false };
  vm.createContext(context);
  vm.runInContext(paint, context);
  context.paintStatus();
  assert.equal(context.statusEl.textContent, "Error: sample transfer timed out");
  assert.equal(context.statusEl.title, "sample transfer timed out");
});
