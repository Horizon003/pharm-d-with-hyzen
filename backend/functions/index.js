'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {randomUUID}=require('node:crypto');
const {dayAt,validateEvents,score,rank,leaseDelta,professionalGroup}=require('./scoring');
initializeApp();const db=getFirestore();
const options={region:'us-central1',maxInstances:20};
const uidOf=r=>{if(!r.auth)throw new HttpsError('unauthenticated','Sign in first.');return r.auth.uid;};
const eligible=m=>professionalGroup(m)!==null;
const memberRef=uid=>db.collection('campusMemberships').doc(uid);
const userRef=uid=>db.collection('studyUsers').doc(uid);

// Private offline history only. Client timestamps NEVER earn competitive points.
exports.syncStudy=onCall(options,async request=>{
 const uid=uidOf(request);let events;
 try{events=validateEvents(request.data?.events,Date.now());}catch(e){throw new HttpsError('invalid-argument',e.message);}
 const accepted=await db.runTransaction(async tx=>{
  const refs=events.map(e=>userRef(uid).collection('events').doc(e.id));
  const snapshots=refs.length?await tx.getAll(...refs):[];
  for(let i=0;i<events.length;i++){
   if(snapshots[i].exists){const previous=snapshots[i].data();for(const key of ['session','start','end','day'])if(previous[key]!==events[i][key])throw new HttpsError('already-exists','An event ID cannot be rewritten.');}
   else tx.create(refs[i],{...events[i],verified:false,receivedAt:FieldValue.serverTimestamp()});
  }
  return events.map(e=>e.id);
 });
 return {accepted};
});

// One live lease per account; only server receipt times count. The client must
// heartbeat while actively foregrounded. Offline personal time stays private.
exports.studyPulse=onCall(options,async request=>{
 const uid=uidOf(request),{session,action}=request.data||{};
 if(!/^[a-f0-9]{32}$/.test(session)||!['start','heartbeat','pause','stop'].includes(action))throw new HttpsError('invalid-argument','Invalid session action.');
 const now=Date.now();
 return db.runTransaction(async tx=>{
  const member= (await tx.get(memberRef(uid))).data();
  if(!eligible(member))throw new HttpsError('permission-denied','Verified campus membership and ranking consent required.');
  const leaseRef=userRef(uid).collection('state').doc('lease');
  const sessionRef=userRef(uid).collection('verifiedSessions').doc(`${member.academicYear}_${session}`);
  const [leaseDoc,sessionDoc]=await tx.getAll(leaseRef,sessionRef);
  const lease=leaseDoc.data()||{},record=sessionDoc.data()||{seconds:0,completed:false};
  if(record.completed)return {status:'completed',seconds:record.seconds};
  if(action!=='start'&&lease.session!==session)throw new HttpsError('failed-precondition','Start this session first.');
  if(lease.active&&lease.session!==session&&now-lease.last<30000)throw new HttpsError('aborted','Another device has an active session.');
  const zone=member.timezone||'Asia/Karachi',day=dayAt(now,zone);
  // A heartbeat crossing midnight is discarded conservatively; subsequent
  // heartbeats belong to the new campus day, never credited to both days.
  const delta=lease.session===session&&lease.academicYear===member.academicYear&&lease.active&&dayAt(lease.last,zone)===day ? leaseDelta(lease.last,now):0;
  const total=record.seconds+delta;
  const completed=action==='stop'&&total>=600;
  const dayRef=userRef(uid).collection('verifiedDays').doc(`${member.academicYear}_${day}`);
  const dayRecord=(await tx.get(dayRef)).data()||{seconds:0,completed:0};
  tx.set(dayRef,{day,academicYear:member.academicYear,seconds:dayRecord.seconds+delta,completed:dayRecord.completed+(completed?1:0)});
  tx.set(sessionRef,{seconds:total,completed:action==='stop',validCompletion:completed,updatedAt:now});
  tx.set(leaseRef,{session,academicYear:member.academicYear,last:now,active:action==='start'||action==='heartbeat'});
  return {status:action,seconds:total};
 });
});

