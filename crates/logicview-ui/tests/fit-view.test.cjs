const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const fit = source.slice(source.indexOf("function fitView()"), source.indexOf("function clampView()"));
test("fit view shows a full four million sample capture", () => {
  const v = {};
  const context = { state: { total: 4_000_000 }, wave: { clientWidth: 1000 }, view: () => v };
  vm.createContext(context);
  vm.runInContext(fit, context);
  context.fitView();
  assert.equal(v.start, 0);
  assert.equal(v.spp * context.wave.clientWidth, context.state.total);
});
