import {beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {QuizAdminService} from '../admin-service.mjs';
import {importHandler} from '../callable-handlers.mjs';
const host=process.env.FIRESTORE_EMULATOR_HOST;
if(!host||!/^127\.0\.0\.1:\d+$/.test(host))throw new Error('Loopback emulator required.');
const projectId='demo-hyzen-admin',app=initializeApp({projectId},'admin-tests'),db=getFirestore(app);
const auth={uid:'fixture-admin'},service=new QuizAdminService(db,{adminUids:[auth.uid],now:()=>1000});
const revision='fixture__v1',q={questionId:'fixture',version:1,professionalYear:1,subject:'Fixture',topic:'Synthetic',stem:'Synthetic test question?',options:{A:'One',B:'Two',C:'Three',D:'Four'},correctOption:'B',explanation:'Fixture only',difficulty:'easy',createdBy:'PRIVATE',importBatch:'PRIVATE'};
const review=()=>service.reviewQuestion(auth,{revision});
const publish=async(overrides={})=>{const r=await review();return service.setPublication(auth,{revision,contentHash:r.contentHash,enabled:true,reviewed:true,expectedVersion:r.publicationVersion,requestId:'fixture_request_0001',...overrides});};
beforeEach(async()=>{
 await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,{method:'DELETE'});
 await db.doc('quiz_control/import').set({enabled:true,taxonomyVersion:'fixture-v1'});
 await db.doc('quiz_control/taxonomy').set({schema_version:1,approved:true,version:'fixture-v1',years:{'1':{subjects:{Fixture:{topics:['Synthetic']}}}}});
 await db.doc('quiz_question_revisions/'+revision).set(q);
});
after(async()=>{await db.terminate();await deleteApp(app);});
test('admin operations deny ordinary users and empty allowlists',async()=>{
 for(const method of ['listQuestions','reviewQuestion','setPublication']){
  await assert.rejects(()=>service[method]({uid:'student'},{}),{code:'permission_denied'});
  await assert.rejects(()=>new QuizAdminService(db)[method](auth,{}),{code:'permission_denied'});
 }
});
test('question list is bounded and paginated without answer keys',async()=>{
 const b=db.batch();for(let i=0;i<24;i++)b.set(db.doc(`quiz_question_revisions/q${i}__v1`),{...q,questionId:`q${i}`});await b.commit();
 const first=await service.listQuestions(auth,{}),second=await service.listQuestions(auth,{after:first.nextCursor});
 assert.equal(first.items.length,20);assert.equal(second.items.length,5);assert.equal(second.nextCursor,null);
 assert.equal(new Set([...first.items,...second.items].map(x=>x.revision)).size,25);
 assert.ok(!JSON.stringify(first).includes('correctOption'));assert.ok(!JSON.stringify(first).includes('PRIVATE'));
});
test('review exposes content to admin only and excludes audit identity',async()=>{
 const r=await review();assert.equal(r.question.correctOption,'B');assert.equal(r.contentHash.length,64);assert.equal(r.enabled,false);
 assert.ok(!JSON.stringify(r).includes('PRIVATE'));
});
test('publication requires exact reviewed content and explicit acknowledgement',async()=>{
 await assert.rejects(()=>publish({reviewed:false}),{code:'invalid_request'});
 await assert.rejects(()=>publish({contentHash:'a'.repeat(64)}),{code:'confirmation_mismatch'});
 assert.equal((await db.doc('quiz_publications/'+revision).get()).exists,false);
});
test('publication is audited, leaves revision unchanged, and exact retry is idempotent',async()=>{
 const r=await review(),data={revision,contentHash:r.contentHash,enabled:true,reviewed:true,expectedVersion:0,requestId:'fixture_request_0001'};
 const results=await Promise.all([service.setPublication(auth,data),service.setPublication(auth,data)]);
 assert.deepEqual(results[0],results[1]);assert.equal(results[0].version,1);
 assert.deepEqual((await db.doc('quiz_question_revisions/'+revision).get()).data(),q);
 assert.equal((await db.collection('quiz_publication_audit').get()).size,1);
 await assert.rejects(()=>service.setPublication(auth,{...data,enabled:false}),{code:'confirmation_mismatch'});
});
test('conflicting concurrent publications cannot overwrite newer admin decision',async()=>{
 const r=await review(),base={revision,contentHash:r.contentHash,reviewed:true,expectedVersion:0};
 const results=await Promise.allSettled([true,false].map((enabled,i)=>service.setPublication(auth,{...base,enabled,requestId:'fixture_request_000'+i})));
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
 assert.equal(results.find(x=>x.status==='rejected').reason.code,'publication_conflict');
});
test('withdrawal stops publication and requires fresh version',async()=>{
 await publish();await assert.rejects(()=>publish({enabled:false,expectedVersion:0,requestId:'fixture_request_0002'}),{code:'publication_conflict'});
 assert.equal((await publish({enabled:false,requestId:'fixture_request_0002'})).enabled,false);
});
test('disabled import or changed taxonomy prevents publishing',async()=>{
 await db.doc('quiz_control/import').update({enabled:false});await assert.rejects(review,{code:'feature_disabled'});
 await db.doc('quiz_control/import').update({enabled:true});
 await db.doc('quiz_control/taxonomy').update({'years.1.subjects.Fixture.topics':['Other']});
 await assert.rejects(()=>publish(),{code:'taxonomy_changed'});
});
test('admin callable guards reject missing auth and App Check',async()=>{
 const handler=importHandler(service,'reviewQuestion');
 await assert.rejects(()=>handler({data:{revision}}),{code:'unauthenticated'});
 await assert.rejects(()=>handler({auth,data:{revision}}),{code:'failed-precondition'});
 await assert.rejects(()=>handler({auth:{uid:'student'},app:{appId:'fixture'},data:{revision}}),{code:'permission-denied'});
});
