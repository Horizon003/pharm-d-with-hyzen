const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('../functions/node_modules/@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,updateDoc,deleteDoc,getDocs,query,collection,where,serverTimestamp,Timestamp,writeBatch,runTransaction}=require('../functions/node_modules/firebase/firestore');
const fs=require('node:fs');let env,a,b,admin;
const day=ms=>Math.floor((ms+18000000)/86400000), date=d=>new Date(d*86400000).toISOString().slice(0,10);
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-hyzen-native',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(process.env.HYZEN_FIRESTORE_RULES || 'backend/firestore.firebase-study.rules','utf8')}});
 a=env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
 b=env.authenticatedContext('bob',{email:'bob@example.com'}).firestore();
 admin=env.authenticatedContext('Vv6HtZjmUvfVACzvuyL2pFx5HR33',{email:'admin@example.com'}).firestore();
});
after(async()=>{await env?.cleanup();});
test('wallet: server date, owner isolation and duplicate/double-credit rejection',async()=>{
 const today=day(Date.now()),wallet={points:100,lastDay:today,streak:1,best:1,days:[today],badges:[],action:'daily',milestone:0,updatedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(a,'studyUsers/alice/state/wallet'),wallet));
 await assertSucceeds(getDoc(doc(a,'studyUsers/alice/state/wallet')));
 await assertFails(getDoc(doc(b,'studyUsers/alice/state/wallet')));
 await assertFails(updateDoc(doc(a,'studyUsers/alice/state/wallet'),{points:200,updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(b,'studyUsers/bob/state/wallet'),{...wallet,lastDay:today+1,days:[today+1]}));
 await assertFails(updateDoc(doc(a,'studyUsers/alice/state/wallet'),{action:'achievement',milestone:100,points:150,badges:[100],updatedAt:serverTimestamp()}));
});
test('weekly bonus and milestone use verified existing streak and are exactly once',async()=>{
 const today=day(Date.now());
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'studyUsers/bob/state/wallet'),{points:600,lastDay:today-1,streak:6,best:6,days:Array.from({length:6},(_,i)=>today-6+i),badges:[],action:'daily',milestone:0,updatedAt:Timestamp.now()}));
 const prior=(await getDoc(doc(b,'studyUsers/bob/state/wallet'))).data();
 await assertSucceeds(setDoc(doc(b,'studyUsers/bob/state/wallet'),{...prior,points:900,lastDay:today,streak:7,best:7,days:[...prior.days,today],updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(doc(b,'studyUsers/bob/state/wallet'),{action:'achievement',milestone:7,points:950,badges:[7],updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(b,'studyUsers/bob/state/wallet'),{points:1000,updatedAt:serverTimestamp()}));
});
test('calendar CRUD is owner scoped; invalid payloads are rejected',async()=>{
 const event={title:'Pharmacology paper',at:'2026-11-23T04:00:00Z',day:'2026-11-23',color:0xffd46a61,kind:'Exam',leadMinutes:30,updatedAt:serverTimestamp()};
 await assertSucceeds(setDoc(doc(a,'studyUsers/alice/calendar/exam'),event));
 await assertFails(getDoc(doc(b,'studyUsers/alice/calendar/exam')));
 await assertFails(setDoc(doc(a,'studyUsers/alice/calendar/bad'),{...event,leadMinutes:-1}));
 await assertSucceeds(deleteDoc(doc(a,'studyUsers/alice/calendar/exam')));
});
test('clock/activity initialize with server timestamps; invented elapsed time is denied',async()=>{
 await assertSucceeds(setDoc(doc(a,'studyUsers/alice/state/clock'),{at:serverTimestamp()}));
 const ref=doc(a,'studyUsers/alice/state/activity');
 const initial={version:1,session:'a'.repeat(32),active:true,closed:false,at:serverTimestamp(),previousAt:serverTimestamp(),previousActive:false,previousSession:'a'.repeat(32),totalMs:0,sessionMs:0,deltaMs:0,creditDay:0,creditYear:0,completion:0,academicYear:0};
 await assertSucceeds(setDoc(ref,initial));
 await assertFails(updateDoc(ref,{totalMs:3600000,at:serverTimestamp()}));
 const old=(await getDoc(ref)).data();
 await assertSucceeds(setDoc(ref,{...old,version:2,at:serverTimestamp(),previousAt:old.at,previousActive:true,previousSession:old.session,creditDay:day(old.at.toMillis())}));
});
test('real server-stamped intervals settle once into private history and cannot be replayed',async()=>{
 const uid='reader',client=env.authenticatedContext(uid).firestore(),now=Date.now();
 const at=Timestamp.fromMillis(now-10000),prev=Timestamp.fromMillis(now-20000),d=day(now-10000),session='c'.repeat(32);
 const old={version:1,session,active:true,closed:false,at,previousAt:prev,previousActive:true,previousSession:session,totalMs:0,sessionMs:0,deltaMs:0,creditDay:0,creditYear:0,completion:0,academicYear:0};
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),`studyUsers/${uid}/state/activity`),old));
 const next={...old,version:2,at:serverTimestamp(),previousAt:at,totalMs:10000,sessionMs:10000,deltaMs:10000,creditDay:d};
 const stats={day:d,academicYear:0,totalMs:10000,completed:0,bonus:0,lastVersion:2};
 const batch=writeBatch(client);batch.set(doc(client,`studyUsers/${uid}/state/activity`),next);batch.set(doc(client,`studyUsers/${uid}/verifiedDays/0_${d}`),stats);
 await assertSucceeds(batch.commit());
 await assertFails(updateDoc(doc(client,`studyUsers/${uid}/verifiedDays/0_${d}`),{totalMs:20000}));
});
test('verified rank credit matches the settled minute and metadata is not self-verifiable',async()=>{
 const uid='ranked',client=env.authenticatedContext(uid).firestore(),now=Date.now(),d=day(now-10000),year=2,session='d'.repeat(32);
 const at=Timestamp.fromMillis(now-10000),prev=Timestamp.fromMillis(now-25000);
 const old={version:1,session,active:true,closed:false,at,previousAt:prev,previousActive:true,previousSession:session,totalMs:45000,sessionMs:45000,deltaMs:0,creditDay:d,creditYear:year,completion:0,academicYear:year};
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),`campusMemberships/${uid}`),{verified:true,firebaseRankConsent:true,academicYear:year,alias:'Reader',optOut:false});
  await setDoc(doc(c.firestore(),`studyUsers/${uid}/state/activity`),old);
  await setDoc(doc(c.firestore(),`studyUsers/${uid}/verifiedDays/${year}_${d}`),{day:d,academicYear:year,totalMs:45000,completed:0,bonus:0,lastVersion:1});
 });
 const dt=new Date(d*86400000),stats={academicYear:year,weekKey:Math.floor((d+3)/7),weekPoints:1,weekMinutes:1,monthKey:dt.getUTCFullYear()*12+dt.getUTCMonth()+1,monthPoints:1,monthMinutes:1,totalPoints:1,totalMinutes:1,sourceVersion:2};
 const batch=writeBatch(client);
 batch.set(doc(client,`studyUsers/${uid}/state/activity`),{...old,version:2,at:serverTimestamp(),previousAt:at,totalMs:60000,sessionMs:60000,deltaMs:15000});
 batch.set(doc(client,`studyUsers/${uid}/verifiedDays/${year}_${d}`),{day:d,academicYear:year,totalMs:60000,completed:0,bonus:0,lastVersion:2});
 batch.set(doc(client,`studyUsers/${uid}/state/rank_${year}`),stats);
 batch.set(doc(client,`professionalRanks/${uid}`),{...stats,uid,alias:'Reader',verified:true,optOut:false});
 await assertSucceeds(batch.commit());
 await assertFails(updateDoc(doc(client,`professionalRanks/${uid}`),{totalPoints:9999}));
 await assertFails(updateDoc(doc(client,`campusMemberships/${uid}`),{academicYear:5}));
 const board=query(collection(client,'professionalRanks'),where('academicYear','==',year),where('verified','==',true),where('optOut','==',false));
 const rows=await assertSucceeds(getDocs(board));assert.equal(rows.size,1);
 const hide=writeBatch(client);hide.update(doc(client,`campusMemberships/${uid}`),{alias:'Reader',optOut:true,privacyUpdatedAt:serverTimestamp()});hide.delete(doc(client,`professionalRanks/${uid}`));await assertSucceeds(hide.commit());
});
test('admin verification changes must invalidate the public rank atomically',async()=>{
 const uid='revoked';
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),`campusMemberships/${uid}`),{verified:true,firebaseRankConsent:true,academicYear:2,alias:'Reader',optOut:false});
  await setDoc(doc(c.firestore(),`professionalRanks/${uid}`),{uid,verified:true,academicYear:2,alias:'Reader',optOut:false,totalPoints:50});
 });
 await assertFails(updateDoc(doc(admin,`campusMemberships/${uid}`),{verified:false}));
 const batch=writeBatch(admin);batch.delete(doc(admin,`professionalRanks/${uid}`));batch.update(doc(admin,`campusMemberships/${uid}`),{verified:false});await assertSucceeds(batch.commit());
});
test('gaps over 30 seconds and paused intervals earn zero, even when a client asks for credit',async()=>{
 for(const [uid,previousActive,gap] of [['gap-reader',true,31000],['paused-reader',false,15000]]) {
  const client=env.authenticatedContext(uid).firestore(),now=Date.now(),at=Timestamp.fromMillis(now-1000),prev=Timestamp.fromMillis(now-1000-gap),session='e'.repeat(32);
  const old={version:1,session,active:true,closed:false,at,previousAt:prev,previousActive,previousSession:session,totalMs:0,sessionMs:0,deltaMs:0,creditDay:0,creditYear:0,completion:0,academicYear:0};
  await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),`studyUsers/${uid}/state/activity`),old));
  const next={...old,version:2,at:serverTimestamp(),previousAt:at,previousActive:true,creditDay:day(at.toMillis())};
  await assertFails(setDoc(doc(client,`studyUsers/${uid}/state/activity`),{...next,totalMs:gap,sessionMs:gap,deltaMs:gap}));
  await assertSucceeds(setDoc(doc(client,`studyUsers/${uid}/state/activity`),next));
 }
});
test('ten-minute completion is exactly once and no new pulse reopens a closed session',async()=>{
 const uid='completion',client=env.authenticatedContext(uid).firestore(),now=Date.now(),at=Timestamp.fromMillis(now-1000),session='f'.repeat(32),d=day(now-1000);
 const old={version:2,session,active:false,closed:false,at,previousAt:Timestamp.fromMillis(now-2000),previousActive:false,previousSession:session,totalMs:600000,sessionMs:600000,deltaMs:0,creditDay:d,creditYear:0,completion:0,academicYear:0};
 await env.withSecurityRulesDisabled(async c=>{
  await setDoc(doc(c.firestore(),`studyUsers/${uid}/state/activity`),old);
  await setDoc(doc(c.firestore(),`studyUsers/${uid}/verifiedDays/0_${d}`),{day:d,academicYear:0,totalMs:600000,completed:0,bonus:0,lastVersion:2});
 });
 const batch=writeBatch(client);
 batch.set(doc(client,`studyUsers/${uid}/state/activity`),{...old,version:3,closed:true,at:serverTimestamp(),previousAt:at,completion:1});
 batch.set(doc(client,`studyUsers/${uid}/verifiedDays/0_${d}`),{day:d,academicYear:0,totalMs:600000,completed:1,bonus:0,lastVersion:3});
 await assertSucceeds(batch.commit());
 const closed=(await getDoc(doc(client,`studyUsers/${uid}/state/activity`))).data();
 await assertFails(setDoc(doc(client,`studyUsers/${uid}/state/activity`),{...closed,version:4,at:serverTimestamp(),previousAt:closed.at,active:true,closed:false,completion:0}));
});
test('concurrent daily claim transactions grant 100 points once',async()=>{
 const uid='concurrent',client=env.authenticatedContext(uid).firestore(),ref=doc(client,`studyUsers/${uid}/state/wallet`),today=day(Date.now());
 const claim=()=>runTransaction(client,async tx=>{
  const snapshot=await tx.get(ref);
  if(snapshot.exists())return;
  tx.set(ref,{points:100,lastDay:today,streak:1,best:1,days:[today],badges:[],action:'daily',milestone:0,updatedAt:serverTimestamp()});
 });
 await Promise.all([claim(),claim()]);
 assert.equal((await getDoc(ref)).data().points,100);
});
test('personal batches are immutable and never authorize rank or reward changes',async()=>{
 const ref=doc(a,'studyUsers/alice/eventBatches/history');
 await assertSucceeds(setDoc(ref,{events:[{id:'offline-personal-interval',seconds:999999}],receivedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{events:[]}));
 await assertFails(getDoc(doc(b,'studyUsers/alice/eventBatches/history')));
 await assertFails(setDoc(doc(a,'professionalRanks/alice'),{uid:'alice',totalPoints:999999}));
});
test('legacy D1 privacy cannot silently become Firebase ranking consent',async()=>{
 const uid='legacy-private',client=env.authenticatedContext(uid).firestore(),member=doc(client,`campusMemberships/${uid}`),publicRef=doc(client,`professionalRanks/${uid}`);
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),`campusMemberships/${uid}`),{verified:true,academicYear:2,alias:'Legacy',optOut:false}));
 const projection={uid,alias:'Legacy',verified:true,optOut:false,academicYear:2,weekKey:0,weekPoints:0,weekMinutes:0,monthKey:0,monthPoints:0,monthMinutes:0,totalPoints:0,totalMinutes:0,sourceVersion:0};
 await assertFails(setDoc(publicRef,projection));
 const board=query(collection(client,'professionalRanks'),where('academicYear','==',2),where('verified','==',true),where('optOut','==',false));
 await assertFails(getDocs(board));
 const batch=writeBatch(client);
 batch.update(member,{alias:'Legacy',optOut:false,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp()});
 batch.set(publicRef,projection);
 await assertSucceeds(batch.commit());
 await assertSucceeds(getDocs(board));
});
test('unverified students can save private setup without self-verifying or publishing scores',async()=>{
 const uid='pending-learner',client=env.authenticatedContext(uid).firestore(),ref=doc(client,`campusMemberships/${uid}`);
 const prefs={verified:false,academicYear:2,requestedYear:2,alias:'Learner',optOut:false,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp(),verificationRequestedAt:serverTimestamp()};
 await assertSucceeds(setDoc(ref,prefs));
 await assertSucceeds(updateDoc(ref,{alias:'My study name',optOut:true,privacyUpdatedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{verified:true}));
 await assertFails(updateDoc(ref,{academicYear:5}));
 await assertFails(setDoc(doc(client,`professionalRanks/${uid}`),{uid,verified:true,academicYear:2,totalPoints:1000}));
 await assertSucceeds(updateDoc(doc(admin,`campusMemberships/${uid}`),{verified:true}));
 await assertFails(updateDoc(ref,{requestedYear:5,verificationRequestedAt:serverTimestamp()}));
});
