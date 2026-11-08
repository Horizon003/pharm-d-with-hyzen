'use strict';
const DAY = 86400000;
function professionalGroup(member) {
  if (member?.verified !== true || member.optOut !== false ||
      !Number.isInteger(member.academicYear) || member.academicYear < 1 || member.academicYear > 5) return null;
  return `professional-${member.academicYear}`;
}
function dayAt(ms, zone = 'Asia/Karachi') {
  const parts = new Intl.DateTimeFormat('en-CA', {timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit'}).formatToParts(ms);
  const get = type => parts.find(p => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
function validateEvents(events, now) {
  if (!Array.isArray(events) || events.length > 100) throw Error('Batch limit is 100');
  const unique = new Map();
  for (const e of events) {
    if (!e || !/^[a-f0-9]{32}$/.test(e.id) || !/^[a-f0-9]{32}$/.test(e.session) ||
        !Number.isSafeInteger(e.start) || !Number.isSafeInteger(e.end) || e.end <= e.start ||
        e.end - e.start > 30000 || e.end > now + 60000 || e.start < now - 365 * DAY ||
        !/^\d{4}-\d{2}-\d{2}$/.test(e.day)) throw Error('Invalid event');
    const date = Date.parse(e.day + 'T00:00:00Z');
    if (!Number.isFinite(date) || new Date(date).toISOString().slice(0,10) !== e.day ||
        e.start < date - 14 * 3600000 || e.end > date + DAY + 14 * 3600000) throw Error('Invalid local date');
    const value = {id:e.id, session:e.session, start:e.start, end:e.end, day:e.day};
    if (unique.has(e.id) && JSON.stringify(unique.get(e.id)) !== JSON.stringify(value)) throw Error('Conflicting duplicate');
    unique.set(e.id, value);
  }
  return [...unique.values()];
}
function unionSeconds(intervals) {
  const sorted = intervals.map(p => [...p]).sort((a,b) => a[0]-b[0]);
  let total = 0, end = -Infinity;
  for (const [a,b] of sorted) { if (b > a) { total += Math.max(0,b-Math.max(a,end)); end = Math.max(end,b); } }
  return Math.floor(total / 1000);
}
function periodStart(period, today) {
  const date = new Date(today + 'T00:00:00Z');
  if (period === 'week') date.setUTCDate(date.getUTCDate() - (date.getUTCDay()+6)%7);
  else if (period === 'month') date.setUTCDate(1);
  else if (period === 'semester') { return '2000-01-01'; }
  else throw Error('Invalid period');
  return date.toISOString().slice(0,10);
}
function score(days, period, today) {
  const start = periodStart(period,today);
  let minutes=0, points=0, sessions=0;
  for(const [day, value] of Object.entries(days)) {
    if (day < start || day > today) continue;
    const seconds = Math.max(0, Number(value.seconds)||0);
    const dailyMinutes = Math.min(360,Math.floor(seconds/60));
    const completed = Math.min(5, Math.max(0,Number(value.completed)||0));
    const previous = new Date(Date.parse(day+'T00:00:00Z')-DAY).toISOString().slice(0,10);
    minutes += dailyMinutes; sessions += completed;
    points += dailyMinutes + 2*completed + (seconds >= 900 && (days[previous]?.seconds||0) >= 900 ? 5 : 0);
  }
  return {score:points, verifiedMinutes:minutes, sessions, periodStart:start, policyVersion:2};
}
function rank(rows) {
  return [...rows].sort((a,b) => b.score-a.score || b.verifiedMinutes-a.verifiedMinutes || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0))
    .map((row,i) => ({...row,rank:i+1}));
}
function leaseDelta(last, now) { return Number.isFinite(last) && now >= last && now-last <= 30000 ? Math.floor((now-last)/1000) : 0; }
module.exports = {DAY,dayAt,validateEvents,unionSeconds,periodStart,score,rank,leaseDelta,professionalGroup};
