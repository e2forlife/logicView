const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const helpers = source.slice(source.indexOf("async function decodedHoverBounds("), source.indexOf("async function runHover("));

test("decoded hover uses data boundaries and the next item, including outside the viewport", async () => {
  const calls = [];
  const context = { state: { active: "s", hoverSequence: 1 }, pointer: null, FRAME_CLASS: new Set(["select"]), api: async request => {
    calls.push(request);
    return [
      { class: "select", start_sample: 0, end_sample: 90 },
      { class: "word", start_sample: 10, end_sample: 20, fields: { mosi: "A5" } },
      { class: "word", start_sample: 35, end_sample: 42, fields: { mosi: "FF" } },
    ];
  } };
  vm.createContext(context); vm.runInContext(helpers, context);
  const bounds = await context.decodedHoverBounds({ decoderId: "d", lane: "mosi" }, 15, "s", 1);
  assert.deepEqual({ ...bounds }, { start: 10, end: 20, next: 35 });
  assert.equal(calls[0].start, 15);
  assert.equal(calls[0].end, undefined);
  assert.equal(await context.decodedHoverBounds({ decoderId: "d", lane: "miso" }, 15, "s", 1), null);
  assert.equal(await context.decodedHoverBounds({ decoderId: "d", lane: "mosi" }, 25, "s", 1), null);
});

test("bus hover measures the combined value rather than one input", async () => {
  const context = { state: { total: 100 }, api: async ({ channel }) => channel === 1
    ? { pulse_start: 10, pulse_end: 40 } : { pulse_start: 20, pulse_end: 30 } };
  vm.createContext(context); vm.runInContext(helpers, context);
  const bounds = await context.busHoverBounds({ bus: { channels: [1, 2] } }, 25, "s");
  assert.deepEqual({ ...bounds }, { start: 20, end: 30, next: 30 });
});
