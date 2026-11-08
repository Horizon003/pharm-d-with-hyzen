import scoring from '../../backend/functions/scoring.js';
const {dayAt,periodStart,leaseDelta,validateEvents}=scoring;
const fail=(message,status=400)=>Object.assign(new Error(message),{status});
const validYear=year=>Number.isInteger(year)&&year>=1&&year<=5;

export function decodeMember(doc) {
  const f=doc?.fields||{};
  return {uid:doc?.name?.split('/').at(-1),verified:f.verified?.booleanValue===true,
    academicYear:Number(f.academicYear?.integerValue),campusId:f.campusId?.stringValue,
    alias:f.alias?.stringValue||'Student',optOut:f.optOut?.booleanValue!==false,
    pushOptOut:f.pushOptOut?.booleanValue===true};
}
export async function membership(user,env) {
  const response=await fetch(`https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/campusMemberships/${encodeURIComponent(user.uid)}`,{headers:{Authorization:`Bearer ${user.token}`}});
  if(response.status===404)return {uid:user.uid,verified:false};
  if(!response.ok)throw fail('Verified profile access unavailable. Check the documented Firestore rules.',503);
  return decodeMember(await response.json());
}
function memberStatement(db,m,now) {
  return db.prepare('INSERT INTO rank_members(uid,academic_year,alias,verified,opt_out,checked_at) VALUES(?,?,?,?,?,?) ON CONFLICT(uid) DO UPDATE SET academic_year=excluded.academic_year,alias=excluded.alias,verified=excluded.verified,opt_out=excluded.opt_out,checked_at=excluded.checked_at WHERE academic_year<>excluded.academic_year OR alias<>excluded.alias OR verified<>excluded.verified OR opt_out<>excluded.opt_out')
    .bind(m.uid,validYear(m.academicYear)?m.academicYear:0,String(m.alias||'Student').slice(0,40),m.verified&&validYear(m.academicYear)?1:0,m.optOut===false?0:1,now);
}
// An administrator's complete roster read also removes revoked/deleted members.
// Student calls independently revalidate their own membership before any credit.
export async function syncRoster(db,members,now=Date.now()) {
  await db.prepare('UPDATE rank_members SET verified=0 WHERE verified<>0').run();
  for(let i=0;i<members.length;i+=200)await db.batch(members.slice(i,i+200).map(m=>memberStatement(db,m,now)));
}
export async function rememberMember(db,member,now=Date.now()) {
  await memberStatement(db,member,now).run();
}
async function eligible(db,member) {
  const privacy=await db.prepare('SELECT opt_out FROM rank_privacy WHERE uid=?').bind(member.uid).first();
  return member.verified===true&&validYear(member.academicYear)&&member.optOut===false&&privacy?.opt_out!==1;
}

export async function pulse(db,member,data,now=Date.now()) {
  if(!await eligible(db,member))throw fail('Verified professional year and ranking consent are required.',403);
  const {session,action}=data;
  if(!/^[a-f0-9]{32}$/.test(session)||!['start','heartbeat','pause','stop'].includes(action))throw fail('Invalid session action.');
  const uid=member.uid,year=member.academicYear;
  await db.prepare("INSERT OR IGNORE INTO rank_leases(uid,academic_year,session,last,active,version,operation) VALUES(?,?,?,0,0,0,'')").bind(uid,year,session).run();
  const lease=await db.prepare('SELECT * FROM rank_leases WHERE uid=?').bind(uid).first();
  const record=await db.prepare('SELECT * FROM rank_sessions WHERE uid=? AND academic_year=? AND session=?').bind(uid,year,session).first();
  if(record?.closed)return {status:'completed',seconds:record.seconds};
  if(action!=='start'&&(lease.session!==session||lease.academic_year!==year))throw fail('Start this session first.',409);
  if(lease.active&&lease.session!==session&&now-lease.last<30000)throw fail('Another device has an active session.',409);
  const day=dayAt(now);
  const delta=lease.active&&lease.session===session&&lease.academic_year===year&&dayAt(lease.last)===day?leaseDelta(lease.last,now):0;
  const seconds=(record?.seconds||0)+delta;
  const completed=action==='stop'&&seconds>=600?1:0;
  const op=crypto.randomUUID();
  // D1 batches are atomic. The version compare-and-swap and operation guard
  // prevent two concurrent heartbeats from crediting the same interval twice.
  const result=await db.batch([
    db.prepare('UPDATE rank_leases SET academic_year=?,session=?,last=?,active=?,version=version+1,operation=? WHERE uid=? AND version=?').bind(year,session,now,['start','heartbeat'].includes(action)?1:0,op,uid,lease.version),
    db.prepare('INSERT INTO rank_days(uid,academic_year,day,seconds,completed) SELECT ?,?,?,?,? WHERE EXISTS(SELECT 1 FROM rank_leases WHERE uid=? AND operation=?) ON CONFLICT(uid,academic_year,day) DO UPDATE SET seconds=rank_days.seconds+excluded.seconds,completed=rank_days.completed+excluded.completed').bind(uid,year,day,delta,completed,uid,op),
    db.prepare('INSERT INTO rank_sessions(uid,academic_year,session,seconds,closed) SELECT ?,?,?,?,? WHERE EXISTS(SELECT 1 FROM rank_leases WHERE uid=? AND operation=?) ON CONFLICT(uid,academic_year,session) DO UPDATE SET seconds=excluded.seconds,closed=excluded.closed').bind(uid,year,session,seconds,action==='stop'?1:0,uid,op)
  ]);
  if(!result[0].meta.changes)throw fail('Session changed concurrently. Retry this action.',409);
  return {status:action,seconds};
}

