import {before,beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {QuizImportService,ImportError,validateCsv} from '../import-service.mjs';
import {expireImportPreviews} from '../preview-retention.mjs';

const host=process.env.FIRESTORE_EMULATOR_HOST;
if(!host||!/^127\.0\.0\.1:\d+$/.test(host))throw new Error('Local emulator required; production forbidden.');
const projectId='demo-hyzen-backend';
const app=initializeApp({projectId},'hyzen-import-tests');const db=getFirestore(app);
let now=Date.parse('2026-10-25T10:00:00Z');
const service=new QuizImportService(db,{adminUids:['fixture-admin','other-admin'],now:()=>now});
const admin={uid:'fixture-admin',token:{email:'admin@example.test'}};
const taxonomy=()=>({schema_version:1,version:'fixture-v1',approved:true,years:{'1':{subjects:{'fixture-subject':{topics:['fixture-topic']}}}}});
const header='question_id,professional_year,subject,topic,question,option_a,option_b,option_c,option_d,correct_option,explanation,difficulty,status';
const row=(id='fixture-1',changes={})=>({question_id:id,professional_year:'1',subject:'fixture-subject',topic:'fixture-topic',question:'SECRET-FIXTURE stem, two\nlines',option_a:'CHOICE-A',option_b:'CHOICE-B',option_c:'CHOICE-C',option_d:'CHOICE-D',correct_option:'B',explanation:'PRIVATE-EXPLANATION',difficulty:'easy',status:'draft',...changes});
const csv=rows=>header+'\r\n'+rows.map(r=>header.split(',').map(k=>'"'+String(r[k]??'').replaceAll('"','""')+'"').join(',')).join('\r\n');
const count=async name=>(await db.collection(name).get()).size;
const preview=async rows=>service.preview(admin,{csv:csv(rows)});
const confirm=p=>({batchId:p.batchId,checksum:p.checksum,idempotencyKey:'confirmation_fixture_0001'});
const rejects=async(action,code)=>assert.rejects(action,error=>error instanceof ImportError&&error.code===code);
async function enable(){await db.doc('quiz_control/import').set({enabled:true,taxonomyVersion:'fixture-v1'});await db.doc('quiz_control/taxonomy').set(taxonomy());}
beforeEach(async()=>{
  await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,{method:'DELETE'});
  now=Date.parse('2026-10-25T10:00:00Z');await enable();
});
after(async()=>{await db.terminate();await deleteApp(app);});

