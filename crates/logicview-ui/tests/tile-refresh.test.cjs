const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const fetchCode = source.slice(source.indexOf("async function fetchTiles()"), source.indexOf("function onTileFrame("));

test("zoom refreshes available channels when another channel has no capture data", async () => {
  const view = { start: 0, spp: 10 };
  const state = {
    active: "session", req: 0,
    tiles: { "logic:0": ["old"], "logic:1": ["old"] },
    tileView: { start: 50, spp: 1, width: 100 },
  };
  let draws = 0;
  const context = {
    state, view: () => view, wave: { clientWidth: 100 }, socket: null,
    pointer: null, tileAgain: false,
    tileRequests: () => [0, 1].map(channel => ({ row: { kind: "logic", channel }, key: `logic:${channel}` })),
    api: async body => {
      if (body.channel === 1) throw new Error("channel not captured");
      return { columns: ["refreshed"] };
    },
    drawWave: () => draws++, drawRuler() {}, scheduleViewPaint() {},
  };
  vm.createContext(context);
  vm.runInContext(fetchCode, context);
  await context.fetchTiles();
  assert.equal(state.tiles["logic:0"][0], "refreshed");
  assert.equal(state.tiles["logic:1"], undefined);
  assert.equal(state.tileView.spp, 10);
  assert.equal(draws, 1);
});

test("tile requests buffer both sides and cover a drag without refetching", async () => {
  const v = { start: 200, spp: 2 };
  const state = { active: "session", req: 0, tiles: {}, tileView: null };
  let body;
  const context = {
    state, view: () => v, wave: { clientWidth: 100 }, socket: null,
    pointer: { kind: "pan" }, tileAgain: false,
    tileRequests: () => [{ row: { kind: "logic", channel: 0 }, key: "logic:0" }],
    api: async request => { body = request; v.start = 240; return { columns: ["data"] }; },
    drawWave() {}, drawRuler() {}, scheduleViewPaint() {},
  };
  vm.createContext(context);
  vm.runInContext(fetchCode, context);
  await context.fetchTiles();
  assert.equal(body.start, 100);
  assert.equal(body.columns, 200);
  assert.equal(context.tileCoversView(state.tileView, v.start, v.spp, 100), true);
  assert.equal(context.tileAgain, false);
  assert.equal(context.tileCoversView(state.tileView, 301, v.spp, 100), false);
});

test("a missing tile does not cause an endless retry", async () => {
  const v = { start: 200, spp: 1 };
  const state = { active: "session", req: 0, tiles: {}, tileView: null };
  const context = { state, view: () => v, wave: { clientWidth: 100 }, socket: null,
    pointer: null, tileAgain: false,
    tileRequests: () => [{ row: { kind: "logic", channel: 0 }, key: "logic:0" }],
    api: async () => { throw new Error("no data"); }, drawWave() {}, drawRuler() {}, scheduleViewPaint() {} };
  vm.createContext(context);
  vm.runInContext(fetchCode, context);
  await context.fetchTiles();
  assert.equal(context.tileAgain, false);
});
