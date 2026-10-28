import {beforeEach,after,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {QuizPlayService,PlayError} from '../play-service.mjs';
import {playHandler} from '../play-handlers.mjs';
const host=process.env.FIRESTORE_EMULATOR_HOST;
if(!host||!/^127\.0\.0\.1:\d+$/.test(host))throw new Error('Loopback emulator required.');
const projectId='demo-hyzen-play',app=initializeApp({projectId},'play-tests'),db=getFirestore(app);
let now;const service=new QuizPlayService(db,{now:()=>now,choose:n=>n-1});
const alice={uid:'fixture-alice'},bob={uid:'fixture-bob'},eve={uid:'fixture-eve'};
const policy={enabled:true,approved:true,version:'free-v1',timezone:'Asia/Karachi',correctPoints:1,wrongPoints:0,tie:'shared',dailyCap:3,cooldownSeconds:3600};
const start=(u=alice,k='start_request_0001')=>service.start(u,{poolId:'fixture',requestId:k});
const challenge=(u=alice,k='duel_request_00001')=>service.createDuel(u,{poolId:'fixture',requestId:k});
const no=(f,c)=>assert.rejects(f,e=>e instanceof PlayError&&e.code===c);
const answers=(a,v='B')=>Object.fromEntries(a.questions.map(q=>[q.id,v]));
const submit=(u,a,v='B')=>service.submit(u,{attemptId:a.attemptId,revision:a.revision,answers:answers(a,v)});
beforeEach(async()=>{
 await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,{method:'DELETE'});
 now=Date.parse('2026-10-26T10:00:00Z');const b=db.batch();b.set(db.doc('quiz_control/play'),policy);
 for(const u of [alice,bob,eve])b.set(db.doc('quiz_members/'+u.uid),{enabled:true,professionalYear:1});
 const revisions=[];
 for(let i=0;i<12;i++){const name=`fixture-${i}__v1`;revisions.push(name);
  b.set(db.doc('quiz_question_revisions/'+name),{questionId:`fixture-${i}`,version:1,professionalYear:1,stem:`Question ${i} synthetic only`,options:{A:'Alpha',B:'Beta',C:'Gamma',D:'Delta'},correctOption:'B',explanation:'PRIVATE explanation',createdBy:'PRIVATE admin'});
  b.set(db.doc('quiz_publications/'+name),{enabled:true,revision:name});}
 b.set(db.doc('quiz_pools/fixture'),{enabled:true,professionalYear:1,questionCount:2,durationSeconds:60,opensAt:now-86400000,closesAt:now+7*86400000,revisions});await b.commit();
});
after(async()=>{await db.terminate();await deleteApp(app);});
test('missing policy, unsupported scoring, absent membership fail closed',async()=>{
 await no(()=>start(null),'unauthenticated');await db.doc('quiz_control/play').delete();await no(()=>start(),'feature_disabled');
 await db.doc('quiz_control/play').set({...policy,wrongPoints:-1});await no(()=>start(),'policy_unavailable');
 await db.doc('quiz_control/play').set(policy);await db.doc('quiz_members/'+alice.uid).delete();await no(()=>start(),'membership_required');
 assert.equal((await db.collection('quiz_attempts').get()).size,0);
});
test('client year/score override rejected; trusted year enforced',async()=>{
 await no(()=>service.start(alice,{poolId:'fixture',requestId:'start_request_0001',professionalYear:1}),'invalid_request');
 await db.doc('quiz_members/'+alice.uid).update({professionalYear:2});await no(()=>start(),'pool_unavailable');
});
test('DTO contains no private keys, explanation or admin identity',async()=>{
 const a=await start();assert.equal(a.questions.length,2);assert.equal(a.deadline,now+60000);
 for(const k of ['correctOption','explanation','createdBy','PRIVATE','uid'])assert.ok(!JSON.stringify(a).includes(k));
 assert.deepEqual(Object.keys(a.questions[0]).sort(),['id','options','stem']);
});
test('same-key concurrent starts charge once',async()=>{
 const [a,b]=await Promise.all([start(),start()]);assert.deepEqual(a,b);assert.equal((await db.doc('quiz_player_state/'+alice.uid).get()).data().count,1);
});
test('different-key concurrent starts cannot bypass active attempt',async()=>{
 const r=await Promise.allSettled([start(),start(alice,'start_request_0002')]);assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(r.find(x=>x.status==='rejected').reason.code,'attempt_active');
});
test('request key is bound to pool',async()=>{
 await start();await no(()=>service.start(alice,{poolId:'other',requestId:'start_request_0001'}),'request_conflict');
});
test('unpublished questions do not allocate or charge quota',async()=>{
 for(let i=0;i<12;i++)await db.doc(`quiz_publications/fixture-${i}__v1`).update({enabled:false});
 await no(()=>start(),'insufficient_questions');assert.equal((await db.collection('quiz_attempts').get()).size,0);
});
test('wrong answers score zero and final submission is immutable',async()=>{
 const a=await start(),b=await submit(alice,a,'A');assert.deepEqual(b.result,{correct:0,total:2,answered:2});assert.deepEqual((await submit(alice,a)).result,b.result);
});
test('exact lost-response save retry is idempotent; stale different save cannot overwrite',async()=>{
 const a=await start(),p={attemptId:a.attemptId,revision:0,answers:answers(a)};
 assert.equal((await service.save(alice,p)).revision,1);assert.equal((await service.save(alice,p)).revision,1);
 await no(()=>service.save(alice,{...p,answers:answers(a,'A')}),'revision_conflict');
});
test('contradictory concurrent saves commit one revision',async()=>{
 const a=await start(),r=await Promise.allSettled(['A','B'].map(v=>service.save(alice,{attemptId:a.attemptId,revision:0,answers:answers(a,v)})));
 assert.equal(r.filter(x=>x.status==='fulfilled').length,1);assert.equal(r.find(x=>x.status==='rejected').reason.code,'revision_conflict');
});
test('server deadline scores saved answers and ignores late client replacement',async()=>{
 const a=await start();await service.save(alice,{attemptId:a.attemptId,revision:0,answers:{[a.questions[0].id]:'B'}});now=a.deadline;
 const b=await service.submit(alice,{attemptId:a.attemptId,revision:1,answers:answers(a)});assert.deepEqual(b.result,{correct:1,total:2,answered:1});
});
test('ownership and answer shape are enforced',async()=>{
 const a=await start();await no(()=>service.get(bob,{attemptId:a.attemptId}),'attempt_unavailable');
 for(const x of [{foreign:'B'},{[a.questions[0].id]:'E'},[]])await no(()=>service.save(alice,{attemptId:a.attemptId,revision:0,answers:x}),'invalid_answers');
});
test('three per day and one-hour cooldown include abandoned starts',async()=>{
 const a=await start();await submit(alice,a);now+=60001;await no(()=>start(alice,'start_request_0002'),'cooldown');
 now+=3600000;await start(alice,'start_request_0002');now+=3600000;await start(alice,'start_request_0003');now+=3600000;await no(()=>start(alice,'start_request_0004'),'daily_limit');
});
test('Pakistan midnight resets count without bypassing cooldown',async()=>{
 now=Date.parse('2026-10-26T18:50:00Z');await start();now+=20*60000;await no(()=>start(alice,'next_day_request_1'),'cooldown');
 now+=41*60000;await start(alice,'next_day_request_1');assert.equal((await db.doc('quiz_player_state/'+alice.uid).get()).data().count,1);
});
test('exhausted pool does not repeat questions or charge an attempt',async()=>{
 await db.doc('quiz_pools/fixture').update({revisions:['fixture-0__v1','fixture-1__v1']});await start();now+=3600000;
 await no(()=>start(alice,'start_request_0002'),'insufficient_questions');assert.equal((await db.doc('quiz_player_state/'+alice.uid).get()).data().count,1);
});
test('invitation has no questions and cancellation is host-only and idempotent',async()=>{
 const d=await challenge();assert.equal(d.questions,undefined);await no(()=>service.cancelDuel(bob,{code:d.code}),'duel_unavailable');
 await service.cancelDuel(alice,{code:d.code});assert.equal((await service.cancelDuel(alice,{code:d.code})).state,'cancelled');await no(()=>service.joinDuel(bob,{code:d.code}),'duel_unavailable');await start();
});
test('duel join requires different-player same-year consent; outsiders cannot inspect',async()=>{
 const d=await challenge();await no(()=>service.joinDuel(alice,{code:d.code}),'duel_unavailable');await db.doc('quiz_members/'+bob.uid).update({professionalYear:2});
 await no(()=>service.joinDuel(bob,{code:d.code}),'duel_unavailable');await db.doc('quiz_members/'+bob.uid).update({professionalYear:1});
 const b=await service.joinDuel(bob,{code:d.code}),a=await service.duelStatus(alice,{code:d.code});assert.deepEqual(a.questions,b.questions);assert.equal(a.deadline,b.deadline);
 await no(()=>service.duelStatus(eve,{code:d.code}),'duel_unavailable');
});
test('two guest race permits one guest; retry cannot create extra attempts',async()=>{
 const d=await challenge(),r=await Promise.allSettled([bob,eve].map(u=>service.joinDuel(u,{code:d.code})));assert.equal(r.filter(x=>x.status==='fulfilled').length,1);
 const b=await service.joinDuel(r[0].status==='fulfilled'?bob:eve,{code:d.code});assert.equal(b.attemptId,r.find(x=>x.status==='fulfilled').value.attemptId);assert.equal((await db.collection('quiz_attempts').get()).size,2);
});
test('duel scores are private until both submit; winner comes from server grading',async()=>{
 const d=await challenge(),b=await service.joinDuel(bob,{code:d.code}),a=await service.duelStatus(alice,{code:d.code});
 assert.equal((await submit(alice,a)).duelResult,undefined);assert.equal((await submit(bob,b,'A')).duelResult,'lost');assert.equal((await service.get(alice,{attemptId:a.attemptId})).duelResult,'won');
});
test('deadline settles disconnected opponent and equal scores share a draw',async()=>{
 const d=await challenge(),b=await service.joinDuel(bob,{code:d.code}),a=await service.duelStatus(alice,{code:d.code});
 for(const [u,x]of [[alice,a],[bob,b]])await service.save(u,{attemptId:x.attemptId,revision:0,answers:answers(x)});now=a.deadline;
 assert.equal((await service.get(alice,{attemptId:a.attemptId})).duelResult,'draw');assert.equal((await service.get(bob,{attemptId:b.attemptId})).duelResult,'draw');
});
test('invitation expiry and quota prevent repeated invite spam',async()=>{
 const d=await challenge();now+=10*60000;await no(()=>service.joinDuel(bob,{code:d.code}),'duel_unavailable');
 for(let i=2;i<=3;i++){const x=await challenge(alice,`duel_request_0000${i}`);await service.cancelDuel(alice,{code:x.code});}await no(()=>challenge(alice,'duel_request_00004'),'invitation_limit');
});
test('duel uses questions unseen by both players',async()=>{
 const first=await start(bob);now+=3600000;const d=await challenge(),b=await service.joinDuel(bob,{code:d.code});assert.ok(b.questions.every(q=>!first.questions.some(x=>x.id===q.id)));
});
test('handler requires authentication and App Check and redacts internal failures',async()=>{
 const h=playHandler({start:async()=>{throw Error('PRIVATE connection');}},'start');
 await assert.rejects(()=>h({}),e=>e.code==='unauthenticated');await assert.rejects(()=>h({auth:alice}),e=>e.code==='failed-precondition');
 await assert.rejects(()=>h({auth:alice,app:{appId:'fixture'},data:{}}),e=>e.code==='internal'&&!JSON.stringify(e).includes('PRIVATE'));
});

