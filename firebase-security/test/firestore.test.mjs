import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp, query, where, writeBatch, runTransaction, getDocFromServer} from 'firebase/firestore';

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^127\.0\.0\.1:\d+$/.test(host)) throw new Error('Local Firestore emulator required; production is never contacted.');
const admin = 'Vv6HtZjmUvfVACzvuyL2pFx5HR33';
const environments = {};
before(async () => {
  for (const [name,file] of [['baseline','deployed.2026-10-25.rules'],['profile','firestore.profile.rules'],['commerce','firestore.commerce.rules']]) {
    environments[name] = await initializeTestEnvironment({projectId:`demo-hyzen-${name}`,firestore:{host:'127.0.0.1',port:Number(host.split(':')[1]),rules:await readFile(new URL('../'+file,import.meta.url),'utf8')}});
  }
});
beforeEach(async () => { for(const environment of Object.values(environments)) await environment.clearFirestore(); });
after(async () => { for(const environment of Object.values(environments)) await environment.cleanup(); });
const client = (name,uid='alice',claims={}) => environments[name].authenticatedContext(uid,{email:`${uid}@example.test`,...claims}).firestore();
const guest = name => environments[name].unauthenticatedContext().firestore();
const ref = (db,path) => doc(db,path);
const profile = (changes={}) => ({uid:'alice',fullName:'Alice Student',mobile:'+923001234567',gender:'female',city:'Lahore',professionalYear:3,institutionName:'Fixture College',affiliationStatus:'non_affiliated',affiliatedUniversity:null,customUniversity:null,customUniversityCity:null,rollNumber:null,photoUrl:'avatar:hyzen_01',email:'alice@example.test',role:'student',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...changes});
const verification = changes => ({orderNumber:'PW-2026-123456',status:'Pending',payment:'Unpaid',createdAt:'2026-10-25T10:00:00.000Z',trackingId:'',...changes});
const token = 'v_'+'a'.repeat(32);
async function seed(name,path,value) { await environments[name].withSecurityRulesDisabled(context=>setDoc(ref(context.firestore(),path),value)); }

