import {test} from 'node:test';
import assert from 'node:assert/strict';
import {importHandler} from '../callable-handlers.mjs';
import {ImportError} from '../import-service.mjs';
const context = {auth:{uid:'fixture-admin'},app:{appId:'fixture-app'},data:{csv:'private-fixture'}};

test('callable adapter requires authenticated and verified-app contexts before any service access',async()=>{
  let called = false;
  const handler = importHandler({preview:async()=>{called=true;}},'preview');
  for (const request of [null,{}, {...context,auth:null}, {...context,auth:{}}]) {
    await assert.rejects(()=>handler(request),e=>e.code==='unauthenticated');
  }
  for (const app of [undefined,null,{}]) {
    await assert.rejects(()=>handler({...context,app}),e=>e.code==='failed-precondition');
  }
  assert.equal(called,false);
});
test('callable adapter forwards verified identity and confirmation without adding client roles',async()=>{
  for (const method of ['preview','commit']) {
    let received;
    const result={published:false,state:method==='preview'?'preview':'committed'};
    const handler=importHandler({[method]:async(auth,data)=>{received={auth,data};return result;}},method);
    assert.deepEqual(await handler(context),result);
    assert.deepEqual(received,{auth:context.auth,data:context.data});
  }
  assert.throws(()=>importHandler({},'deleteEverything'));
});
test('service authorization and validation codes map to callable errors without private details',async()=>{
  for (const [internal,external] of [['permission_denied','permission-denied'],['invalid_request','invalid-argument'],['feature_disabled','failed-precondition'],['batch_expired','failed-precondition']]) {
    const handler=importHandler({preview:async()=>{throw new ImportError(internal,{csv:'PRIVATE-CSV',correctOption:'A'});}},'preview');
    await assert.rejects(()=>handler(context),e=>e.code===external && !JSON.stringify(e).includes('PRIVATE-CSV') && Object.keys(e.details).length===0);
  }
});
test('CSV error response allows positions and machine codes while stripping payload fields',async()=>{
  const handler=importHandler({preview:async()=>{throw new ImportError('invalid_csv',{
    line:2,field:'correct_option',reason:'must_be_A_B_C_D',csv:'PRIVATE-CSV',question:'PRIVATE-STEM'});}},'preview');
  await assert.rejects(()=>handler(context),e=>e.code==='invalid-argument' && e.details.line===2 && e.details.field==='correct_option' && !JSON.stringify(e).includes('PRIVATE'));
});
test('unexpected service failures expose no stack connection strings or CSV',async()=>{
  const handler=importHandler({commit:async()=>{throw new Error('PRIVATE connection=secret');}},'commit');
  await assert.rejects(()=>handler(context),e=>e.code==='internal' && !e.message.includes('PRIVATE') && e.details===undefined);
});
