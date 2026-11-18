const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");

test("bus navigation chooses the nearest transition across all members", async () => {
  let centered;
  const context = { state: { total: 100, active: "s", hoverX: null }, view: () => ({ start: 0, spp: 1 }), wave: { clientWidth: 20 }, descendantChannels: () => [1, 2], api: async ({channel, rising}) => ({ sample: channel === 1 ? (rising ? 30 : 20) : (rising ? 15 : 25) }), centerOn: sample => { centered = sample; }, statusEl: {} };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("async function stepDataChange("), source.indexOf("async function dropCursor(")), context);
  await context.stepDataChange(true, {kind: "bus", bus: {}});
  assert.equal(centered, 15);
});

test("decoder navigation uses lane-filtered span boundaries outside the viewport", async () => {
  let centered;
  const state = { total: 200, active: "s", hoverX: null, decoders: [{ id: "d", protocol: "p" }] };
  const context = { state, view: () => ({ start: 45, spp: 1 }), wave: { clientWidth: 10 }, FRAME_CLASS: new Set(["frame"]), laneAnnotations: rows => rows.filter(row => row.class === "data"), api: async () => [{class: "frame", start_sample: 1, end_sample: 100}, {class: "data", start_sample: 20, end_sample: 40}, {class: "data", start_sample: 80, end_sample: 90}], centerOn: sample => { centered = sample; }, statusEl: {} };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("async function stepDataChange("), source.indexOf("async function dropCursor(")), context);
  await context.stepDataChange(true, {kind: "decode", decoderId: "d", lane: "data"});
  assert.equal(centered, 80);
  await context.stepDataChange(false, {kind: "decode", decoderId: "d", lane: "data"});
  assert.equal(centered, 40);
});

test("data rows draw a center line in gaps and center labels; overlays do neither", () => {
  const lines = [], labels = [];
  const ctx = { save() {}, restore() {}, beginPath() {}, closePath() {}, moveTo(x,y) { lines.push(["move",x,y]); }, lineTo(x,y) { lines.push(["line",x,y]); }, fill() {}, stroke() {}, rect() {}, clip() {}, fillText(text,x) { labels.push([text,x,this.textAlign]); }, measureText: () => ({width: 10}) };
  const context = { sampleX: x => x, traceColor: c => c, lightTheme: () => false, wavePalette: () => ({ink: "black"}) };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function traceHexagon("), source.indexOf("function drawDecodeOverlay(")), context);
  const rows = [{start_sample: 20, end_sample: 80}];
  context.drawHexagons(ctx, rows, 0, 20, "blue", 100, () => "A", 0.82, true);
  assert.ok(lines.some(v => v[0] === "move" && v[1] === 0 && v[2] === 10));
  assert.deepEqual(labels[0], ["A", 50, "center"]);
  lines.length = 0; labels.length = 0;
  context.drawHexagons(ctx, rows, 0, 20, "blue", 100, () => "A");
  assert.ok(!lines.some(v => v[0] === "move" && v[1] === 0 && v[2] === 10));
  assert.equal(labels[0][2], "left");
});
