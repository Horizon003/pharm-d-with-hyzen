import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture} from './sqlite.js';
import {rememberMember,syncRoster,pulse,syncEvents,readBoard,rankPrivacy,decodeMember} from '../src/ranking.js';
import scoring from '../../backend/functions/scoring.js';
const member=(uid,year=1,college='a')=>({uid,academicYear:year,campusId:college,alias:uid,verified:true,optOut:false});
const session='a'.repeat(32),other='b'.repeat(32),now=Date.parse('2026-11-08T10:00:00Z');
test('all colleges share a professional board; previous professional history remains isolated',async()=>{
  const {db,sql}=fixture();
  const users=[member('a',1,'college-a'),member('b',1,'college-b'),member('c',2,'college-a')];
  for(const m of users){await rememberMember(db,m);sql.prepare('INSERT INTO rank_days VALUES(?,?,?,?,?)').run(m.uid,m.academicYear,'2026-11-08',1200,1);}
  let board=await readBoard(db,users[0],{period:'week'},now);
  assert.deepEqual(board.entries.map(r=>r.uid),['a','b']);
  await rememberMember(db,member('a',2));
  board=await readBoard(db,member('a',2),{period:'semester'},now);
  assert.deepEqual(board.entries.map(r=>r.uid),['c']);assert.equal(board.mine,null);
  assert.equal(sql.prepare('SELECT seconds FROM rank_days WHERE uid=?').get('a').seconds,1200);
  sql.close();
});
test('SQL scores match reference policy with daily caps, sessions, streak and period boundaries',async()=>{
  const {db,sql}=fixture(),m=member('student');await rememberMember(db,m);
  const days={'2026-10-31':{seconds:1200,completed:1},'2026-11-01':{seconds:1200,completed:1},'2026-11-02':{seconds:50000,completed:20},'2026-11-08':{seconds:900,completed:1}};
  for(const [day,d]of Object.entries(days))sql.prepare('INSERT INTO rank_days VALUES(?,?,?,?,?)').run(m.uid,1,day,d.seconds,d.completed);
  for(const period of ['week','month','semester']) {
    const row=(await readBoard(db,m,{period},now)).mine,expected=scoring.score(days,period,'2026-11-08');
    for(const key of ['score','verifiedMinutes','sessions'])assert.equal(row[key],expected[key],`${period}/${key}`);
  }
  sql.close();
});
test('concurrent heartbeats credit a receipt interval only once; stale/midnight gaps earn zero',async()=>{
  const {db,sql}=fixture(),m=member('student');await rememberMember(db,m);
  await pulse(db,m,{session,action:'start'},now);
  const attempts=await Promise.allSettled([pulse(db,m,{session,action:'heartbeat'},now+15000),pulse(db,m,{session,action:'heartbeat'},now+15000)]);
  assert.equal(attempts.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(sql.prepare('SELECT seconds FROM rank_days').get().seconds,15);
  await assert.rejects(pulse(db,m,{session:other,action:'start'},now+16000),/Another device/);
  await pulse(db,m,{session,action:'heartbeat'},now+60000);
  assert.equal(sql.prepare('SELECT seconds FROM rank_days').get().seconds,15);
  const midnight=Date.parse('2026-11-08T19:00:00Z');
  await pulse(db,m,{session,action:'heartbeat'},midnight-10000);
  await pulse(db,m,{session,action:'heartbeat'},midnight+5000);
  assert.equal(sql.prepare('SELECT SUM(seconds) AS seconds FROM rank_days').get().seconds,15);
  sql.close();
});
test('only a stopped ten-minute verified session earns completion once',async()=>{
  const {db,sql}=fixture(),m=member('student');await rememberMember(db,m);
  await pulse(db,m,{session,action:'start'},now);
  for(let i=1;i<=39;i++)await pulse(db,m,{session,action:'heartbeat'},now+i*15000);
  await pulse(db,m,{session,action:'stop'},now+600000);
  await pulse(db,m,{session,action:'stop'},now+610000);
  const day=sql.prepare('SELECT * FROM rank_days').get();
  assert.equal(day.seconds,600);assert.equal(day.completed,1);
  sql.close();
});
test('privacy withdrawal, membership revocation and pagination generation take effect',async()=>{
  const {db,sql}=fixture(),a=member('a'),b=member('b');
  await syncRoster(db,[a,b]);
  for(const m of [a,b])sql.prepare('INSERT INTO rank_days VALUES(?,?,?,?,?)').run(m.uid,1,'2026-11-08',1200,1);
  const initial=await readBoard(db,a,{period:'week'},now);
  await rememberMember(db,a,now+1);
  assert.equal((await readBoard(db,a,{period:'week',generation:initial.generation},now)).status,'ready');
  await rankPrivacy(db,b,{alias:'Private',optOut:true});
  assert.equal((await readBoard(db,a,{period:'week',generation:initial.generation},now)).status,'refresh');
  assert.deepEqual((await readBoard(db,a,{period:'week'},now)).entries.map(r=>r.uid),['a']);
  await rankPrivacy(db,b,{alias:'Back',optOut:false});
  await syncRoster(db,[a]);
  assert.deepEqual((await readBoard(db,a,{period:'week'},now)).entries.map(r=>r.uid),['a']);
  sql.close();
});
test('offline sync is idempotent and immutable and cannot earn ranking credit',async()=>{
  const {db,sql}=fixture();
  const event={id:'c'.repeat(32),session,start:now-10000,end:now,day:'2026-11-08'};
  assert.deepEqual((await syncEvents(db,'user',[event],now)).accepted,[event.id]);
  await syncEvents(db,'user',[event],now);
  await assert.rejects(syncEvents(db,'user',[{...event,start:now-9000}],now),/cannot be rewritten/);
  assert.equal(sql.prepare('SELECT COUNT(*) AS n FROM study_events').get().n,1);
  const hundred=Array.from({length:100},(_,i)=>({...event,id:i.toString(16).padStart(32,'0')}));
  assert.equal((await syncEvents(db,'user',hundred,now)).accepted.length,100);
  assert.equal(sql.prepare('SELECT COUNT(*) AS n FROM study_events').get().n,101);
  assert.equal(sql.prepare('SELECT COUNT(*) AS n FROM rank_days').get().n,0);
  const decoded=decodeMember({name:'documents/campusMemberships/user',fields:{academicYear:{stringValue:'1'},verified:{booleanValue:true}}});
  await assert.rejects(pulse(db,decoded,{session,action:'start'},now),/verified|Verified/);
  sql.close();
});
test('immutable snapshots keep pagination stable while live study changes scores',async()=>{
  const {db,sql}=fixture();
  const users=Array.from({length:35},(_,i)=>member(`learner-${String(i).padStart(2,'0')}`));
  await syncRoster(db,users);
  for(let i=0;i<users.length;i++)sql.prepare('INSERT INTO rank_days VALUES(?,?,?,?,?)').run(users[i].uid,1,'2026-11-08',(40-i)*60,0);
  const first=await readBoard(db,users[0],{period:'week'},now);
  assert.equal(first.entries.length,30);assert.equal(first.next,30);
  sql.prepare('UPDATE rank_days SET seconds=20000 WHERE uid=?').run(users[34].uid);
  const second=await readBoard(db,users[0],{period:'week',generation:first.generation,after:30},now+15000);
  assert.equal(second.status,'ready');assert.equal(second.entries.length,5);
  assert.equal(new Set([...first.entries,...second.entries].map(row=>row.uid)).size,35);
  assert.equal(second.entries.at(-1).uid,users[34].uid);
  const refreshed=await readBoard(db,users[0],{period:'week',generation:first.generation,after:30},now+60001);
  assert.equal(refreshed.status,'refresh');
  const current=await readBoard(db,users[0],{period:'week'},now+60002);
  assert.equal(current.entries[0].uid,users[34].uid);
  assert.equal(sql.prepare('SELECT COUNT(DISTINCT generation) AS n FROM rank_entries').get().n,1);
  sql.close();
});
