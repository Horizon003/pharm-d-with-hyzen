const {test}=require('node:test');const assert=require('node:assert/strict');
const {dayAt,validateEvents,unionSeconds,periodStart,score,rank,leaseDelta,professionalGroup}=require('./scoring');
test('ranking combines colleges and separates professional years',()=>{
 const member={verified:true,optOut:false,academicYear:1,campusId:'college-a'};
 assert.equal(professionalGroup(member),professionalGroup({...member,campusId:'college-b'}));
 assert.notEqual(professionalGroup(member),professionalGroup({...member,academicYear:2}));
 assert.equal(professionalGroup({...member,campusId:undefined}),'professional-1');
 assert.equal(professionalGroup({...member,verified:false}),null);
 assert.equal(professionalGroup({...member,optOut:true}),null);
 assert.equal(professionalGroup({...member,academicYear:'1'}),null);
});
test('campus date and semester boundaries use campus calendar',()=>{
 assert.equal(dayAt(Date.parse('2026-11-07T20:00:00Z')),'2026-11-08');
 assert.equal(periodStart('semester','2026-06-30'),'2000-01-01');
 assert.equal(periodStart('semester','2026-07-01'),'2000-01-01');
 assert.equal(periodStart('week','2026-11-08'),'2026-11-02');
});
test('duplicates, overlaps and out-of-order intervals count once',()=>assert.equal(unionSeconds([[1000,11000],[0,5000],[1000,11000],[10000,15000]]),15));
test('daily scored minutes and session caps',()=>assert.deepEqual(score({'2026-11-07':{seconds:30000,completed:99}},'week','2026-11-07'),{score:370,verifiedMinutes:360,sessions:5,periodStart:'2026-11-02',policyVersion:2}));
test('15-minute consecutive-day bonus starts on day two',()=>{
 const days={'2026-11-05':{seconds:900},'2026-11-06':{seconds:899},'2026-11-07':{seconds:900},'2026-11-08':{seconds:900}};
 assert.equal(score(days,'week','2026-11-07').score,44);
 assert.equal(score(days,'week','2026-11-08').score,64);
});
test('deterministic ties and periods exclude future/outside records',()=>{
 assert.deepEqual(rank([{uid:'z',score:1,verifiedMinutes:2},{uid:'a',score:1,verifiedMinutes:2}]).map(r=>r.uid),['a','z']);
 assert.equal(score({'2026-12-01':{seconds:900},'2026-10-31':{seconds:900}},'month','2026-11-07').score,0);
});
test('validation rejects spoofed dates, future times and conflicting ids',()=>{
 const now=Date.parse('2026-11-07T12:00:00Z'),e={id:'a'.repeat(32),session:'b'.repeat(32),start:now-1000,end:now,day:'2026-11-07'};
 assert.equal(validateEvents([e,e],now).length,1);
 assert.throws(()=>validateEvents([e,{...e,end:now-1}],now));
 assert.throws(()=>validateEvents([{...e,day:'2026-02-30'}],now));
 assert.throws(()=>validateEvents([{...e,end:now+120000}],now));
});
test('server leases reject long disconnects and clock reversal',()=>{
 assert.equal(leaseDelta(0,10000),10);assert.equal(leaseDelta(0,31000),0);assert.equal(leaseDelta(10000,0),0);
});
