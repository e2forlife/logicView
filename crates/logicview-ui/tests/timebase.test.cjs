const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");

test("timebase reaches picosecond divisions at a 1 GHz sample rate", () => {
  const list = source.slice(source.indexOf("const TIME_DIVS"), source.indexOf("const MARKER_COLORS"));
  const apply = source.slice(source.indexOf("function applyTimebase("), source.indexOf("function bindSplitters("));
  const format = source.slice(source.indexOf("function formatDiv("), source.indexOf("function applyTimebase("));
  const seconds = source.slice(source.indexOf("function formatSeconds("), source.indexOf("function formatHz("));
  const v = { start: 0, spp: 1 };
  const label = {};
  const context = { state: { rate: 1e9 }, wave: { clientWidth: 1000 }, view: () => v,
    document: { getElementById: () => label }, clampView() {}, scheduleTiles() {}, drawWave() {}, drawRuler() {}, drawOverview() {} };
  vm.createContext(context); vm.runInContext(list + seconds + format + apply, context);
  context.applyTimebase(0);
  assert.ok(Math.abs(v.spp - 0.00001) < 1e-12);
  assert.equal(label.textContent, "1.0 ps/div");
  context.applyTimebase(9);
  assert.ok(Math.abs(v.spp - 0.01) < 1e-12);
  assert.equal(label.textContent, "1.0 ns/div");
});

test("ruler labels distinguish picoseconds and nanoseconds", () => {
  const code = source.slice(source.indexOf("function formatRulerTick("), source.indexOf("function formatHz("));
  const context = {}; vm.createContext(context); vm.runInContext(code, context);
  assert.equal(context.formatRulerTick(2e-12, 1e-12), "2 ps");
  assert.equal(context.formatRulerTick(2e-9, 1e-9), "2 ns");
  assert.equal(context.formatSeconds(1e-12), "1.0 ps");
});
