const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const spiLanes = [
  { id: "mosi", name: "MOSI", channel: "mosi", channels: ["mosi", "sck", "cs"], classes: ["word"], value_field: "mosi" },
  { id: "miso", name: "MISO", channel: "miso", channels: ["sck", "miso", "cs"], classes: ["word"], value_field: "miso" },
];

test("colors selected for decoder group headers and their signals survive row rebuilding", () => {
  const v = { colors: {} };
  const state = { gutterSig: "old" };
  const fly = { classList: { contains: () => true } };
  const context = { state, view: () => v, decodeShownAnalog: () => false,
    laneColor: channel => context.storedColor("logic:" + channel, "#112233"),
    persistColors() {}, renderGutter() {}, drawWave() {},
    document: { querySelector: () => null, getElementById: () => fly },
  };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function logicRowModel("), source.indexOf("function persistColors(")), context);
  vm.runInContext(source.slice(source.indexOf("function decodeBusRow("), source.indexOf("function groupRows(")), context);
  let rows = [];
  context.orderedRows = () => rows;
  vm.runInContext(source.slice(source.indexOf("function setChannelColor("), source.indexOf("function fillColorSwatches(")), context);
  const signal = { index: 2, name: "Data", color: "#112233" };
  const decoder = { id: "decoder-1" };
  const lane = { id: "data", name: "Data", channel: 2 };
  rows = [context.decodeBusRow(decoder, lane, true), context.logicRowModel(signal, decoder.id, lane.id)];
  context.setChannelColor(rows[0].key, "#aabbcc");
  context.setChannelColor(rows[1].key, "#445566");
  assert.equal(context.decodeBusRow(decoder, lane, true).color, "#aabbcc");
  assert.equal(context.logicRowModel(signal, decoder.id, lane.id).color, "#445566");
  assert.equal(context.logicRowModel(signal, "").color, "#445566");
});

test("Lua overlays use declared input order and stacked decoders use their parent waveform", () => {
  const parent = { id: "p", protocol: "lua", channels: { clock: 1, data: 3 } };
  const child = { id: "c", protocol: "child", channels: {}, stack_on: "p" };
  const state = { decoders: [parent, child], decoderCatalog: [{ id: "lua", channels: ["data"], optional_channels: ["clock"] }] };
  const context = { state, annotationLabel: row => row.text, decoderLaneSpecs: () => [] };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function dataLineTargets("), source.indexOf("function traceHexagon(")), context);
  assert.equal(context.dataLineTargets(parent)[0].channel, 3);
  assert.equal(context.dataLineTargets(child)[0].channel, 3);
  assert.equal(context.dataLineTargets(child)[0].decoderId, "p");
});

test("adding a decoder from a waveform binds its first declared input", async () => {
  let request, configured;
  const state = { active: "s", decoders: [], decoderCatalog: [{ id: "lua", channels: ["data", "clock"] }] };
  const context = { state, api: async args => { request = args; return { id: "new" }; }, refreshDecoders: async () => { state.decoders = [{ id: "new", channels: {} }]; }, openDecodeConfig: decoder => { configured = decoder; }, loadAnnotations: async () => {}, paintStatus() {}, statusEl: {} };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("async function addDecoder("), source.indexOf("async function refreshDecoders(")), context);
  await context.addDecoder("lua", 4);
  assert.equal(Object.keys(request.channels).length, 0);
  assert.equal(configured.channels.data, 4);
});

test("waveform decoder dialog filters choices and keeps the clicked channel", () => {
  function element() {
    return { children: [], classList: { hidden: true, add() { this.hidden = true; }, remove() { this.hidden = false; } }, replaceChildren() { this.children = []; }, append(child) { this.children.push(child); }, querySelectorAll() { return this.children; }, addEventListener(name, fn) { this[name] = fn; }, focus() {} };
  }
  const dialog = element(), list = element(), search = element();
  const elements = { "signal-decoder-dialog": dialog, "signal-decoder-list": list, "signal-decoder-search": search };
  let selected;
  const state = { decoderCatalog: [{ id: "spi", name: "SPI", channels: ["clk"] }, { id: "uart", name: "UART", channels: ["rx"] }, { id: "stack", stack_on: "spi", channels: [] }] };
  const context = { state, document: { getElementById: id => elements[id], createElement: element }, decoderMatches: (item, text) => item.name.toLowerCase().includes(text.toLowerCase()), addDecoder: (id, channel) => { selected = [id, channel]; } };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function openSignalDecoderDialog("), source.indexOf("function openContainerMenu(")), context);
  context.openSignalDecoderDialog({ channel: 7 });
  assert.equal(dialog.classList.hidden, false);
  assert.equal(list.children.length, 2);
  search.value = "uart";
  search.oninput();
  assert.equal(list.children[0].hidden, true);
  assert.equal(list.children[1].hidden, false);
  list.children[1].click();
  assert.deepEqual(selected, ["uart", 7]);
  assert.equal(dialog.classList.hidden, true);
});

test("SPI lanes have separate clock and chip-select rows with unique keys", () => {
  const state = { channels: [0, 1, 2, 3].map(index => ({ index, name: String(index), color: "white" })), decodeView: {}, spiView: {}, decoderCatalog: [{ id: "spi", lanes: spiLanes }] };
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
  const state = { channels: [0, 1, 2, 3].map(index => ({ index, name: String(index), color: "white" })), decodeView: { spi1: { lanes: { mosi: true, miso: false } } }, spiView: {}, decoderCatalog: [{ id: "spi", lanes: spiLanes }] };
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


test("translated SPI lanes route only their own data to the data channels", () => {
  const decoder = { id: "lua", protocol: "1:spi", channels: { clk: 0, mosi: 1, miso: 2 } };
  const state = { channels: [0, 1, 2].map(index => ({ index, name: String(index), color: "white" })), decodeView: {}, spiView: {}, decoderCatalog: [{ id: "1:spi", lanes: [
    { id: "mosi", name: "MOSI", channel: "mosi", channels: ["mosi", "clk"], classes: ["mosi-data"], value_field: "value" },
    { id: "miso", name: "MISO", channel: "miso", channels: ["clk", "miso"], classes: ["miso-data"], value_field: "value" },
  ] }], decoders: [decoder] };
  const context = { state, view: () => ({ colors: {} }), protocolLabel: () => "SPI", decodeFormat: () => "hex", decoderCondensed: () => false, annotationLabel: row => row.text };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function logicRowModel("), source.indexOf("function displayRows()")), context);
  vm.runInContext(source.slice(source.indexOf("function dataLineTargets("), source.indexOf("function traceHexagon(")), context);
  const groups = context.groupRows(decoder, []);
  assert.deepEqual(Array.from(groups.filter(row => row.kind === "decode"), row => [row.lane, row.channel]), [["mosi", 1], ["miso", 2]]);
  assert.deepEqual(Array.from(context.dataLineTargets(decoder), target => target.channel), [1, 2]);
  const rows = [{ class: "mosi-data", text: "@A5", fields: { value: "A5" } }, { class: "miso-data", text: "@3C", fields: { value: "3C" } }, { class: "mosi-bits", text: "1" }];
  assert.deepEqual(Array.from(context.laneAnnotations(rows, "mosi", decoder), row => row.text), ["@A5"]);
  assert.deepEqual(Array.from(context.laneAnnotations(rows, "miso", decoder), row => row.text), ["@3C"]);
});


test("custom decoder lanes control grouping, filtering, and numeric values", () => {
  const decoder = { id: "d", protocol: "custom", channels: { clock: 0, outbound: 1, inbound: 2 } };
  const specs = [{ id: "send", name: "Send", channel: "outbound", channels: ["clock", "outbound"], classes: ["transmit"], value_field: "payload" }, { id: "receive", name: "Receive", channel: "inbound", channels: ["inbound", "clock"], classes: ["reply"] }];
  const state = { channels: [0, 1, 2].map(index => ({ index, name: String(index), color: "white" })), decoderCatalog: [{ id: "custom", lanes: specs }], decoders: [decoder], decodeView: {}, spiView: {} };
  const context = { state, view: () => ({ colors: {} }), protocolLabel: () => "custom", decodeFormat: () => "hex", decoderCondensed: () => false, annotationLabel: row => row.text };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function logicRowModel("), source.indexOf("function displayRows()")), context);
  vm.runInContext(source.slice(source.indexOf("function dataLineTargets("), source.indexOf("function traceHexagon(")), context);
  const groups = context.groupRows(decoder, []);
  assert.deepEqual(Array.from(groups.filter(row => row.kind === "decode"), row => [row.lane, row.channel]), [["send", 1], ["receive", 2]]);
  const rows = [{ class: "transmit", fields: { payload: "A5" } }, { class: "reply", text: "OK" }];
  assert.equal(context.laneAnnotations(rows, "send", decoder)[0], rows[0]);
  assert.equal(context.laneAnnotations(rows, "receive", decoder)[0], rows[1]);
  assert.equal(context.laneValue(rows[0], decoder, "send"), "A5");
  assert.equal(context.dataLineTargets(decoder)[1].channel, 2);
  delete decoder.channels.inbound;
  assert.equal(context.groupRows(decoder, []).filter(row => row.kind === "decode").length, 1);
});


test("decoder progress remains visible during status refresh", () => {
  const context = { state: { phase: "stopped", decoderBusy: 1 }, statusEl: {}, runBtn: {}, stopBtn: {}, commandBusy: false, settings: {}, document: { getElementById: () => null }, isLive: () => false, paintRunIcon() {} };
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf("function paintStatus()"), source.indexOf("let sessionRename")), context);
  context.paintStatus();
  assert.match(context.statusEl.textContent, /Applying decoder annotations/);
  context.state.error = "capture failed";
  context.paintStatus();
  assert.equal(context.statusEl.textContent, "Error: capture failed");
});
