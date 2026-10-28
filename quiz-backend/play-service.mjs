import {createHash, randomInt, randomBytes} from 'node:crypto';

export class PlayError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = code => { throw new PlayError(code); };
const hash = value => createHash('sha256').update(value).digest('hex');
const plain = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const id = x => typeof x === 'string' && /^[A-Za-z0-9_-]{16,100}$/.test(x);
const poolId = x => typeof x === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(x);
const keys = (x, allowed) => { if (!plain(x) || Object.keys(x).some(k => !allowed.includes(k))) fail('invalid_request'); };
const day = now => new Intl.DateTimeFormat('en-CA', {timeZone:'Asia/Karachi',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
const hour = 3600000;
const poolHash = p => hash(JSON.stringify([p.professionalYear,p.questionCount,p.durationSeconds,p.opensAt,p.closesAt,p.revisions]));
const active = (state, now) => state?.activeId && state.activeUntil > now;
const questionDto = q => ({id:q.questionId, stem:q.stem, options:{A:q.options.A,B:q.options.B,C:q.options.C,D:q.options.D}});
function validateAnswers(answers, questions) {
  if (!plain(answers) || Object.keys(answers).length > questions.length) fail('invalid_answers');
  const ids = new Set(questions.map(q => q.questionId));
  for (const [key, value] of Object.entries(answers)) if (!ids.has(key) || !['A','B','C','D'].includes(value)) fail('invalid_answers');
  return Object.fromEntries(Object.entries(answers));
}
function score(attempt) {
  let correct = 0;
  for (const q of attempt.questions) if (attempt.answers[q.questionId] === q.correctOption) correct++;
  return {correct, total:attempt.questions.length, answered:Object.keys(attempt.answers).length};
}
function validatePolicy(policy) {
  // Explicit server approval is required. This implementation deliberately
  // supports only this documented, non-monetary scoring contract.
  if (policy?.enabled !== true || policy.approved !== true) fail('feature_disabled');
  if (policy.version !== 'free-v1' || policy.timezone !== 'Asia/Karachi' ||
      policy.correctPoints !== 1 || policy.wrongPoints !== 0 || policy.tie !== 'shared' ||
      policy.dailyCap !== 3 || policy.cooldownSeconds !== 3600) fail('policy_unavailable');
}
function validatePool(pool, year, now) {
  if (!pool || pool.enabled !== true || pool.professionalYear !== year ||
      !Number.isSafeInteger(pool.questionCount) || pool.questionCount < 1 || pool.questionCount > 20 ||
      !Number.isSafeInteger(pool.durationSeconds) || pool.durationSeconds < 30 || pool.durationSeconds > 1800 ||
      !Number.isSafeInteger(pool.opensAt) || !Number.isSafeInteger(pool.closesAt) ||
      now < pool.opensAt || now >= pool.closesAt ||
      !Array.isArray(pool.revisions) || pool.revisions.length < pool.questionCount || pool.revisions.length > 200 ||
      new Set(pool.revisions).size !== pool.revisions.length ||
      pool.revisions.some(x => typeof x !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}__v[1-9][0-9]*$/.test(x))) fail('pool_unavailable');
}
function validateQuestion(q, year) {
  return q && q.professionalYear === year && typeof q.questionId === 'string' &&
    /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(q.questionId) &&
    typeof q.stem === 'string' && q.stem.length >= 5 && q.stem.length <= 8000 &&
    plain(q.options) && ['A','B','C','D'].every(k => typeof q.options[k] === 'string' && q.options[k].length > 0 && q.options[k].length <= 2000) &&
    ['A','B','C','D'].includes(q.correctOption);
}

/** Private Admin SDK service. All collections remain denied to client SDKs. */
export class QuizPlayService {
  constructor(db, {now=()=>Date.now(), choose=randomInt}={}) { this.db=db; this.now=now; this.choose=choose; }
  auth(auth) { if (!auth?.uid || typeof auth.uid !== 'string' || auth.uid.includes('/')) fail('unauthenticated'); return auth.uid; }
  ref(path) { return this.db.doc(path); }
  member(uid) { return this.ref('quiz_members/'+uid); }
  state(uid) { return this.ref('quiz_player_state/'+uid); }
  attempt(uid, key) { return this.ref('quiz_attempts/'+hash(uid+'\0'+key)); }
  authorizeMember(member) {
    // Membership/year is provisioned by a trusted administrator. A student's
    // self-edited academic profile cannot move their competition eligibility.
    if (!member || member.enabled !== true || !Number.isInteger(member.professionalYear) ||
        member.professionalYear < 1 || member.professionalYear > 5) fail('membership_required');
  }
  quota(state, now) {
    if (active(state, now)) fail('attempt_active');
    if (state?.lastStartedAt != null && now < state.lastStartedAt + hour) fail('cooldown');
    if (state?.day === day(now) && state.count >= 3) fail('daily_limit');
  }
  charge(tx, uid, state, attemptId, deadline, now) {
    tx.set(this.state(uid), {day:day(now),count:state?.day===day(now)?state.count+1:1,
      lastStartedAt:now,activeId:attemptId,lastAttemptId:attemptId,activeUntil:deadline}, {merge:true});
  }
  async allocate(tx, pool, uids, year) {
    const revisions = await tx.getAll(...pool.revisions.map(r => this.ref('quiz_question_revisions/'+r)));
    const publications = await tx.getAll(...pool.revisions.map(r => this.ref('quiz_publications/'+r)));
    const candidates = revisions.flatMap((s,i) => {
      const q=s.data(), publication=publications[i].data();
      return validateQuestion(q,year) && publication?.enabled===true && publication.revision===pool.revisions[i]
        ? [{...q, revision:pool.revisions[i]}] : [];
    });
    // Deduplicate question IDs across revisions: a new revision never resets
    // per-user no-repeat history.
    const unique = [...new Map(candidates.map(q => [q.questionId,q])).values()];
    if (unique.length < pool.questionCount) fail('insufficient_questions');
    const seen = await tx.getAll(...uids.flatMap(uid => unique.map(q => this.ref(`quiz_seen/${hash(uid)}/questions/${q.questionId}`))));
    const available = unique.filter((q,i) => uids.every((_,u) => !seen[u*unique.length+i].exists));
    if (available.length < pool.questionCount) fail('insufficient_questions');
    for (let i=available.length-1;i>0;i--) { const j=this.choose(i+1); [available[i],available[j]]=[available[j],available[i]]; }
    return available.slice(0,pool.questionCount);
  }
  reserve(tx, questions, uids, now) {
    for (const uid of uids) for (const q of questions) tx.create(this.ref(`quiz_seen/${hash(uid)}/questions/${q.questionId}`),{firstAssignedAt:now});
  }
  record(uid, pool, poolName, questions, now, duelId=null) {
    return {uid,poolId:poolName,professionalYear:pool.professionalYear,questions,answers:{},revision:0,
      state:'active',startedAt:now,deadline:Math.min(now+pool.durationSeconds*1000,pool.closesAt),
      policyVersion:'free-v1',duelId};
  }
  dto(attemptId, a, now, duel=null) {
    const result={attemptId,state:a.state,serverNow:now,startedAt:a.startedAt,deadline:a.deadline,
      revision:a.revision,answers:a.answers,questions:a.questions.map(questionDto),duelId:a.duelId};
    if (a.state==='submitted') result.result=score(a);
    if (duel) {
      result.duelState=duel.state;
      if (duel.state==='complete') {
        result.duelResult=duel.scores[0]===duel.scores[1]?'draw':duel.uids[duel.scores[0]>duel.scores[1]?0:1]===a.uid?'won':'lost';
        result.opponentCorrect=duel.scores[duel.uids[0]===a.uid?1:0];
      }
    }
    // Never return keys/explanations, even after submission: another player
    // might still be answering the same question in a different attempt.
    return result;
  }
  async lobby(auth,data) {
    const uid=this.auth(auth); keys(data,[]);
    const [control,member,state]=await this.db.getAll(this.ref('quiz_control/play'),this.member(uid),this.state(uid));
    validatePolicy(control.data());this.authorizeMember(member.data());const now=this.now(),s=state.data();
    const pools=await this.db.collection('quiz_pools').where('professionalYear','==',member.data().professionalYear).limit(50).get();
    const available=[];
    for(const snapshot of pools.docs){const p=snapshot.data();try{validatePool(p,member.data().professionalYear,now);}catch{continue;}
      available.push({id:snapshot.id,title:typeof p.title==='string'?p.title.slice(0,120):'Practice quiz',questionCount:p.questionCount,durationSeconds:p.durationSeconds});}
    return {serverNow:now,professionalYear:member.data().professionalYear,pools:available,
      attemptsToday:s?.day===day(now)?s.count??0:0,cooldownUntil:s?.lastStartedAt?s.lastStartedAt+hour:0,
      lastAttemptId:s?.lastAttemptId??null,lastDuelCode:s?.lastDuelCode??null};
  }
  async start(auth, data) {
    const uid=this.auth(auth); keys(data,['poolId','requestId']);
    if (!poolId(data.poolId)||!id(data.requestId)) fail('invalid_request');
    const target=this.attempt(uid,data.requestId);
    return this.db.runTransaction(async tx => {
      const [control,member,state,pool,old]=await tx.getAll(this.ref('quiz_control/play'),this.member(uid),this.state(uid),this.ref('quiz_pools/'+data.poolId),target);
      validatePolicy(control.data()); this.authorizeMember(member.data());
      const now=this.now();
      if (old.exists) {
        if (old.data().poolId!==data.poolId||old.data().duelId) fail('request_conflict');
        return this.dto(target.id,old.data(),now);
      }
      validatePool(pool.data(),member.data().professionalYear,now); this.quota(state.data(),now);
      const questions=await this.allocate(tx,pool.data(),[uid],member.data().professionalYear);
      const assignedAt=this.now(); validatePool(pool.data(),member.data().professionalYear,assignedAt);
      const a=this.record(uid,pool.data(),data.poolId,questions,assignedAt);
      this.reserve(tx,questions,[uid],assignedAt); tx.create(target,a); this.charge(tx,uid,state.data(),target.id,a.deadline,assignedAt);
      return this.dto(target.id,a,assignedAt);
    });
  }
  async createDuel(auth, data) {
    const uid=this.auth(auth); keys(data,['poolId','requestId']);
    if (!poolId(data.poolId)||!id(data.requestId)) fail('invalid_request');
    // Server-generated secret code; client idempotency keys need not be secret.
    const proposedCode=randomBytes(32).toString('hex');
    const requestRef=this.ref('quiz_duel_requests/'+hash(uid+'\0'+data.requestId));
    return this.db.runTransaction(async tx => {
      const [control,member,state,pool,request]=await tx.getAll(this.ref('quiz_control/play'),this.member(uid),this.state(uid),this.ref('quiz_pools/'+data.poolId),requestRef);
      validatePolicy(control.data()); this.authorizeMember(member.data()); const now=this.now();
      const code=request.exists?request.data().code:proposedCode,target=this.ref('quiz_duels/'+code);
      const old=await tx.get(target);
      if (old.exists) {
        if (old.data().poolId!==data.poolId) fail('request_conflict');
        return {code,state:old.data().state,expiresAt:old.data().expiresAt,serverNow:now};
      }
      validatePool(pool.data(),member.data().professionalYear,now); this.quota(state.data(),now);
      const s=state.data();
      if (s?.inviteDay===day(now)&&s.inviteCount>=3) fail('invitation_limit');
      const expiresAt=Math.min(now+10*60000,pool.data().closesAt);
      tx.create(requestRef,{code});
      tx.create(target,{host:uid,poolId:data.poolId,year:member.data().professionalYear,poolHash:poolHash(pool.data()),state:'waiting',expiresAt,createdAt:now});
      tx.set(this.state(uid),{activeId:code,lastDuelCode:code,activeUntil:expiresAt,inviteDay:day(now),inviteCount:s?.inviteDay===day(now)?s.inviteCount+1:1},{merge:true});
      return {code,state:'waiting',expiresAt,serverNow:now};
    });
  }
  async joinDuel(auth, data) {
    const uid=this.auth(auth); keys(data,['code']);
    if (typeof data.code!=='string'||!/^[a-f0-9]{64}$/.test(data.code)) fail('invalid_request');
    const duelRef=this.ref('quiz_duels/'+data.code);
    return this.db.runTransaction(async tx => {
      const [control,ds,member,state]=await tx.getAll(this.ref('quiz_control/play'),duelRef,this.member(uid),this.state(uid));
      validatePolicy(control.data()); this.authorizeMember(member.data()); const d=ds.data(),now=this.now();
      if (!d||d.host===uid) fail('duel_unavailable');
      if (d.state==='active'||d.state==='complete') {
        if (!d.uids.includes(uid)) fail('duel_unavailable');
        const a=await tx.get(this.ref('quiz_attempts/'+d.attemptIds[1]));
        return this.dto(a.id,a.data(),now,d);
      }
      if (d.state!=='waiting'||now>=d.expiresAt||member.data().professionalYear!==d.year) fail('duel_unavailable');
      const [hostMember,hostState,pool]=await tx.getAll(this.member(d.host),this.state(d.host),this.ref('quiz_pools/'+d.poolId));
      this.authorizeMember(hostMember.data());
      if (hostMember.data().professionalYear!==d.year||hostState.data()?.activeId!==data.code) fail('duel_unavailable');
      validatePool(pool.data(),d.year,now); if(poolHash(pool.data())!==d.poolHash)fail('pool_changed'); this.quota(state.data(),now);
      this.quota({...hostState.data(),activeId:null},now);
      const uids=[d.host,uid],questions=await this.allocate(tx,pool.data(),uids,d.year);
      const refs=uids.map(u=>this.attempt(u,'duel_'+data.code));
      const assignedAt=this.now(); if(assignedAt>=d.expiresAt)fail('duel_unavailable'); validatePool(pool.data(),d.year,assignedAt);
      const attempts=uids.map(u=>this.record(u,pool.data(),d.poolId,questions,assignedAt,data.code));
      this.reserve(tx,questions,uids,assignedAt);
      for(let i=0;i<2;i++) {tx.create(refs[i],attempts[i]);this.charge(tx,uids[i],i===0?hostState.data():state.data(),refs[i].id,attempts[i].deadline,assignedAt);}
      tx.update(duelRef,{state:'active',uids,attemptIds:refs.map(r=>r.id),deadline:attempts[0].deadline});
      return this.dto(refs[1].id,attempts[1],assignedAt,{state:'active'});
    });
  }
  async duelStatus(auth, data) {
    const uid=this.auth(auth); keys(data,['code']);
    if(typeof data.code!=='string'||!/^[a-f0-9]{64}$/.test(data.code))fail('invalid_request');
    const d=(await this.ref('quiz_duels/'+data.code).get()).data(),now=this.now();
    if(!d||(d.host!==uid&&!d.uids?.includes(uid)))fail('duel_unavailable');
    if(d.state==='cancelled')return {state:'cancelled',serverNow:now};
    if(d.state==='waiting')return {state:now>=d.expiresAt?'expired':'waiting',expiresAt:d.expiresAt,serverNow:now};
    return this.get(auth,{attemptId:d.attemptIds[d.uids.indexOf(uid)]});
  }
  async cancelDuel(auth,data) {
    const uid=this.auth(auth);keys(data,['code']);
    if(typeof data.code!=='string'||!/^[a-f0-9]{64}$/.test(data.code))fail('invalid_request');
    return this.db.runTransaction(async tx=>{
      const ref=this.ref('quiz_duels/'+data.code),[ds,state]=await tx.getAll(ref,this.state(uid));
      const d=ds.data();if(!d||d.host!==uid)fail('duel_unavailable');
      if(d.state==='cancelled')return {state:'cancelled'};
      if(d.state!=='waiting')fail('duel_started');
      tx.update(ref,{state:'cancelled'});
      if(state.data()?.activeId===data.code)tx.set(this.state(uid),{activeId:null,activeUntil:0},{merge:true});
      return {state:'cancelled'};
    });
  }
  async get(auth,data) { return this.update(auth,data,'get'); }
  async save(auth,data) { return this.update(auth,data,'save'); }
  async submit(auth,data) { return this.update(auth,data,'submit'); }
  async update(auth,data,operation) {
    const uid=this.auth(auth);keys(data,operation==='get'?['attemptId']:['attemptId','revision','answers']);
    if(typeof data.attemptId!=='string'||!/^[a-f0-9]{64}$/.test(data.attemptId))fail('invalid_request');
    if(operation!=='get'&&(!Number.isSafeInteger(data.revision)||data.revision<0))fail('invalid_request');
    const target=this.ref('quiz_attempts/'+data.attemptId);
    return this.db.runTransaction(async tx=>{
      const [snapshot,control,member]=await tx.getAll(target,this.ref('quiz_control/play'),this.member(uid));
      validatePolicy(control.data());this.authorizeMember(member.data());
      let a=snapshot.data();if(!a||a.uid!==uid)fail('attempt_unavailable');
      const now=this.now();let duel=null,other=null,otherRef=null,duelRef=null;
      if(a.duelId){
        duelRef=this.ref('quiz_duels/'+a.duelId);duel=(await tx.get(duelRef)).data();
        if(!duel||!duel.uids?.includes(uid))fail('attempt_unavailable');
        otherRef=this.ref('quiz_attempts/'+duel.attemptIds[duel.uids[0]===uid?1:0]);
        other=(await tx.get(otherRef)).data();
      }
      let changed=false;
      if(a.state==='active'){
        if(now>=a.deadline){a={...a,state:'submitted',submittedAt:a.deadline};changed=true;}
        else if(operation!=='get'){
          const answers=validateAnswers(data.answers,a.questions);
          if(data.revision!==a.revision) {
            // A lost-response retry with the same saved payload is safe;
            // stale different answers never overwrite a newer device save.
            if(data.revision===a.revision-1&&JSON.stringify(Object.entries(answers).sort())===JSON.stringify(Object.entries(a.answers).sort())&&operation==='save')return this.dto(target.id,a,now,duel);
            fail('revision_conflict');
          }
          a={...a,answers,revision:a.revision+1,...(operation==='submit'?{state:'submitted',submittedAt:now}:{})};changed=true;
        }
      }
      // No reads after writes. Both opponents settle together on a deadline;
      // only answers received before it count, never a client clock/duration.
      if(other?.state==='active'&&now>=other.deadline){other={...other,state:'submitted',submittedAt:other.deadline};tx.set(otherRef,other);}
      if(changed)tx.set(target,a);
      if(duel&&duel.state!=='complete'&&a.state==='submitted'&&other.state==='submitted'){
        const scores=duel.uids[0]===uid?[score(a).correct,score(other).correct]:[score(other).correct,score(a).correct];
        duel={...duel,state:'complete',scores,completedAt:now};tx.set(duelRef,duel);
      }
      return this.dto(target.id,a,now,duel);
    });
  }
}
