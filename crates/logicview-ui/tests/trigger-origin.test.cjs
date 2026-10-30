// Run with: node --test crates/logicview-ui/tests/trigger-origin.test.cjs
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const functions = source.slice(source.indexOf("function triggerOrigin()"), source.indexOf("function persistOrder("));

test("ruler zero uses the captured trigger, not the requested pre-trigger percentage", () => {
  const context = { state: { triggerSample: 250, total: 10000, rate: 1000 }, settings: { trigger: true, percent: 10 } };
  vm.createContext(context);
  vm.runInContext(functions, context);
  assert.equal(context.triggerOrigin(), 250);
  assert.equal(context.sampleSeconds(250), 0);
  assert.equal(context.sampleSeconds(150), -0.1);
  context.settings.percent = 50;
  context.settings.trigger = false;
  assert.equal(context.triggerOrigin(), 250);
});

test("an absent trigger uses capture start instead of a guessed position", () => {
  const context = { state: { triggerSample: null, total: 10000, rate: 1000 }, settings: { trigger: true, percent: 10 } };
  vm.createContext(context);
  vm.runInContext(functions, context);
  assert.equal(context.triggerOrigin(), 0);
  context.state.triggerSample = 0;
  assert.equal(context.triggerOrigin(), 0);
});
