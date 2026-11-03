const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const src = fs.readFileSync(path.join(__dirname, '../assets/app.js'), 'utf8');
const part = (a,b) => src.slice(src.indexOf(a), src.indexOf(b, src.indexOf(a) + a.length));

test('renamed channels show device-local probe numbers even with sparse capture channels', () => {
  const probes = [{index:0,name:'D0',device_name:'Plus',device_id:'a'}, {index:1,name:'D1',device_name:'Plus',device_id:'a'},
    {index:2,name:'U3 D0',device_name:'U3',device_id:'b'}, {index:3,name:'U3 D1',device_name:'U3',device_id:'b'}];
  const c = {state:{probes}}; vm.createContext(c);
  vm.runInContext(part('function probeForRow(', 'function maskBit(') + part('function localProbeIndex(', 'function deviceTag(') + part('function originalChannelNumber(', 'function startRename('), c);
  assert.equal(c.originalChannelNumber({name:'U3 D1',device:'U3',channel:1}),1);
  assert.equal(c.originalChannelNumber({name:'Plus D12',device:'Plus',channel:0}),12);
});

test('clearing a renamed channel restores the original name', () => {
  const row = {kind:'logic',key:'logic:0',name:'D0'};
  const v = {names:{'logic:0':'Clock'}}; let input;
  const c = {state:{}, view:()=>v, renderGutter(){}, document:{createElement(){return input={handlers:{},setAttribute(){},focus(){},select(){},addEventListener(k,f){this.handlers[k]=f;}};}}};
  vm.createContext(c); vm.runInContext(part('function signalName(', 'function eyeIcon('),c);
  c.startRename(row,{replaceWith(){}}); input.value='  '; input.handlers.blur();
  assert.equal(c.signalName(row),'D0');
});
