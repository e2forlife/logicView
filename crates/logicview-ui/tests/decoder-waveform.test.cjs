const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");

test("SPI lanes have separate clock and chip-select rows with unique keys", () => {
  const state = { channels: [0, 1, 2, 3].map(index => ({ index, name: String(index), color: "white" })), decodeView: {}, spiView: {} };
  const context = { state, view: () => ({ colors: {} }), protocolLabel: () => "SPI", decodeFormat: () => "hex", decoderCondensed: () => false };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function logicRowModel("), source.indexOf("function displayRows()")), context);
  const rows = context.groupRows({ id: "spi1", protocol: "spi", channels: { sck: 0, mosi: 1, miso: 2, cs: 3 } }, []);
  assert.deepEqual(Array.from(rows, row => [row.kind, row.channel, row.lane]), [
    ["decode", 1, "mosi"], ["logic", 1, "mosi"], ["logic", 0, "mosi"], ["logic", 3, "mosi"],
    ["decode", 2, "miso"], ["logic", 0, "miso"], ["logic", 2, "miso"], ["logic", 3, "miso"],
  ]);
  assert.equal(new Set(rows.map(row => row.key)).size, rows.length);
  assert.equal(rows[2].tileKey, rows[5].tileKey);
  assert.equal(rows[3].tileKey, rows[7].tileKey);
});

test("waveform annotations follow the visible range and reject stale requests", async () => {
  let callback;
  const requests = [];
  const pending = [];
  const state = { active: "s", total: 100000, decoders: [{ id: "d" }], waveformAnnotations: [] };
  const v = { start: 20000, spp: 2 };
  const context = { state, view: () => v, wave: { clientWidth: 100 }, clearTimeout() {}, setTimeout(fn) { callback = fn; }, drawWave() {}, statusEl: {}, api(args) { requests.push(args); return new Promise(resolve => pending.push(resolve)); } };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("let waveformAnnotationTimer"), source.indexOf("async function loadAnnotations()")), context);
  context.scheduleWaveformAnnotations();
  const first = callback();
  assert.equal(requests[0].start, 20000);
  assert.equal(requests[0].end, 20200);
  v.start = 40000;
  context.scheduleWaveformAnnotations();
  const second = callback();
  pending[1]([{ decoder: "d", text: "new" }]);
  await second;
  pending[0]([{ decoder: "d", text: "old" }]);
  await first;
  assert.equal(state.waveformAnnotations[0].text, "new");
});


test("SPI disconnected lanes are omitted and remaining lanes fold independently", () => {
  const state = { channels: [0, 1, 2, 3].map(index => ({ index, name: String(index), color: "white" })), decodeView: { spi1: { lanes: { mosi: true, miso: false } } }, spiView: {} };
  const context = { state, view: () => ({ colors: {} }), protocolLabel: () => "SPI", decodeFormat: () => "hex", decoderCondensed: (id, lane) => !!state.decodeView[id].lanes[lane] };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function logicRowModel("), source.indexOf("function displayRows()")), context);
  const decoder = { id: "spi1", protocol: "spi", channels: { sck: 0, mosi: 1, miso: 2, cs: 3 } };
  const rows = context.groupRows(decoder, []);
  assert.equal(rows.filter(row => row.kind === "logic" && row.lane === "mosi").length, 0);
  assert.equal(rows.filter(row => row.kind === "logic" && row.lane === "miso").length, 3);
  delete decoder.channels.mosi;
  const remaining = context.groupRows(decoder, []);
  assert.deepEqual(Array.from(remaining.filter(row => row.kind === "decode"), row => row.lane), ["miso"]);
  delete decoder.channels.miso;
  assert.equal(context.groupRows(decoder, []).length, 0);
});
