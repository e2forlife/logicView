const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../assets/app.js'), 'utf8');
function section(start, end) { return source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start) + start.length)); }

test('device scans add and remove pods and retain the last list on failure', async () => {
  let devices = [{ id: 'demo', kind: 'demo' }, { id: 'usb:1', kind: 'usb', name: 'Pod' }];
  const menu = { classList: { contains: () => false } };
  let renders = 0;
  const context = { state: { deviceList: [] }, api: async () => { if (!devices) throw Error('offline'); return devices; },
    document: { getElementById: (id) => id === 'device-menu' ? menu : null }, syncDeviceSelect() {}, renderDeviceMenu() { renders++; } };
  vm.createContext(context); vm.runInContext(section('let deviceScanInFlight', 'async function loadDeviceChoices'), context);
  await context.refreshDeviceList(); assert.equal(context.state.deviceList.length, 2);
  devices = [devices[0]]; await context.refreshDeviceList(); assert.equal(context.state.deviceList.length, 1);
  devices = null; await context.refreshDeviceList(); assert.equal(context.state.deviceList.length, 1); assert.equal(renders, 2);
});

test('pinch zoom preserves its anchor and supports the timebase minimum', () => {
  const v = { start: 100, spp: 1 };
  const context = { view: () => v, wave: { clientWidth: 1000 }, state: { total: 100000, rate: 1e9 }, TIME_DIVS: [1e-12],
    clampView() {}, scheduleTiles() {}, drawWave() {}, drawRuler() {}, drawOverview() {}, syncTimebaseLabel() {} };
  vm.createContext(context); vm.runInContext(section('function zoomAt(', 'wave.addEventListener("pointerdown"'), context);
  context.zoomAt(600, 500, 0.001);
  assert.equal(v.spp, 0.001); assert.equal(v.start + 500 * v.spp, 600);
  context.zoomAt(600, 500, 0.001); assert.equal(v.spp, 0.00001);
});

test('capture keeps the selected view and ruler centers labels with ticks', () => {
  const capture = section('async function runCapture()', 'function ');
  assert.match(capture, /view\(\)\.userNavigated = true/);
  const ruler = section('function drawRuler()', 'function drawWave(');
  assert.match(ruler, /textBaseline = "middle"/);
  assert.match(ruler, /minorStep = step \/ 5/);
});

