const {test,before,after}=require('node:test');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteDoc,collection,getDocs}=require('firebase/firestore');
const fs=require('node:fs');let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-hyzen-study',firestore:{rules:fs.readFileSync('../study.rules','utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();await setDoc(doc(db,'studyUsers/alice/events/event'),{seconds:10});
  await setDoc(doc(db,'campusMemberships/alice'),{verified:true,campusId:'campus',optOut:false});
  await setDoc(doc(db,'campusLeaderboards/campus/periods/week'),{generation:'test'});
 });
});
after(async()=>{await env.cleanup();});
test('owner may read private events; guests and other accounts cannot',async()=>{
 await assertSucceeds(getDoc(doc(env.authenticatedContext('alice').firestore(),'studyUsers/alice/events/event')));
 await assertFails(getDoc(doc(env.authenticatedContext('bob').firestore(),'studyUsers/alice/events/event')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'studyUsers/alice/events/event')));
});
test('clients cannot forge study events or self-verify campus membership',async()=>{
 const db=env.authenticatedContext('alice').firestore();
 await assertFails(setDoc(doc(db,'studyUsers/alice/events/new'),{seconds:999999}));
 await assertFails(setDoc(doc(db,'campusMemberships/alice'),{verified:true,campusId:'other'}));
 await assertSucceeds(getDoc(doc(db,'campusMemberships/alice')));
 await assertFails(getDocs(collection(db,'campusMemberships')));
});
test('only the existing admin can list and maintain canonical professional membership',async()=>{
 const db=env.authenticatedContext('Vv6HtZjmUvfVACzvuyL2pFx5HR33').firestore();
 await assertSucceeds(getDocs(collection(db,'campusMemberships')));
 await assertSucceeds(setDoc(doc(db,'campusMemberships/bob'),{verified:true,academicYear:2,campusId:'other-college',optOut:false}));
 await assertFails(setDoc(doc(db,'campusMemberships/bad'),{verified:true,academicYear:6}));
 await assertFails(setDoc(doc(db,'campusMemberships/bad'),{verified:true,academicYear:'2'}));
 await assertFails(getDoc(doc(env.authenticatedContext('alice').firestore(),'campusMemberships/bob')));
 await assertFails(setDoc(doc(env.authenticatedContext('bob').firestore(),'campusMemberships/bob'),{verified:true,academicYear:5}));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'campusMemberships')));
});
test('leaderboards require server privacy filtering, never direct client reads/writes',async()=>{
 const db=env.authenticatedContext('alice').firestore();
 await assertFails(getDoc(doc(db,'campusLeaderboards/campus/periods/week')));
 await assertFails(setDoc(doc(db,'campusLeaderboards/campus/periods/week'),{score:99999}));
});
test('membership deletion, verification and consent cannot be changed by students',async()=>{
 const admin=env.authenticatedContext('Vv6HtZjmUvfVACzvuyL2pFx5HR33').firestore();
 const student=env.authenticatedContext('carol').firestore();
 await assertSucceeds(setDoc(doc(admin,'campusMemberships/carol'),{verified:true,academicYear:5,optOut:true,pushOptOut:true}));
 await assertFails(setDoc(doc(student,'campusMemberships/carol'),{verified:true,academicYear:1,optOut:false,pushOptOut:false}));
 await assertFails(deleteDoc(doc(student,'campusMemberships/carol')));
 for(const academicYear of [0,-1,1.5,6])await assertFails(setDoc(doc(admin,'campusMemberships/invalid'),{verified:true,academicYear}));
 await assertFails(setDoc(doc(admin,'campusMemberships/invalid'),{verified:'true',academicYear:1}));
 await assertSucceeds(deleteDoc(doc(admin,'campusMemberships/carol')));
});
