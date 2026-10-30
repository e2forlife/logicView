const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('crates/logicview-ui/assets/app.js', 'utf8');
const add = source.slice(source.indexOf('async function addDecoder('), source.indexOf('async function refreshDecoders('));

test('adding a decoder opens configuration with no assumed channel names', async () => {
  const calls = [];
  const context = {
    state: { active: 'session', decoders: [] },
    api: async (request) => { calls.push(request); return { id: 'spi-1' }; },
    refreshDecoders: async () => { context.state.decoders = [{ id: 'spi-1', protocol: 'spi', channels: {} }]; },
    openDecodeConfig: (decoder) => calls.push(decoder),
    loadAnnotations: async () => {}, statusEl: { textContent: '' },
  };
  vm.createContext(context);
  vm.runInContext(add, context);
  await context.addDecoder('spi');
  assert.equal(Object.keys(calls[0].channels).length, 0);
  assert.equal(calls[1].id, 'spi-1');
  assert.equal(context.statusEl.textContent, '');
});