test('live baseline confirms profile gap and unrestricted public verification creation', async()=>{
  await assertFails(setDoc(ref(client('baseline'),'students/alice'),profile()));
  await assertSucceeds(setDoc(ref(guest('baseline'),`verifications/${token}`),{customer:{phone:'fixture-private'},payment:'Paid'}));
  const result=await assertSucceeds(getDoc(ref(guest('baseline'),`verifications/${token}`)));
  assert.equal(result.data().customer.phone,'fixture-private');
});
test('profile rollout adds owner profile creation and owner missing-document reads',async()=>{
  const db=client('profile');
  await assertSucceeds(getDoc(ref(db,'students/alice')));
  await assertSucceeds(setDoc(ref(db,'students/alice'),profile()));
  assert.equal((await assertSucceeds(getDoc(ref(db,'students/alice')))).data().professionalYear,3);
});
test('profile data is unavailable to anonymous and different-account readers and writers',async()=>{
  await assertSucceeds(setDoc(ref(client('profile'),'students/alice'),profile()));
  for(const db of [guest('profile'),client('profile','bob')]){
    await assertFails(getDoc(ref(db,'students/alice')));
    await assertFails(setDoc(ref(db,'students/alice'),profile()));
    await assertFails(updateDoc(ref(db,'students/alice'),{city:'Karachi',updatedAt:serverTimestamp()}));
  }
});
test('students cannot query profiles or impersonate admin through custom claims',async()=>{
  const db=client('profile'); await assertSucceeds(setDoc(ref(db,'students/alice'),profile()));
  await assertFails(getDocs(collection(db,'students')));
  await assertFails(getDocs(query(collection(db,'students'),where('uid','==','alice'))));
  await assertFails(getDoc(ref(client('profile','bob',{admin:true,role:'admin'}),'students/alice')));
  await assertSucceeds(getDoc(ref(client('profile',admin),'students/alice')));
  await assertSucceeds(getDocs(collection(client('profile',admin),'students')));
});
test('valid profile updates and registration-recovery transaction shape retain immutable identity',async()=>{
  const db=client('profile');await assertSucceeds(setDoc(ref(db,'students/alice'),profile()));
  const created=(await getDoc(ref(db,'students/alice'))).data().createdAt;
  await assertSucceeds(updateDoc(ref(db,'students/alice'),{fullName:'Alice Updated',city:'Karachi',professionalYear:4,photoUrl:null,updatedAt:serverTimestamp()}));
  assert.ok((await getDoc(ref(db,'students/alice'))).data().createdAt.isEqual(created));
  await assertFails(deleteDoc(ref(db,'students/alice')));
});
test('uid email role and createdAt cannot change or be removed on updates',async()=>{
  const db=client('profile');await assertSucceeds(setDoc(ref(db,'students/alice'),profile()));
  for(const changes of [{uid:'bob'},{email:'bob@example.test'},{role:'admin'},{createdAt:Timestamp.fromMillis(1)}]){
    await assertFails(updateDoc(ref(db,'students/alice'),{...changes,updatedAt:serverTimestamp()}));
  }
  const current=(await getDoc(ref(db,'students/alice'))).data();delete current.role;
  await assertFails(setDoc(ref(db,'students/alice'),{...current,updatedAt:serverTimestamp()}));
});
test('creation rejects impersonation privilege escalation secrets and unknown fields',async()=>{
  const db=client('profile');
  for(const changes of [{uid:'bob'},{email:'bob@example.test'},{role:'admin'},{password:'should-never-store'},{passwordHash:'secret'},{wallet:100}]){
    await assertFails(setDoc(ref(db,'students/alice'),profile(changes)));
  }
});
test('profile type and length boundaries reject malformed academic and contact fields',async()=>{
  const db=client('profile');
  for(const changes of [{professionalYear:0},{professionalYear:6},{professionalYear:'3'},{gender:'unknown'},{fullName:'ab'},{fullName:'a'.repeat(81)},{mobile:'03001234567'},{city:''},{institutionName:''},{photoUrl:{token:'no'}},{rollNumber:'x'.repeat(101)},{affiliationStatus:'other'}]){
    await assertFails(setDoc(ref(db,'students/alice'),profile(changes)));
  }
});
test('server timestamps are mandatory and token email is matched case-insensitively',async()=>{
  const db=client('profile','alice',{email:'Alice@Example.Test'});
  await assertFails(setDoc(ref(db,'students/alice'),profile({createdAt:Timestamp.fromMillis(1)})));
  await assertFails(setDoc(ref(db,'students/alice'),profile({updatedAt:Timestamp.fromMillis(1)})));
  await assertSucceeds(setDoc(ref(db,'students/alice'),profile()));
  await assertFails(updateDoc(ref(db,'students/alice'),{city:'Daska',updatedAt:Timestamp.fromMillis(1)}));
});
test('known and custom affiliation shapes support actual profile DTO without nested secrets',async()=>{
  const db=client('profile');
  await assertSucceeds(setDoc(ref(db,'students/alice'),profile({affiliationStatus:'affiliated',affiliatedUniversity:{id:'pu',name:'University of the Punjab',shortName:'PU',city:'Lahore'}})));
  await assertFails(updateDoc(ref(db,'students/alice'),{affiliatedUniversity:{id:'pu',name:'PU',shortName:'PU',city:'Lahore',password:'no'},updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref(db,'students/alice'),{affiliatedUniversity:null,customUniversity:'Custom University',customUniversityCity:'Daska',updatedAt:serverTimestamp()}));
});
test('profile rollout preserves legacy public content and privileged settings behavior',async()=>{
  for(const name of ['baseline','profile']){
    await seed(name,'settings/pw_notes_tree',{value:[]});await seed(name,'settings/pw_orders',{value:[]});
    await assertSucceeds(getDoc(ref(guest(name),'settings/pw_notes_tree')));
    await assertFails(getDoc(ref(guest(name),'settings/pw_orders')));
    await assertFails(setDoc(ref(client(name),'settings/pw_notes_tree'),{value:[]}));
    await assertSucceeds(setDoc(ref(client(name,admin),'settings/pw_notes_tree'),{value:[]}));
    await assertSucceeds(getDoc(ref(client(name,admin),'settings/pw_orders')));
  }
});
test('profile rollout preserves anonymous legacy inbox contracts without exposing their contents',async()=>{
  for(const name of ['baseline','profile'])for(const collectionName of ['orders_inbox','messages_inbox']){
    const path=`${collectionName}/fixture`;
    await assertSucceeds(setDoc(ref(guest(name),path),{value:{id:'fixture'},createdAt:123}));
    await assertFails(getDoc(ref(guest(name),path)));
    await assertFails(updateDoc(ref(guest(name),path),{createdAt:456}));
    await assertSucceeds(getDoc(ref(client(name,admin),path)));
    await assertSucceeds(deleteDoc(ref(client(name,admin),path)));
  }
});
test('profile rollout deliberately retains legacy verification contract until coordinated migration',async()=>{
  const db=guest('profile');
  await assertSucceeds(setDoc(ref(db,`verifications/${token}`),{legacy:'fixture',customer:{phone:'fixture-private'}}));
  await assertSucceeds(getDoc(ref(db,`verifications/${token}`)));
  await assertFails(getDocs(collection(client('profile',admin),'verifications')));
  await assertFails(updateDoc(ref(db,`verifications/${token}`),{payment:'Paid'}));
});
test('unimplemented quiz private banks and attempts remain denied even with fake admin claims',async()=>{
  for(const name of ['profile','commerce'])for(const path of ['quiz_question_revisions/private','quiz_attempts_private/attempt','quiz_events/event']){
    await seed(name,path,{correct_option:'private-fixture'});
    for(const db of [guest(name),client(name),client(name,'bob',{admin:true})]){
      await assertFails(getDoc(ref(db,path)));await assertFails(setDoc(ref(db,path),{role:'admin'}));
    }
  }
});
test('separate commerce rollout accepts only bounded private-data-free pending verification creates',async()=>{
  const db=guest('commerce');await assertSucceeds(setDoc(ref(db,`verifications/${token}`),verification()));
  assert.deepEqual((await getDoc(ref(db,`verifications/${token}`))).data(),verification());
  await assertFails(updateDoc(ref(db,`verifications/${token}`),{status:'Delivered'}));
  await assertFails(getDocs(collection(client('commerce',admin),'verifications')));
});
test('commerce rollout blocks forged paid or delivered state and private nested payloads',async()=>{
  const db=guest('commerce');
  for(const changes of [{status:'Delivered'},{payment:'Paid'},{trackingId:'secret'},{customer:{phone:'private'}},{address:{city:'private'}},{items:[{name:'private purchase'}]},{totals:{grandTotal:999}},{status:{email:'private'}}]){
    await assertFails(setDoc(ref(db,`verifications/${token}`),verification(changes)));
  }
  await assertFails(setDoc(ref(db,'verifications/guessable'),verification()));
  await assertFails(setDoc(ref(db,`verifications/${token}`),verification({orderNumber:'malformed'})));
});
test('admin verification replacement removes legacy PII; merge cannot silently retain it',async()=>{
  const path=`verifications/${token}`;await seed('commerce',path,{...verification(),customer:{phone:'legacy-private'},address:{city:'legacy-private'}});
  const db=client('commerce',admin);
  await assertFails(setDoc(ref(db,path),verification({status:'Shipped'}),{merge:true}));
  await assertSucceeds(setDoc(ref(db,path),verification({status:'Shipped',trackingId:'TRACK-fixture'})));
  const result=(await getDoc(ref(guest('commerce'),path))).data();assert.equal(result.customer,undefined);assert.equal(result.address,undefined);
});

// The existing receipt prevents a retry from recreating an already-drained inbox.
test('atomic checkout creates both records and retry cannot recreate drained inbox', async()=>{
  for (const name of ['profile', 'commerce']) {
    const db=guest(name), inbox=ref(db,'orders_inbox/retry-fixture'), receipt=ref(db,`verifications/${token}`);
    const submit=()=>{const batch=writeBatch(db);batch.set(inbox,{value:{id:'retry-fixture'},createdAt:123});batch.set(receipt,verification());return batch.commit();};
    await assertSucceeds(submit());
    await assertFails(submit());
    await assertSucceeds(deleteDoc(ref(client(name,admin),'orders_inbox/retry-fixture')));
    await assertFails(submit());
    assert.equal((await getDoc(ref(client(name,admin),'orders_inbox/retry-fixture'))).exists(),false);
    assert.deepEqual((await getDoc(receipt)).data(), verification());
  }
});
test('failed atomic checkout leaves no orphan verification receipt', async()=>{
  for(const name of ['profile','commerce']) {
    await seed(name,'orders_inbox/collision',{value:{id:'existing'},createdAt:1});
    const db=guest(name), batch=writeBatch(db);
    batch.set(ref(db,'orders_inbox/collision'),{value:{id:'replacement'},createdAt:2});
    batch.set(ref(db,`verifications/${token}`),verification());
    await assertFails(batch.commit());
    assert.equal((await getDoc(ref(db,`verifications/${token}`))).exists(),false);
  }
});

test('transactional receipt check prevents concurrent and post-drain retry even for admin checkout', async()=>{
  for (const name of ['profile','commerce']) for (const privileged of [false,true]) {
    const db=privileged?client(name,admin):guest(name), suffix=privileged?'admin':'guest';
    const path=`orders_inbox/transaction-${suffix}`, inbox=ref(db,path);
    const receipt=ref(db,`verifications/v_${(privileged?'b':'c').repeat(32)}`);
    const submit=async()=>{try {await runTransaction(db,async tx=>{
      const previous=await tx.get(receipt);
      if(previous.exists()) {assert.equal(previous.data().orderNumber,verification().orderNumber);return;}
      tx.set(inbox,{value:{id:suffix},createdAt:123});tx.set(receipt,verification());
    });} catch(error) {
      // Firestore may reject the losing create-only write before retrying a
      // concurrent transaction. The app resolves this via a server receipt.
      const recovered=await getDocFromServer(receipt);
      if(!recovered.exists() || recovered.data().orderNumber!==verification().orderNumber ||
         recovered.data().createdAt!==verification().createdAt) throw error;
    }};
    await Promise.all([assertSucceeds(submit()),assertSucceeds(submit())]);
    await deleteDoc(ref(client(name,admin),path));
    await updateDoc(ref(client(name,admin),receipt.path),{status:'Shipped'});
    await assertSucceeds(submit());
    assert.equal((await getDoc(ref(client(name,admin),path))).exists(),false);
    assert.equal((await getDoc(receipt)).data().status,'Shipped');
  }
});


test('all quiz gameplay namespaces stay private even for the client-side administrator',async()=>{
  const paths=['quiz_control/play','quiz_members/alice','quiz_player_state/alice','quiz_attempts/fixture','quiz_duels/fixture','quiz_duel_requests/fixture','quiz_seen/fixture/questions/q1','quiz_pools/fixture','quiz_publications/q1__v1','quiz_question_revisions/q1__v1'];
  for(const name of ['profile','commerce'])for(const path of paths){
    await seed(name,path,{privateKey:'SECRET'});
    for(const db of [guest(name),client(name),client(name,admin)]){
      await assertFails(getDoc(ref(db,path)));
      await assertFails(setDoc(ref(db,path),{enabled:true,score:999}));
    }
  }
});
