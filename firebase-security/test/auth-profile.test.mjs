import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,createUserWithEmailAndPassword,signInWithEmailAndPassword,signOut} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,doc,setDoc,getDocFromServer,getDocs,collection,serverTimestamp,terminate} from 'firebase/firestore';
// The Admin SDK is pinned in the sibling backend package; only the emulator
// fixture creates the fixed admin account. No service-account credentials exist.
const backendRequire=createRequire(new URL('../../quiz-backend/package.json',import.meta.url));
const adminApps=backendRequire('firebase-admin/app'),adminAuth=backendRequire('firebase-admin/auth');
// Auth emulator resolves this synthetic API key to the CLI demo project.
const projectId='demo-hyzen-rules';
const adminUid='Vv6HtZjmUvfVACzvuyL2pFx5HR33';
const firestoreHost=process.env.FIRESTORE_EMULATOR_HOST,authHost=process.env.FIREBASE_AUTH_EMULATOR_HOST;
if(!/^127\.0\.0\.1:\d+$/.test(firestoreHost??'') || !/^127\.0\.0\.1:\d+$/.test(authHost??'')) {
  throw new Error('Both loopback emulators required. Production access is forbidden.');
}

test('actual Auth SDK registration login and logout enforce owner and fixed-admin profile access',async()=>{
  const environment=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',
    port:Number(firestoreHost.split(':')[1]),rules:await readFile(new URL('../firestore.profile.rules',import.meta.url),'utf8')}});
  const app=initializeApp({projectId,apiKey:'emulator-fixture-key'},'auth-profile-client');
  const auth=getAuth(app);connectAuthEmulator(auth,`http://${authHost}`,{disableWarnings:true});
  const db=getFirestore(app);connectFirestoreEmulator(db,'127.0.0.1',Number(firestoreHost.split(':')[1]));
  const adminApp=adminApps.initializeApp({projectId},'auth-profile-fixture-admin');
  try {
    await environment.clearFirestore();
    await fetch(`http://${authHost}/emulator/v1/projects/${projectId}/accounts`,{method:'DELETE'});
    const credentials=await createUserWithEmailAndPassword(auth,'owner@example.test','FixtureOnly_123!');
    const uid=credentials.user.uid, target=doc(db,'students',uid);
    await setDoc(target,{uid,fullName:'Fixture Student',mobile:'+923001234567',gender:'female',
      city:'Lahore',professionalYear:2,institutionName:'Fixture College',affiliationStatus:'non_affiliated',
      email:'owner@example.test',role:'student',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
    assert.equal((await getDocFromServer(target)).data().uid,uid);
    await signOut(auth);
    await assert.rejects(()=>getDocFromServer(target),e=>e.code==='permission-denied');
    await signInWithEmailAndPassword(auth,'owner@example.test','FixtureOnly_123!');
    assert.equal((await getDocFromServer(target)).data().fullName,'Fixture Student');
    await signOut(auth);
    await createUserWithEmailAndPassword(auth,'other@example.test','FixtureOnly_123!');
    await assert.rejects(()=>getDocFromServer(target),e=>e.code==='permission-denied');
    await assert.rejects(()=>getDocs(collection(db,'students')),e=>e.code==='permission-denied');
    await signOut(auth);
    await adminAuth.getAuth(adminApp).createUser({uid:adminUid,email:'admin@example.test',password:'FixtureOnly_123!'});
    await signInWithEmailAndPassword(auth,'admin@example.test','FixtureOnly_123!');
    const roster=await getDocs(collection(db,'students'));
    assert.equal(roster.size,1);assert.equal(roster.docs[0].id,uid);
    assert.equal((await getDocFromServer(target)).data().email,'owner@example.test');
  } finally {
    await signOut(auth);await terminate(db);await deleteApp(app);
    await adminApps.deleteApp(adminApp);await environment.cleanup();
  }
});
