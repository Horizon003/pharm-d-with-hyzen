export const routes = ['/home','/study','/downloads','/pdf-studio','/study-goals','/study-streak','/campus-rank','/notifications'];
export function validateMessage(value) {
  if (!value || !/^[a-f0-9-]{36}$/i.test(value.id || '')) throw Error('A stable UUID is required.');
  if (typeof value.title !== 'string' || !value.title.trim() || value.title.length > 100) throw Error('Title must be 1–100 characters.');
  if (typeof value.body !== 'string' || !value.body.trim() || value.body.length > 1000) throw Error('Message must be 1–1000 characters.');
  if (!routes.includes(value.route)) throw Error('Unsupported destination.');
  if (!['announcement','material','rank','update','task'].includes(value.category)) throw Error('Unsupported category.');
  if (!['all','college','professional'].includes(value.target)) throw Error('Unsupported audience.');
  if (value.target === 'professional' && ![1,2,3,4,5].includes(value.year)) throw Error('Choose professional year 1–5.');
  if (value.target === 'college' && !/^[\w-]{1,80}$/.test(value.college || '')) throw Error('Choose a verified college ID.');
  if (value.sendAt) throw Error('Scheduled remote sends are not enabled. Use local reminders or send now.');
  return {id:value.id,title:value.title.trim(),body:value.body.trim(),route:value.route,category:value.category,target:value.target,year:value.year||null,college:value.college||null};
}
export function selectRecipients(profiles, message) {
  return [...new Set(profiles.filter(p=>p.verified === true && p.pushOptOut !== true &&
    typeof p.uid === 'string' && p.uid.length > 0 && p.uid.length <= 128 &&
    Number.isInteger(p.academicYear) && p.academicYear >= 1 && p.academicYear <= 5 &&
    (message.target !== 'professional' || p.academicYear === message.year) &&
    (message.target !== 'college' || p.campusId === message.college)).map(p=>p.uid))];
}
