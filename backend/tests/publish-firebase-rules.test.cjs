const {test}=require('node:test');
const assert=require('node:assert/strict');
const {publishRules}=require('../tools/publish-firebase-rules.cjs');
const previous={name:'projects/pharmawhisper-debd2/releases/cloud.firestore',rulesetName:'projects/pharmawhisper-debd2/rulesets/old'};
const next='projects/pharmawhisper-debd2/rulesets/new';
test('compiles immutable ruleset then publishes and confirms exact release',async()=>{
 let current=previous.rulesetName;const methods=[];
 const client={request:async req=>{
  methods.push(req.method||'GET');
  if(req.method==='POST'){assert.equal(req.data.source.files[0].content,'tested rules');return {data:{name:next}};}
  if(req.method==='PATCH'){assert.equal(req.data.release.name,previous.name);current=req.data.release.rulesetName;}
  return {data:{...previous,rulesetName:current}};
 }};
 assert.equal((await publishRules(client,previous,'tested rules')).rulesetName,next);
 assert.deepEqual(methods,['GET','POST','GET','PATCH','GET']);
});
test('compiler rejection never updates the production release',async()=>{
 let updates=0;
 const client={request:async req=>{
  if(req.method==='PATCH')updates++;
  if(req.method==='POST')throw Error('Invalid rules');
  return {data:previous};
 }};
 await assert.rejects(publishRules(client,previous,'bad'),/Invalid rules/);assert.equal(updates,0);
});
test('concurrent rule edits abort publication without overwriting them',async()=>{
 let gets=0,updates=0;
 const client={request:async req=>{
  if(req.method==='POST')return {data:{name:next}};
  if(req.method==='PATCH')updates++;
  gets++;return {data:{...previous,rulesetName:gets===1?previous.rulesetName:'someone-else'}};
 }};
 await assert.rejects(publishRules(client,previous,'tested'),/changed since backup/);assert.equal(updates,0);
});
