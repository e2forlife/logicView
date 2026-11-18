const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../assets/app.js'), 'utf8');
const code = source.slice(source.indexOf('let deviceScanInFlight'), source.indexOf('async function refreshDeviceList'));
const demo = { id: 'demo', kind: 'demo' };
const a = { id: 'usb:a', kind: 'usb' }, b = { id: 'usb:b', kind: 'usb' };
function setup(selected) {
  const chosen = [];
  const context = { state: { devices: selected, phase: 'stopped', profiles: [a, b].map(d => ({ id: d.id, hardware_tested: true })) }, commandBusy: false,
    isLive: phase => phase === 'running', statusEl: {}, useDevice: async id => { chosen.push(id); context.state.devices = [id === 'demo' ? demo : id === a.id ? a : b]; } };
  vm.createContext(context); vm.runInContext(code + '\ndeviceSelectionReady = true;', context);
  return { context, chosen };
}
test('removed selected pod selects another, then demo if none remain', async () => {
  const { context: c, chosen } = setup([a]);
  await c.reconcileDeviceSelection([a, b, demo], [b, demo]);
  await c.reconcileDeviceSelection([b, demo], [demo]);
  assert.deepEqual(chosen, ['usb:b', 'demo']);
});
test('new sole pod selects from demo; another available pod prevents switching', async () => {
  const { context: c, chosen } = setup([demo]);
  await c.reconcileDeviceSelection([a, demo], [a, b, demo]);
  assert.deepEqual(chosen, []);
  await c.reconcileDeviceSelection([demo], [a, demo]);
  assert.deepEqual(chosen, ['usb:a']);
});
test('selection waits for capture to stop and untested hardware is skipped', async () => {
  const { context: c, chosen } = setup([demo]);
  c.state.phase = 'running';
  await c.reconcileDeviceSelection([demo], [a, demo]);
  assert.deepEqual(chosen, []);
  c.state.phase = 'stopped';
  await c.reconcileDeviceSelection([a, demo], [a, demo]);
  assert.deepEqual(chosen, ['usb:a']);
  c.state.profiles = [];
  c.api = async () => [];
  await c.reconcileDeviceSelection([a, b, demo], [b, demo]);
  assert.deepEqual(chosen, ['usb:a', 'demo']);
});