test('verified-auth context and fixed server admin list are required before any import',async()=>{
  await rejects(()=>service.preview(null,{csv:csv([row()])}),'unauthenticated');
  await rejects(()=>service.preview({uid:'student',token:{admin:true,role:'admin'}},{csv:csv([row()])}),'permission_denied');
  const emptyAdmins=new QuizImportService(db);await rejects(()=>emptyAdmins.preview(admin,{csv:csv([row()])}),'permission_denied');
  assert.equal(await count('quiz_import_batches'),0);
});
test('default missing or disabled private server configuration fails closed',async()=>{
  await db.doc('quiz_control/import').delete();await rejects(()=>preview([row()]),'feature_disabled');
  await db.doc('quiz_control/import').set({enabled:false});await rejects(()=>preview([row()]),'feature_disabled');
  assert.equal(await count('quiz_import_batches'),0);
});
test('actual owner-approved taxonomy must be supplied server-side with the current version',async()=>{
  await db.doc('quiz_control/taxonomy').delete();await rejects(()=>preview([row()]),'taxonomy_unavailable');
  await db.doc('quiz_control/taxonomy').set({...taxonomy(),approved:false});await rejects(()=>preview([row()]),'taxonomy_unavailable');
  await db.doc('quiz_control/taxonomy').set({...taxonomy(),version:'mismatch'});await rejects(()=>preview([row()]),'taxonomy_unavailable');
});
test('BOM quoted multiline CSV stages private rows but returns metadata only',async()=>{
  const result=await service.preview(admin,{csv:'\ufeff'+csv([row()])});
  assert.deepEqual(Object.keys(result).sort(),['batchId','checksum','expiresAt','published','rowCount','state'].sort());
  assert.equal(result.rowCount,1);assert.equal(result.published,false);
  assert.ok(!JSON.stringify(result).includes('SECRET-FIXTURE'));assert.ok(!JSON.stringify(result).includes('PRIVATE-EXPLANATION'));
  const stored=(await db.doc('quiz_import_batches/'+result.batchId).get()).data();assert.equal(stored.rows[0].correctOption,'B');assert.equal(stored.rows[0].stem,row().question);
  assert.equal(await count('quiz_question_revisions'),0);
});
test('server validator rejects cross-year subject/topic values with line-only error metadata',async()=>{
  for(const changes of [{professional_year:'2'},{subject:'foreign-subject'},{topic:'foreign-topic'}]){
    try{await preview([row('fixture-1',changes)]);assert.fail('accepted wrong taxonomy');}
    catch(error){assert.equal(error.code,'invalid_csv');assert.equal(error.details.line,2);assert.ok(!JSON.stringify(error.details).includes('SECRET-FIXTURE'));}
  }
  assert.equal(await count('quiz_import_batches'),0);
});
test('duplicates malformed columns unsafe IDs answers formulas and markup reject the entire preview',async()=>{
  await rejects(()=>preview([row(),row()]),'invalid_csv');
  for(const changes of [{question_id:'../secret'},{correct_option:'Z'},{option_b:'CHOICE-A'},{option_a:'=IMPORT("PRIVATE")'},{question:'<script>PRIVATE</script>'}]) await rejects(()=>preview([row('fixture-1',changes)]),'invalid_csv');
  await rejects(()=>service.preview(admin,{csv:header+',unknown\n'}),'invalid_csv');
  await rejects(()=>service.preview(admin,{csv:'"unclosed'}),'invalid_csv');
  assert.equal(await count('quiz_import_batches'),0);
});
test('transport row and encoding limits bound parsing before a stored preview exists',async()=>{
  for(const value of ['x'.repeat(256*1024+1),'\0','\ud800',header+'\n'])await rejects(()=>service.preview(admin,{csv:value}),'invalid_csv');
  await rejects(()=>preview(Array.from({length:201},(_,i)=>row('fixture-'+i))),'invalid_csv');
  assert.equal(await count('quiz_import_batches'),0);
});
test('explicit confirmation atomically imports immutable private draft revisions and never publishes active CSV rows',async()=>{
  const p=await preview([row('fixture-1',{status:'active'}),row('fixture-2')]);
  const result=await service.commit(admin,confirm(p));assert.equal(result.imported,2);assert.equal(result.published,false);
  const question=(await db.doc('quiz_question_revisions/fixture-1__v1').get()).data();
  assert.equal(question.version,1);assert.equal(question.status,'draft');assert.equal(question.sourceRequestedStatus,'active');assert.equal(question.correctOption,'B');assert.equal(question.importBatch,p.batchId);
  assert.equal(await count('quiz_events'),0);
});
test('commit binds checksum and preview ownership before writing questions',async()=>{
  const p=await preview([row()]);
  await rejects(()=>service.commit(admin,{...confirm(p),checksum:'b'.repeat(64)}),'confirmation_mismatch');
  await rejects(()=>service.commit({uid:'other-admin'},confirm(p)),'batch_unavailable');
  await rejects(()=>service.commit({uid:'student'},confirm(p)),'permission_denied');
  assert.equal(await count('quiz_question_revisions'),0);
});
test('concurrent same-key retries resolve to one result and one question revision',async()=>{
  const p=await preview([row()]);const [a,b]=await Promise.all([service.commit(admin,confirm(p)),service.commit(admin,confirm(p))]);
  assert.deepEqual(a,b);assert.equal(await count('quiz_question_revisions'),1);
  const saved=(await db.doc('quiz_import_batches/'+p.batchId).get()).data();assert.equal(saved.state,'committed');assert.equal(saved.idempotencyKey,confirm(p).idempotencyKey);
});
test('a second confirmation key cannot commit the same preview twice',async()=>{
  const p=await preview([row()]);await service.commit(admin,confirm(p));
  await rejects(()=>service.commit(admin,{...confirm(p),idempotencyKey:'different_confirmation_0002'}),'already_committed');assert.equal(await count('quiz_question_revisions'),1);
});
test('idempotent responses never echo extra private fields from stored result metadata',async()=>{
  const p=await preview([row()]);const result=await service.commit(admin,confirm(p));
  await db.doc('quiz_import_batches/'+p.batchId).update({result:{...result,secret:'PRIVATE-SECRET',correctOption:'B'}});
  const replay=await service.commit(admin,confirm(p));assert.deepEqual(replay,result);assert.ok(!JSON.stringify(replay).includes('PRIVATE-SECRET'));
});
test('existing IDs require revision review and cannot be overwritten or partially imported',async()=>{
  const original={stem:'original-private',version:1,status:'draft'};await db.doc('quiz_question_revisions/fixture-1__v1').set(original);
  const p=await preview([row('fixture-1'),row('fixture-2')]);await rejects(()=>service.commit(admin,confirm(p)),'revision_conflict');
  assert.deepEqual((await db.doc('quiz_question_revisions/fixture-1__v1').get()).data(),original);assert.equal((await db.doc('quiz_question_revisions/fixture-2__v1').get()).exists,false);
  assert.equal((await db.doc('quiz_import_batches/'+p.batchId).get()).data().state,'preview');
});
test('parallel overlapping batches allow only one complete transaction',async()=>{
  const a=await preview([row('overlap'),row('only-a')]),b=await preview([row('overlap'),row('only-b')]);
  const results=await Promise.allSettled([service.commit(admin,confirm(a)),service.commit(admin,confirm(b))]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(results.find(r=>r.status==='rejected').reason.code,'revision_conflict');assert.equal(await count('quiz_question_revisions'),2);
});
test('expired preview cannot commit while a completed idempotent retry remains stable',async()=>{
  const p=await preview([row()]);now+=16*60*1000;await rejects(()=>service.commit(admin,confirm(p)),'batch_expired');assert.equal(await count('quiz_question_revisions'),0);
  now-=16*60*1000;const valid=await preview([row('valid')]);const accepted=await service.commit(admin,confirm(valid));now+=16*60*1000;assert.deepEqual(await service.commit(admin,confirm(valid)),accepted);
});
test('taxonomy changes including same-version edits block stale confirmation',async()=>{
  const p=await preview([row()]);const changed=taxonomy();changed.years['1'].subjects['fixture-subject'].topics.push('new-topic');
  await db.doc('quiz_control/taxonomy').set(changed);await rejects(()=>service.commit(admin,confirm(p)),'taxonomy_changed');assert.equal(await count('quiz_question_revisions'),0);
});
test('server-side feature disable is rechecked inside the committing transaction',async()=>{
  const p=await preview([row()]);await db.doc('quiz_control/import').update({enabled:false});await rejects(()=>service.commit(admin,confirm(p)),'feature_disabled');assert.equal(await count('quiz_question_revisions'),0);
});
test('client cannot choose taxonomy or authorization and unsafe confirmation inputs fail closed',async()=>{
  await rejects(()=>service.preview(admin,{csv:csv([row()]),taxonomy:taxonomy()}),'invalid_request');
  await rejects(()=>service.preview(admin,{csv:csv([row()]),adminUid:'fixture-admin'}),'invalid_request');
  for(const changes of [{batchId:'../../settings/pw_orders'},{idempotencyKey:'short'},{checksum:'invalid'}])await rejects(()=>service.commit(admin,{batchId:'a'.repeat(36),checksum:'a'.repeat(64),idempotencyKey:'fixture_confirmation_123',...changes}),'invalid_request');
});

test('retention removes expired preview payload while preserving a private audit tombstone',async()=>{
  const p=await preview([row()]);now+=16*60*1000;
  const result=await expireImportPreviews(db,{now});assert.deepEqual(result,{scanned:1,expired:1});
  const tombstone=(await db.doc('quiz_import_batches/'+p.batchId).get()).data();
  assert.equal(tombstone.state,'expired');assert.equal(tombstone.rowCount,1);assert.equal(tombstone.actorUid,admin.uid);
  assert.equal(tombstone.rows,undefined);assert.ok(!JSON.stringify(tombstone).includes('SECRET-FIXTURE'));
  await rejects(()=>service.commit(admin,confirm(p)),'batch_expired');
  assert.deepEqual(await expireImportPreviews(db,{now}),{scanned:0,expired:0});
});
test('retention preserves current previews committed replay and immutable draft revisions',async()=>{
  const old=await preview([row('committed')]);const result=await service.commit(admin,confirm(old));
  now+=16*60*1000;const current=await preview([row('current')]);
  assert.deepEqual(await expireImportPreviews(db,{now}),{scanned:0,expired:0});
  assert.equal((await db.doc('quiz_import_batches/'+current.batchId).get()).data().rows.length,1);
  assert.deepEqual(await service.commit(admin,confirm(old)),result);
  assert.equal((await db.doc('quiz_question_revisions/committed__v1').get()).data().stem,row().question);
});
test('retention is bounded and concurrent overlapping cleanup is idempotent',async()=>{
  for (let i=0;i<3;i++) await preview([row('expired-'+i)]);
  now+=16*60*1000;
  const [a,b]=await Promise.all([expireImportPreviews(db,{now,limit:2}),expireImportPreviews(db,{now,limit:2})]);
  assert.ok(a.expired+b.expired<=3);
  const rest=await expireImportPreviews(db,{now,limit:2});
  assert.equal(a.expired+b.expired+rest.expired,3);
  assert.equal((await db.collection('quiz_import_batches').where('state','==','preview').get()).size,0);
  for (const limit of [0,101,1.5]) await assert.rejects(()=>expireImportPreviews(db,{now,limit}));
});
test('retention never removes a batch committed after candidate selection',async()=>{
  const p=await preview([row()]);
  // Simulate Scheduler clock at expiry while an already-running valid commit
  // wins the transaction. Cleanup must reread state inside its transaction.
  const candidate=(await db.doc('quiz_import_batches/'+p.batchId).get());
  await service.commit(admin,confirm(p));
  const facade={collection:()=>({where:()=>({where:()=>({orderBy:()=>({limit:()=>({get:async()=>({docs:[candidate],size:1})})})})})}),runTransaction:callback=>db.runTransaction(callback)};
  assert.deepEqual(await expireImportPreviews(facade,{now:now+16*60*1000}),{scanned:1,expired:0});
  assert.equal((await candidate.ref.get()).data().state,'committed');
});