test('changed duel pool requires a new invitation rather than silently changing agreed rules',async()=>{
 const d=await challenge();await db.doc('quiz_pools/fixture').update({questionCount:3});
 await no(()=>service.joinDuel(bob,{code:d.code}),'pool_changed');assert.equal((await db.collection('quiz_attempts').get()).size,0);
});
test('same-key concurrent duel creation returns one server-generated code and one reservation',async()=>{
 const [a,b]=await Promise.all([challenge(),challenge()]);assert.equal(a.code,b.code);assert.equal((await db.collection('quiz_duels').get()).size,1);
 assert.equal((await db.doc('quiz_player_state/'+alice.uid).get()).data().inviteCount,1);
});

test('lobby exposes only eligible pool metadata and owned recovery IDs',async()=>{
 await db.doc('quiz_pools/other-year').set({...(await db.doc('quiz_pools/fixture').get()).data(),professionalYear:2,title:'PRIVATE other year'});
 const a=await start(),l=await service.lobby(alice,{});
 assert.equal(l.lastAttemptId,a.attemptId);assert.equal(l.attemptsToday,1);assert.equal(l.pools.length,1);
 for(const secret of ['correctOption','stem','PRIVATE','fixture-alice','revisions'])assert.ok(!JSON.stringify(l).includes(secret));
 await no(()=>service.lobby(bob,{uid:alice.uid}),'invalid_request');
});
test('cancelled invitation status remains recoverable after restart',async()=>{
 const d=await challenge();await service.cancelDuel(alice,{code:d.code});
 assert.equal((await service.duelStatus(alice,{code:d.code})).state,'cancelled');assert.equal((await service.lobby(alice,{})).lastDuelCode,d.code);
});
test('new revision cannot reset per-user question history',async()=>{
 await db.doc('quiz_pools/fixture').update({revisions:['fixture-0__v1','fixture-1__v1']});await start();now+=3600000;
 for(let i=0;i<2;i++){
  await db.doc(`quiz_question_revisions/fixture-${i}__v2`).set({...(await db.doc(`quiz_question_revisions/fixture-${i}__v1`).get()).data(),version:2});
  await db.doc(`quiz_publications/fixture-${i}__v2`).set({enabled:true,revision:`fixture-${i}__v2`});
 }
 await db.doc('quiz_pools/fixture').update({revisions:['fixture-0__v2','fixture-1__v2']});await no(()=>start(alice,'start_request_0002'),'insufficient_questions');
});
test('duel exhaustion charges neither player and keeps invitation cancellable',async()=>{
 await db.doc('quiz_pools/fixture').update({revisions:['fixture-0__v1','fixture-1__v1']});await start(bob);now+=3600000;
 const d=await challenge();await no(()=>service.joinDuel(bob,{code:d.code}),'insufficient_questions');
 assert.equal((await db.doc('quiz_player_state/'+alice.uid).get()).data().count,undefined);assert.equal((await db.doc('quiz_player_state/'+bob.uid).get()).data().count,1);
 await service.cancelDuel(alice,{code:d.code});
});