export async function syncEvents(db,uid,events,now=Date.now()) {
  const valid=validateEvents(events,now);
  if(valid.length)await db.batch(valid.map(e=>db.prepare('INSERT OR IGNORE INTO study_events(uid,id,fingerprint,received_at) VALUES(?,?,?,?)').bind(uid,e.id,JSON.stringify(e),now)));
  // A conflicting immutable ID is never acknowledged. Offline events never
  // modify rank_days and therefore cannot manufacture competitive points.
  const stored=valid.length?await db.batch(valid.map(e=>db.prepare('SELECT fingerprint FROM study_events WHERE uid=? AND id=?').bind(uid,e.id))):[];
  for(let i=0;i<valid.length;i++) {
    const e=valid[i],row=stored[i].results[0];
    if(row.fingerprint!==JSON.stringify(e))throw fail('An event ID cannot be rewritten.',409);
  }
  return {accepted:valid.map(e=>e.id)};
}

const boardQuery=`WITH totals AS (
  SELECT m.uid,COALESCE(p.alias,m.alias) AS alias,m.academic_year AS academicYear,
    SUM(MIN(360,CAST(d.seconds/60 AS INTEGER))) AS verifiedMinutes,
    SUM(MIN(5,d.completed)) AS sessions,
    SUM(MIN(360,CAST(d.seconds/60 AS INTEGER))+2*MIN(5,d.completed)+CASE WHEN d.seconds>=900 AND COALESCE(previous.seconds,0)>=900 THEN 5 ELSE 0 END) AS score
  FROM rank_members m JOIN rank_days d ON d.uid=m.uid AND d.academic_year=m.academic_year
  LEFT JOIN rank_privacy p ON p.uid=m.uid
  LEFT JOIN rank_days previous ON previous.uid=d.uid AND previous.academic_year=d.academic_year AND previous.day=date(d.day,'-1 day')
  WHERE m.verified=1 AND m.opt_out=0 AND COALESCE(p.opt_out,0)=0 AND m.academic_year=? AND d.day>=? AND d.day<=?
  GROUP BY m.uid HAVING verifiedMinutes>0
), ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY score DESC,verifiedMinutes DESC,uid ASC) AS rank FROM totals)
SELECT * FROM ranked`;
export async function readBoard(db,member,data,now=Date.now()) {
  if(!['week','month','semester'].includes(data.period))throw fail('Invalid ranking period.');
  if(!await eligible(db,member))return {status:'Verified professional year and ranking consent are required.',entries:[],mine:null};
  const today=dayAt(now),start=periodStart(data.period,today),year=member.academicYear;
  const privacy=await db.prepare('SELECT version FROM rank_revision WHERE id=1').first();
  let meta=await db.prepare('SELECT * FROM rank_boards WHERE academic_year=? AND period=?').bind(year,data.period).first();
  if(!meta||meta.day!==today||meta.revision!==privacy.version||now-meta.updated_at>=60000) {
    const proposed=crypto.randomUUID();
    // A board is published atomically and stays immutable for one minute. Live
    // heartbeats cannot reset every page or silently move rows between pages.
    // Membership/privacy changes invalidate it immediately on the next read.
    await db.batch([
      db.prepare('INSERT INTO rank_boards(academic_year,period,generation,updated_at,revision,day) VALUES(?,?,?,?,?,?) ON CONFLICT(academic_year,period) DO UPDATE SET generation=excluded.generation,updated_at=excluded.updated_at,revision=excluded.revision,day=excluded.day WHERE rank_boards.updated_at<=? OR rank_boards.revision<>excluded.revision OR rank_boards.day<>excluded.day').bind(year,data.period,proposed,now,privacy.version,today,now-60000),
      db.prepare(`INSERT INTO rank_entries(generation,uid,alias,academicYear,verifiedMinutes,sessions,score,rank) SELECT ?,uid,alias,academicYear,verifiedMinutes,sessions,score,rank FROM (${boardQuery}) WHERE EXISTS(SELECT 1 FROM rank_boards WHERE generation=?)`).bind(proposed,year,start,today,proposed),
      db.prepare('DELETE FROM rank_entries WHERE generation NOT IN(SELECT generation FROM rank_boards)')
    ]);
    meta=await db.prepare('SELECT * FROM rank_boards WHERE academic_year=? AND period=?').bind(year,data.period).first();
  }
  const generation=meta.generation;
  if(data.generation&&data.generation!==generation)return {status:'refresh',entries:[],mine:null};
  const after=Math.max(0,Number(data.after)||0);
  const page=await db.prepare('SELECT uid,alias,academicYear,verifiedMinutes,sessions,score,rank FROM rank_entries WHERE generation=? AND rank>? ORDER BY rank LIMIT 30').bind(generation,after).all();
  const mine=await db.prepare('SELECT uid,alias,academicYear,verifiedMinutes,sessions,score,rank FROM rank_entries WHERE generation=? AND uid=?').bind(generation,member.uid).first();
  return {status:'ready',academicYear:year,entries:page.results,mine,updatedAt:meta.updated_at,generation,next:page.results.length===30?page.results.at(-1).rank:null};
}
export async function rankPrivacy(db,member,data) {
  const alias=typeof data.alias==='string'?data.alias.trim():'';
  if(!member.verified||!validYear(member.academicYear))throw fail('Professional year has not been verified.',403);
  if(typeof data.optOut!=='boolean'||alias.length<1||alias.length>40||/[\r\n\u0000-\u001f]/.test(alias))throw fail('Choose an alias of 1–40 characters.');
  await db.prepare('INSERT INTO rank_privacy(uid,alias,opt_out) VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET alias=excluded.alias,opt_out=excluded.opt_out').bind(member.uid,alias,data.optOut?1:0).run();
  return {saved:true};
}
