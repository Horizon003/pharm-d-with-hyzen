// Opt-in production smoke test. Uses two isolated temporary users and removes
// all their data in finally. Never touches student records or settings trees.
const assert=require('node:assert/strict');
const requireBackend=require('node:module').createRequire(require('node:path').resolve(__dirname,'../functions/package.json'));
const fs=require('node:fs');
const {randomUUID}=require('node:crypto');
const adminApp=requireBackend('firebase-admin/app');
const {getAuth}=requireBackend('firebase-admin/auth');
const {getFirestore}=requireBackend('firebase-admin/firestore');
const {initializeApp,deleteApp}=requireBackend('firebase/app');
const {getAuth:clientAuth,signInWithCustomToken,signOut}=requireBackend('firebase/auth');
const {getFirestore:clientDb,doc,setDoc,getDocFromServer,updateDoc,deleteDoc,writeBatch,serverTimestamp,collection,query,where,orderBy,limit,getDocsFromServer,getCountFromServer}=requireBackend('firebase/firestore');
const projectId='pharmawhisper-debd2';
const day=ms=>Math.floor((ms+18000000)/86400000);
(async()=>{
 if(process.env.HYZEN_LIVE_FIREBASE_CHECK!=='yes')throw Error('Explicit live-check opt-in is required.');
 if(process.argv.includes('--permissions-only')){
  const {GoogleAuth}=requireBackend('google-auth-library');
  const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const wanted=['datastore.indexes.list','datastore.indexes.create','datastore.indexes.get','datastore.operations.get','firebaserules.releases.get','firebaserules.releases.update','firebaserules.rulesets.create','firebase.projects.get','serviceusage.services.get'];
  const result=await client.request({url:`https://cloudresourcemanager.googleapis.com/v1/projects/${projectId}:testIamPermissions`,method:'POST',data:{permissions:wanted}});
  const allowed=result.data.permissions||[];
  console.log(JSON.stringify({allowed,missing:wanted.filter(p=>!allowed.includes(p))}));
  return;
 }
 const source=fs.readFileSync('hyzen_flutter/lib/core/firebase/firebase_options.dart','utf8').split('FirebaseOptions web = FirebaseOptions(')[1].split(');')[0];
 const config={projectId,apiKey:source.match(/apiKey:\s*'([^']+)'/)[1],appId:source.match(/appId:\s*'([^']+)'/)[1]};
 const credentialFile=process.env.GOOGLE_APPLICATION_CREDENTIALS;
 const credentials=credentialFile?JSON.parse(fs.readFileSync(credentialFile,'utf8')):null;
 if(credentials?.project_id && credentials.project_id!==projectId)throw Error('Smoke-check credentials belong to a different project.');
 const credential=credentials?.private_key?adminApp.cert(credentials):adminApp.applicationDefault();
 const admin=adminApp.initializeApp({credential,projectId});
 const auth=getAuth(admin),db=getFirestore(admin),prefix='hyzen-ci-smoke-'+randomUUID(),uids=[prefix+'-a',prefix+'-b'],apps=[];
 const checks=[];
 const denied=promise=>assert.rejects(promise,e=>e.code==='permission-denied');
 try {
  for(const uid of uids){
   const app=initializeApp(config,uid);apps.push(app);
   await signInWithCustomToken(clientAuth(app),await auth.createCustomToken(uid));
  }
  const a=clientDb(apps[0]),b=clientDb(apps[1]),uid=uids[0];
  const clock=doc(a,`studyUsers/${uid}/state/clock`);
  await setDoc(clock,{at:serverTimestamp()});
  const at=(await getDocFromServer(clock)).data().at,today=day(at.toMillis());
  const wallet=doc(a,`studyUsers/${uid}/state/wallet`);
  await setDoc(wallet,{points:100,lastDay:today,streak:1,best:1,days:[today],badges:[],action:'daily',milestone:0,updatedAt:serverTimestamp()});
  assert.equal((await getDocFromServer(wallet)).data().points,100);checks.push('authenticated daily claim persisted');
  await denied(updateDoc(wallet,{points:200,updatedAt:serverTimestamp()}));checks.push('double credit denied');
  await denied(getDocFromServer(doc(b,`studyUsers/${uid}/state/wallet`)));checks.push('cross-account wallet read denied');
  const event=doc(a,`studyUsers/${uid}/calendar/smoke`);
  const date=new Date(today*86400000).toISOString().slice(0,10);
  await setDoc(event,{title:'Temporary CI check',at:new Date().toISOString(),day:date,color:0xffd46a61,kind:'Test',leadMinutes:30,updatedAt:serverTimestamp()});
  assert.equal((await getDocFromServer(event)).data().title,'Temporary CI check');
  await denied(getDocFromServer(doc(b,`studyUsers/${uid}/calendar/smoke`)));
  await deleteDoc(event);assert.equal((await getDocFromServer(event)).exists(),false);checks.push('calendar round trip and privacy');
  const pulse=doc(a,`studyUsers/${uid}/state/activity`),session=randomUUID().replaceAll('-','');
  await setDoc(pulse,{version:1,session,active:true,closed:false,at:serverTimestamp(),previousAt:serverTimestamp(),previousActive:false,previousSession:session,totalMs:0,sessionMs:0,deltaMs:0,creditDay:0,creditYear:0,completion:0,academicYear:0});
  let old=(await getDocFromServer(pulse)).data();
  await new Promise(r=>setTimeout(r,150));
  await setDoc(pulse,{...old,version:2,at:serverTimestamp(),previousAt:old.at,previousActive:true,creditDay:day(old.at.toMillis())});
  old=(await getDocFromServer(pulse)).data();
  const delta=old.at.toMillis()-old.previousAt.toMillis(),d=day(old.at.toMillis());
  assert.ok(delta>0&&delta<=30000&&d===day(old.previousAt.toMillis()),'Unexpected server interval; do not grant invented credit');
  const batch=writeBatch(a);
  batch.set(pulse,{...old,version:3,active:false,at:serverTimestamp(),previousAt:old.at,totalMs:delta,sessionMs:delta,deltaMs:delta,creditDay:d});
  batch.set(doc(a,`studyUsers/${uid}/verifiedDays/0_${d}`),{day:d,academicYear:0,totalMs:delta,completed:0,bonus:0,lastVersion:3});
  await batch.commit();assert.equal((await getDocFromServer(pulse)).data().totalMs,delta);checks.push('server-timestamp study credit committed');
  await denied(updateDoc(pulse,{totalMs:999999,at:serverTimestamp()}));checks.push('forged study time denied');
  const member=doc(a,`campusMemberships/${uid}`);
  await setDoc(member,{verified:false,academicYear:5,requestedYear:5,alias:'Temporary QA',optOut:true,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp(),verificationRequestedAt:serverTimestamp()});
  assert.equal((await getDocFromServer(member)).data().verified,false);
  await updateDoc(member,{alias:'Temporary QA saved',optOut:false,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp()});
  await denied(updateDoc(member,{verified:true}));
  assert.equal((await getDocFromServer(doc(a,`professionalRanks/${uid}`))).exists(),false);
  checks.push('pending-year display name/privacy saved without self-verification or public score');
  // Zero-score QA participant exercises real ranking indexes without appearing
  // in the app's points>0 board or altering any student's competitive position.
  await db.doc(`campusMemberships/${uid}`).set({verified:true,academicYear:5,alias:'Temporary QA',optOut:true});
  const rank={academicYear:5,weekKey:0,weekPoints:0,weekMinutes:0,monthKey:0,monthPoints:0,monthMinutes:0,totalPoints:0,totalMinutes:0,sourceVersion:0};
  const consent=writeBatch(a);
  consent.update(doc(a,`campusMemberships/${uid}`),{alias:'Temporary QA',optOut:false,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp()});
  consent.set(doc(a,`professionalRanks/${uid}`),{...rank,uid,alias:'Temporary QA',verified:true,optOut:false});
  await consent.commit();
  for(const prefix of ['week','month','total']){
   let filters=[where('academicYear','==',5),where('verified','==',true),where('optOut','==',false)];
   if(prefix!=='total')filters.push(where(prefix+'Key','==',prefix==='week'?Math.floor((today+3)/7):new Date(today*86400000).getUTCFullYear()*12+new Date(today*86400000).getUTCMonth()+1));
   const base=()=>query(collection(a,'professionalRanks'),...filters);
   await getDocsFromServer(query(base(),where(prefix+'Points','>',0),orderBy(prefix+'Points','desc'),orderBy(prefix+'Minutes','desc'),orderBy('uid'),limit(30)));
   await getCountFromServer(query(base(),where(prefix+'Points','>',0)));
   await getCountFromServer(query(base(),where(prefix+'Points','==',0),where(prefix+'Minutes','>',0)));
   await getCountFromServer(query(base(),where(prefix+'Points','==',0),where(prefix+'Minutes','==',0),where('uid','<',uid)));
  }
  checks.push('week/month/professional ranking queries and rank-count indexes');
  const hide=writeBatch(a);
  hide.update(doc(a,`campusMemberships/${uid}`),{alias:'Temporary QA',optOut:true,firebaseRankConsent:true,privacyUpdatedAt:serverTimestamp()});
  hide.delete(doc(a,`professionalRanks/${uid}`));await hide.commit();
  assert.equal((await getDocFromServer(doc(a,`professionalRanks/${uid}`))).exists(),false);checks.push('ranking consent and opt-out removal');

 } finally {
  let cleanupError;
  for(const app of apps){await signOut(clientAuth(app)).catch(()=>{});await deleteApp(app);}
  for(const uid of uids){
   try{await db.doc(`professionalRanks/${uid}`).delete();await db.doc(`campusMemberships/${uid}`).delete();await db.recursiveDelete(db.doc(`studyUsers/${uid}`));await auth.deleteUser(uid).catch(e=>{if(e.code!=='auth/user-not-found')throw e;});}
   catch(e){cleanupError=e;console.error('QA cleanup incomplete for '+uid);}
  }
  await adminApp.deleteApp(admin);
  if(cleanupError)throw cleanupError;
 }
 console.log(JSON.stringify({projectId,checks,temporaryUsersRemoved:true}));
})().catch(e=>{console.error(e.code||'',e.message);process.exitCode=1;});
