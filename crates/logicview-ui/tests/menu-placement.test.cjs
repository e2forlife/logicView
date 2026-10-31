const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../assets/app.js"), "utf8");
const code = source.slice(source.indexOf("function placeViewportMenu("), source.indexOf("function placeSubmenu("));

test("menus are kept inside the viewport at every edge", () => {
  const context = { window: { innerWidth: 800, innerHeight: 600 } };
  vm.createContext(context);
  vm.runInContext(code, context);
  const menu = { offsetWidth: 220, offsetHeight: 180, style: {} };
  context.placeViewportMenu(menu, 790, 590);
  assert.equal(menu.style.left, "572px");
  assert.equal(menu.style.top, "412px");
  context.placeViewportMenu(menu, -30, -20);
  assert.equal(menu.style.left, "8px");
  assert.equal(menu.style.top, "8px");
});
