const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const nearest = source.slice(source.indexOf("async function nearestRowEdge("), source.indexOf("// A decoder row represents annotation spans"));
const hover = source.slice(source.indexOf("async function runHover("), source.indexOf("function setTool("));
test("leaving the waveform invalidates a pending measurement response", async () => {
  let finish;
  let shown = false;
  const request = new Promise((resolve) => { finish = resolve; });
  const context = {
    state: { active: "session", total: 100, hoverSequence: 1, hidden: new Set(), hoverBounds: null },
    wave: { getBoundingClientRect: () => ({ left: 0, top: 0, width: 100 }) },
    rowMetrics: () => ({ layout: [{}] }), rowAt: () => ({ kind: "logic", key: "D0", channel: 0 }),
    traceEndX: () => 100, view: () => ({ start: 0, spp: 1 }), api: () => request,
    hoverEl: { classList: { add() {} } }, hoverTimer: null, clearTimeout, pointer: null,
    paintStatus() {}, drawWave() {}, document: { getElementById: () => null },
  };
  vm.createContext(context);
  context.preferences = { edge_snap: true };
  vm.runInContext(nearest, context);
  vm.runInContext(hover, context);
  context.showHover = () => { shown = true; };
  const pending = context.runHover({ clientX: 25, clientY: 10 }, 1);
  context.hideHover();
  finish({ pulse_start: 0, pulse_end: 50, period_start: null, period_end: null });
  await pending;
  assert.equal(shown, false);
  assert.equal(context.state.hoverBounds, null);
});

test("hover locks to the nearest edge and measures at that edge", async () => {
  const calls = [];
  const state = { active: "session", total: 100, rate: 1000, hoverSequence: 1, hidden: new Set(), hoverBounds: null };
  const context = { state, wave: { getBoundingClientRect: () => ({ left: 0, top: 0, width: 100 }) },
    rowMetrics: () => ({ layout: [{}] }), rowAt: () => ({ kind: "logic", key: "D0", channel: 0, name: "D0" }),
    traceEndX: () => 100, view: () => ({ start: 0, spp: 1 }), pointer: null,
    api: async req => { calls.push(req); return req.cmd === "nearest_edge" ? {sample: 20} : {level_high: true, width_secs: 0.01, period_secs: null, frequency_hz: null, duty: null}; },
    drawWave() {}, formatSeconds: String, formatHz: String, document: { getElementById: () => null },
  };
  vm.createContext(context);
  context.preferences = { edge_snap: true };
  vm.runInContext(nearest, context);
  vm.runInContext(hover, context);
  context.showHover = () => {};
  await context.runHover({ clientX: 25, clientY: 10 }, 1);
  assert.equal(state.hoverSnap.sample, 20);
  assert.equal(calls[1].sample, 20);
  assert.equal(state.lastMeasure.sample, 20);
});

test("an outdated nearest-edge response cannot move the cursor", async () => {
  let finish;
  const state = { active: "session", total: 100, hoverSequence: 1, hidden: new Set(), hoverSnap: { key: "D0", sample: 10 } };
  const context = { state, wave: { getBoundingClientRect: () => ({ left: 0, top: 0, width: 100 }) },
    rowMetrics: () => ({ layout: [{}] }), rowAt: () => ({ kind: "logic", key: "D0", channel: 0 }),
    traceEndX: () => 100, view: () => ({ start: 0, spp: 1 }), pointer: null,
    api: () => new Promise(resolve => { finish = resolve; }), drawWave() {} };
  vm.createContext(context);
  context.preferences = { edge_snap: true };
  vm.runInContext(nearest, context);
  vm.runInContext(hover, context);
  const pending = context.runHover({ clientX: 25, clientY: 10 }, 1);
  state.hoverSequence++;
  finish({ sample: 20 });
  await pending;
  assert.equal(state.hoverSnap.sample, 10);
});

test("bus snapping selects the closest member transition", async () => {
  const context = { descendantChannels: () => [0, 1], api: async ({channel}) => ({sample: channel ? 21 : 15}) };
  vm.createContext(context);
  vm.runInContext(nearest, context);
  const result = await context.nearestRowEdge({kind: "bus", bus: {}}, 20, "session");
  assert.equal(result.sample, 21);
});

test("decoder snapping requests only the selected lane's boundaries", async () => {
  let request;
  const context = { state: {decoders: [{id: "d", protocol: "spi"}]},
    decoderLaneSpecs: () => [{id: "miso", classes: ["word"], value_field: "miso"}],
    api: async args => {request = args; return {sample: 42};} };
  vm.createContext(context);
  vm.runInContext(nearest, context);
  const result = await context.nearestRowEdge({kind: "decode", decoderId: "d", lane: "miso"}, 40, "session");
  assert.equal(result.sample, 42);
  assert.equal(request.cmd, "nearest_annotation_boundary");
  assert.equal(request.value_field, "miso");
  assert.equal(request.classes[0], "word");
});

test("disabled snapping measures at the pointer without an edge lookup", async () => {
  const calls = [];
  const state = { active: "session", total: 100, rate: 1000, hoverSequence: 1, hidden: new Set(), hoverSnap: null };
  const context = { state, preferences: {edge_snap: false}, wave: { getBoundingClientRect: () => ({left: 0, top: 0, width: 100}) },
    rowMetrics: () => ({layout: [{}]}), rowAt: () => ({kind: "logic", key: "D0", channel: 0, name: "D0"}),
    traceEndX: () => 100, view: () => ({start: 0, spp: 1}), pointer: null,
    api: async req => { calls.push(req); return {level_high: true, width_secs: 0.01, period_secs: null, frequency_hz: null, duty: null}; },
    drawWave() {}, formatSeconds: String, formatHz: String, document: {getElementById: () => null} };
  vm.createContext(context);
  vm.runInContext(nearest, context);
  vm.runInContext(hover, context);
  context.showHover = () => {};
  await context.runHover({clientX: 25, clientY: 10}, 1);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].cmd, "measure");
  assert.equal(calls[0].sample, 25);
  assert.equal(state.hoverSnap, null);
});
