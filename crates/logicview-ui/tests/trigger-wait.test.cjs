const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const src=fs.readFileSync(path.join(__dirname,'../assets/app.js'),'utf8');
const html=fs.readFileSync(path.join(__dirname,'../assets/index.html'),'utf8');
test('trigger wait displays cancel and stopping does not show a false trigger',()=>{
  const dialog={className:''}, label={textContent:''}, arc={style:{}};
  const state={phase:'waiting_trigger',waitKind:'',planned:100,total:0};
  const context={state,settings:{depth:'buffer'},document:{getElementById:id=>({'capture-wait':dialog,'wait-text':label,'wait-arc':arc})[id]}, setTimeout(){},clearTimeout(){}};
  vm.createContext(context); vm.runInContext(src.slice(src.indexOf('let triggeredTimer = null;'),src.indexOf('let editingGroupId = null;')),context);
  context.paintWait(); assert.equal(label.textContent,'Waiting for trigger'); assert.equal(dialog.className,'wait-dialog waiting');
  state.phase='stopping'; context.paintWait(); assert.equal(dialog.className,'wait-dialog hidden');
  state.phase='stopped'; context.paintWait(); assert.equal(dialog.className,'wait-dialog hidden');
  assert.match(html, /id="wait-cancel"/); assert.match(src, /getElementById\("wait-cancel"\)\.addEventListener\("click", \(\) => stopCapture\(\)\)/);
});
