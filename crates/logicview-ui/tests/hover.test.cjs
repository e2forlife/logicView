const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
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
  vm.runInContext(hover, context);
  context.showHover = () => { shown = true; };
  const pending = context.runHover({ clientX: 25, clientY: 10 }, 1);
  context.hideHover();
  finish({ pulse_start: 0, pulse_end: 50, period_start: null, period_end: null });
  await pending;
  assert.equal(shown, false);
  assert.equal(context.state.hoverBounds, null);
});
