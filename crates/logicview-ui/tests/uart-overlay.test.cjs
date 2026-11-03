const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const src = fs.readFileSync(path.join(__dirname, '../assets/app.js'), 'utf8');
const code = src.slice(src.indexOf('function dataLineTargets('), src.indexOf('function traceHexagon('));
test('translated UART overlay uses whole data annotations on RX/TX', () => {
  const decoder = {id:'u', protocol:'1:uart', channels:{rxtx:3}};
  const lanes = [{id:'rxtx', channel:'rxtx', classes:['data'], value_field:'value'}];
  const c = {state:{}, annotationLabel:r=>r.text, decoderLaneSpecs:()=>lanes};
  vm.createContext(c); vm.runInContext(code,c);
  const target = c.dataLineTargets(decoder)[0];
  assert.equal(target.channel,3);
  const rows = [{class:'data-bits',text:'1'}, {class:'data',text:'A5',fields:{value:'A5'}}, {class:'warnings',text:'Frame error'}];
  assert.deepEqual(Array.from(c.laneAnnotations(rows,target.lane,decoder), r=>r.text), ['A5']);
  assert.equal(c.laneValue(rows[1],decoder,target.lane),'A5');
});
test('decoded hover uses lane annotation classes rather than lane-named fields', async () => {
  const decoder = {id:'u', protocol:'1:uart', channels:{rxtx:3}};
  const lane = {id:'rxtx', channel:'rxtx', classes:['data'], value_field:'value'};
  const c = {state:{active:'s', hoverSequence:1, decoders:[decoder]}, pointer:null,
    FRAME_CLASS:new Set(['start','stop']), decoderLaneSpecs:()=>[lane],
    api:async()=>[{class:'data-bits',start_sample:10,end_sample:20},
      {class:'data',start_sample:10,end_sample:40,fields:{value:'A5'}},
      {class:'data',start_sample:50,end_sample:80,fields:{value:'42'}}]};
  vm.createContext(c); vm.runInContext(code,c);
  vm.runInContext(src.slice(src.indexOf('async function decodedHoverBounds('),src.indexOf('async function busHoverBounds(')),c);
  const result = await c.decodedHoverBounds({decoderId:'u', lane:'rxtx'},15,'s',1);
  assert.deepEqual({start:result.start,end:result.end,next:result.next},{start:10,end:40,next:50});
});
