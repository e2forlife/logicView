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
