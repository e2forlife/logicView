const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../assets/app.js'), 'utf8');
const script = source.slice(source.indexOf('function dataLineTargets('), source.indexOf('function traceHexagon('));
test('WS2812 overlay formats each byte in the selected base', () => {
  const decoder = { id:'led', protocol:'rgb_led_ws281x', channels:{din:5} };
  const lane = {id:'color', channel:'din', channels:['din'], classes:['byte'], value_field:'value'};
  let format = "hex";
  const context = {state:{}, annotationLabel: row => row.text, decoderLaneSpecs:()=>[lane], decodeFormat:()=>format};
  vm.createContext(context); vm.runInContext(script + source.slice(source.indexOf("function formatDecoded("), source.indexOf("function drawStepSeries(")), context);
  const target = context.dataLineTargets(decoder)[0];
  assert.equal(target.channel, 5);
  const rows = [{class:'bit',text:'1'}, {class:'rgb',text:'GRB#123456',fields:{value:'123456'}},
    ...['12','34','56'].map(value => ({class:'byte',text:value,fields:{value}}))];
  const bytes = context.laneAnnotations(rows, target.lane, decoder);
  assert.deepEqual(Array.from(bytes, row => row.text), ['12','34','56']);
  for (const [selected, expected] of [["hex", ["0x12","0x34","0x56"]], ["dec", ["18","52","86"]], ["oct", ["22","64","126"]], ["bin", ["00010010","00110100","01010110"]]]) {
    format = selected;
    assert.deepEqual(Array.from(bytes, row => target.label(row)), expected);
    assert.deepEqual(Array.from(bytes, row => context.laneLabel(row, selected, 'color', decoder)), expected);
  }
});

test('waveform excludes WS2812 bit annotations even without lane metadata', () => {
  const decoder = { id:'led', protocol:'rgb_led_ws281x', channels:{din:5} };
  const bit = {decoder:'led', class:'bit', text:'1'};
  const byte = {decoder:'led', class:'byte', text:'12', fields:{value:'12'}};
  const color = {decoder:'led', class:'rgb', text:'GRB#123456'};
  const context = {state:{waveformAnnotations:[bit, byte, color]}, FRAME_CLASS:new Set(['start','stop'])};
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf('function valueAnnotations('), source.indexOf('function annotationLabel(')), context);
  assert.deepEqual(Array.from(context.valueAnnotations(decoder), row => row.class), ['byte']);
  context.state.waveformAnnotations = [bit, color];
  assert.equal(context.valueAnnotations(decoder).length, 0);
  // Annotation data remains available to the decode table.
  assert.equal(context.state.waveformAnnotations.length, 2);
});
test('rendered WS2812 overlay contains only complete bytes', () => {
  const decoder = {id:'led', protocol:'rgb_led_ws281x', channels:{din:5}};
  const annotations = [{decoder:'led', class:'bit', text:'1'}, {decoder:'led', class:'byte', text:'71', fields:{value:'71'}}, {decoder:'led', class:'rgb', text:'GRB#712300'}];
  const rendered = [];
  const item = {row:{color:'#fff'},top:0,height:50};
  const context = {state:{decoders:[decoder],waveformAnnotations:annotations},FRAME_CLASS:new Set(),
    overlayEnabled:()=>true, dataLineTargets:()=>[{channel:5,lane:'color',label:r=>r.text}],
    decoderCondensed:()=>false, logicRow:()=>item, traceColor:c=>c,
    laneAnnotations: rows=>rows, drawHexagons:(_ctx,rows)=>rendered.push(...rows),
    ctx:{save(){},restore(){}}};
  vm.createContext(context);
  vm.runInContext(source.slice(source.indexOf('function valueAnnotations('),source.indexOf('function annotationLabel(')) + source.slice(source.indexOf('function drawDecodeOverlay('),source.indexOf('function annotationNumbers(')),context);
  context.drawDecodeOverlay(context.ctx, 100, {layout:[item]});
  assert.deepEqual(rendered.map(row=>row.class), ['byte']);
});