exports.setRankPrivacy=onCall(options,async request=>{
 const uid=uidOf(request),alias=String(request.data?.alias||'').trim(),optOut=request.data?.optOut;
 if(typeof optOut!=='boolean'||alias.length<1||alias.length>40||/[\r\n\u0000-\u001f]/.test(alias))throw new HttpsError('invalid-argument','Choose an alias of 1–40 characters.');
 await db.runTransaction(async tx=>{
  const ref=memberRef(uid),doc=await tx.get(ref);
  if(!doc.exists)throw new HttpsError('failed-precondition','Campus membership has not been verified.');
  tx.update(ref,{alias,optOut,privacyUpdatedAt:FieldValue.serverTimestamp()});
 });
 return {saved:true};
});

// Immutable generations avoid partially published ranks during chunked writes.
exports.refreshCampusRanks=onSchedule({schedule:'every 15 minutes',region:'us-central1',timeoutSeconds:540},async()=>{
 const members=await db.collection('campusMemberships').where('verified','==',true).get();
 const campuses=new Map(),now=Date.now();
 for(const doc of members.docs){
  const m=doc.data();if(!eligible(m))continue;
  const zone=m.timezone||'Asia/Karachi',today=dayAt(now,zone);
  const history=await userRef(doc.id).collection('verifiedDays').where('academicYear','==',m.academicYear).get();
  const days=Object.fromEntries(history.docs.map(d=>[d.data().day||d.id,d.data()]));
  const group = professionalGroup(m);
  if(!campuses.has(group))campuses.set(group,[]);
  campuses.get(group).push({uid:doc.id,alias:m.alias||'Student',academicYear:m.academicYear,days,today});
 }
 for(const [campus,members]of campuses)for(const period of ['week','month','semester']){
  const ref=db.collection('campusLeaderboards').doc(campus).collection('periods').doc(period);
  const generation=randomUUID(),rows=rank(members.map(({days,today,...m})=>({...m,...score(days,period,today)}))).filter(r=>r.verifiedMinutes>0);
  // Re-rank after filtering zero-minute accounts.
  const published=rank(rows);
  for(let i=0;i<published.length;i+=400){const batch=db.batch();for(const row of published.slice(i,i+400))batch.set(ref.collection('generations').doc(generation).collection('entries').doc(row.uid),row);await batch.commit();}
  await ref.set({generation,updatedAt:FieldValue.serverTimestamp(),total:published.length,policyVersion:2});
 }
});

exports.readCampusBoard=onCall(options,async request=>{
 const uid=uidOf(request),period=request.data?.period;
 if(!['week','month','semester'].includes(period))throw new HttpsError('invalid-argument','Invalid period.');
 const membership=(await memberRef(uid).get()).data();
 if(!eligible(membership))return {status:'Campus verification and ranking consent are required.',entries:[],mine:null};
 const ref=db.collection('campusLeaderboards').doc(`professional-${membership.academicYear}`).collection('periods').doc(period),meta=(await ref.get()).data();
 if(!meta?.generation)return {status:'No verified leaderboard has been published.',entries:[],mine:null};
 const generation=String(request.data?.generation||meta.generation);
 if(generation!==meta.generation)return {status:'refresh',entries:[],mine:null};
 const after=Math.max(0,Number(request.data?.after)||0),entriesRef=ref.collection('generations').doc(generation).collection('entries');
 const page=await entriesRef.orderBy('rank').startAfter(after).limit(30).get();
 const memberships=page.empty?[]:await db.getAll(...page.docs.map(d=>memberRef(d.id)));
 const entries=page.docs.flatMap((d,i)=>{const current=memberships[i].data();return eligible(current)&&current.academicYear===membership.academicYear ? [{...d.data(),alias:current.alias||'Student'}]:[];});
 const mine=(await entriesRef.doc(uid).get()).data()||null;
 return {status:'ready',entries,mine,updatedAt:meta.updatedAt.toMillis(),generation,
   next:page.size===30?page.docs.at(-1).data().rank:null,alias:membership.alias||'Student'};
});
