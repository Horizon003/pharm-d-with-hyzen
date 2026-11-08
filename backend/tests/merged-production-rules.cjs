const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, getDocs, collection } = require('firebase/firestore');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
 const env = await initializeTestEnvironment({projectId:'hyzen-rules-ci',firestore:{rules:fs.readFileSync('backend/firestore.production.merged.rules','utf8'),host:'127.0.0.1',port:8080}});
 try {
  const owner = env.authenticatedContext('owner',{email:'owner@example.com'}).firestore();
  const stranger = env.authenticatedContext('stranger',{email:'stranger@example.com'}).firestore();
  const admin = env.authenticatedContext('Vv6HtZjmUvfVACzvuyL2pFx5HR33',{email:'admin@example.com'}).firestore();
  const anon = env.unauthenticatedContext().firestore();
  await env.withSecurityRulesDisabled(async ctx=>{
   const db=ctx.firestore();
   await setDoc(doc(db,'studyUsers/owner/notes/one'),{text:'private'});
   await setDoc(doc(db,'campusMemberships/owner'),{verified:true,academicYear:2});
   await setDoc(doc(db,'campusLeaderboards/global'),{rank:1});
   await setDoc(doc(db,'settings/pw_orders'),{secret:'x'});
   await setDoc(doc(db,'settings/public_info'),{value:'ok'});
   await setDoc(doc(db,'students/owner'),{uid:'owner'});
  });
  await assertSucceeds(getDoc(doc(owner,'studyUsers/owner/notes/one')));
  await assertFails(getDoc(doc(stranger,'studyUsers/owner/notes/one')));
  await assertFails(getDoc(doc(anon,'studyUsers/owner/notes/one')));
  await assertFails(setDoc(doc(owner,'studyUsers/owner/notes/new'),{text:'x'}));
  await assertSucceeds(getDoc(doc(owner,'campusMemberships/owner')));
  await assertFails(getDoc(doc(stranger,'campusMemberships/owner')));
  await assertFails(getDocs(collection(owner,'campusMemberships')));
  await assertSucceeds(getDocs(collection(admin,'campusMemberships')));
  await assertFails(setDoc(doc(owner,'campusMemberships/owner'),{verified:true,academicYear:3}));
  await assertFails(setDoc(doc(admin,'campusMemberships/owner'),{verified:true,academicYear:6}));
  await assertSucceeds(setDoc(doc(admin,'campusMemberships/owner'),{verified:true,academicYear:3}));
  await assertFails(getDoc(doc(admin,'campusLeaderboards/global')));
  await assertFails(getDoc(doc(owner,'campusLeaderboards/global')));
  await assertFails(getDoc(doc(owner,'settings/pw_orders')));
  await assertSucceeds(getDoc(doc(admin,'settings/pw_orders')));
  await assertSucceeds(getDoc(doc(anon,'settings/public_info')));
  await assertSucceeds(getDoc(doc(owner,'students/owner')));
  await assertFails(getDoc(doc(stranger,'students/owner')));
  await assertFails(getDocs(collection(owner,'students')));
  await assertSucceeds(getDocs(collection(admin,'students')));
  await assertSucceeds(setDoc(doc(anon,'orders_inbox/test'),{message:'x'}));
  await assertFails(getDoc(doc(anon,'orders_inbox/test')));
  console.log('Merged production Firestore rules access tests PASSED');
 } finally {await env.cleanup();}
})().catch(e=>{console.error(e);process.exitCode=1;});
