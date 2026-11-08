import {createRemoteJWKSet,jwtVerify} from 'jose';
import {validateMessage,selectRecipients} from './policy.js';
import {materializeRecipients} from './draft.js';
import {decodeMember,membership,rememberMember,syncRoster,pulse,syncEvents,readBoard,rankPrivacy} from './ranking.js';
const keys=createRemoteJWKSet(new URL('https://www.googleapis.com/service_accounts/v1/metadata/jwk/securetoken@system.gserviceaccount.com'));
async function identity(request,env) {
  const token=(request.headers.get('authorization')||'').match(/^Bearer (.+)$/)?.[1];
  if(!token) throw new Error('401');
  let payload;
  try {({payload}=await jwtVerify(token,keys,{algorithms:['RS256'],audience:env.FIREBASE_PROJECT_ID,issuer:`https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,requiredClaims:['sub','iat','exp','auth_time']}));}
  catch {throw Error('401');}
  const now=Date.now()/1000;
  if(typeof payload.sub!=='string' || !payload.sub || payload.sub.length>128 ||
    !Number.isFinite(payload.auth_time) || payload.auth_time<=0 || payload.auth_time>now ||
    !Number.isFinite(payload.iat) || payload.iat>now)throw Error('401');
  return {uid:payload.sub,token};
}
async function profiles(token,env) {
  let page='',rows=[];
  do {
    const url=`https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/campusMemberships?pageSize=300${page?`&pageToken=${encodeURIComponent(page)}`:''}`;
    const response=await fetch(url,{headers:{Authorization:`Bearer ${token}`}});
    if(!response.ok) throw Error('Verified profile access unavailable. Apply the documented Firestore admin rules.');
    const data=await response.json();
    rows.push(...(data.documents||[]).map(decodeMember));
    page=data.nextPageToken||'';
    if(rows.length>3000)throw Error('Audience exceeds the current bounded sender limit.');
  } while(page);
  return rows;
}
async function provider(env,path,method='GET',body) {
  if(!env.ONESIGNAL_REST_API_KEY)throw Error('OneSignal server secret is not configured.');
  const response=await fetch(`https://api.onesignal.com/${path}`,{method,headers:{Authorization:`Key ${env.ONESIGNAL_REST_API_KEY}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  const data=await response.json();
  if(!response.ok)throw Error(`OneSignal request failed (${response.status}). Retry with the same message ID.`);
  return data;
}
export default {
  async fetch(request,env) {
    const origin=request.headers.get('origin');
    const headers={'content-type':'application/json','cache-control':'no-store','access-control-allow-origin':env.ALLOWED_ORIGIN,'access-control-allow-headers':'Authorization,Content-Type','access-control-allow-methods':'GET,POST,OPTIONS','vary':'Origin'};
    const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
    if(origin && origin!==env.ALLOWED_ORIGIN)return reply({error:'Origin forbidden'},403);
    if(request.method==='OPTIONS')return reply({});
    try {
      const user=await identity(request,env),path=new URL(request.url).pathname;
      if(['/syncStudy','/studyPulse','/readCampusBoard','/setRankPrivacy'].includes(path)&&request.method==='POST') {
        const text=await request.text();if(text.length>32768)return reply({error:'Payload too large'},413);
        const data=JSON.parse(text).data||{};
        if(path==='/syncStudy')return reply({result:await syncEvents(env.DB,user.uid,data.events)});
        const member=await membership(user,env);
        await rememberMember(env.DB,member);
        const result=path==='/studyPulse'?await pulse(env.DB,member,data):path==='/setRankPrivacy'?await rankPrivacy(env.DB,member,data):await readBoard(env.DB,member,data);
        return reply({result});
      }
      if((path==='/inbox'||path.startsWith('/inbox/')) && request.method==='GET') {
        const id=path.startsWith('/inbox/')?decodeURIComponent(path.slice(7)):null;
        const query="SELECT m.id,m.title,m.body,m.route,m.category,m.created_at FROM messages m JOIN recipients r ON r.message_id=m.id WHERE r.uid=? AND m.state='accepted'";
        const rows=await (id?env.DB.prepare(`${query} AND m.id=?`).bind(user.uid,id):env.DB.prepare(`${query} ORDER BY m.created_at DESC LIMIT 100`).bind(user.uid)).all();
        return reply({items:rows.results});
      }
      if(user.uid!==env.ADMIN_UID)return reply({error:'Administrator access required'},403);
      if(path==='/history' && request.method==='GET')return reply(await env.DB.prepare('SELECT id,title,body,route,category,state,provider_id,created_at,error FROM messages ORDER BY created_at DESC LIMIT 100').all());
      if(path==='/audiences' && request.method==='GET') {
        const rows=await profiles(user.token,env);
        await syncRoster(env.DB,rows);
        return reply({verified:rows.filter(p=>p.verified).length,colleges:[...new Set(rows.filter(p=>p.verified).map(p=>p.campusId).filter(Boolean))]});
      }
      if(path.startsWith('/status/') && request.method==='GET') {
        const row=await env.DB.prepare('SELECT provider_id FROM messages WHERE id=?').bind(path.split('/').at(-1)).first();
        if(!row?.provider_id)return reply({error:'No provider message exists yet'},404);
        const result=await provider(env,`notifications/${row.provider_id}?app_id=${env.ONESIGNAL_APP_ID}`);
        return reply({successful:result.successful,failed:result.failed,errored:result.errored,received:result.received,converted:result.converted});
      }
      if(path==='/send' && request.method==='POST') {
        if(Number(request.headers.get('content-length')||0)>8192)return reply({error:'Payload too large'},413);
        const text=await request.text();if(text.length>8192)return reply({error:'Payload too large'},413);
        const message=validateMessage(JSON.parse(text));
        const fingerprint=JSON.stringify(message);
        let row=await env.DB.prepare('SELECT * FROM messages WHERE id=?').bind(message.id).first();
        if(row && row.fingerprint!==fingerprint)return reply({error:'Message ID belongs to different content'},409);
        if(row?.provider_id)return reply({id:row.provider_id,state:row.state,reused:true});
        if(row&&Date.now()-row.created_at>86400000)return reply({error:'This unsent draft has expired. Create a new notification after reviewing provider history.'},410);
        if(!row) {
          const audience=selectRecipients(await profiles(user.token,env),message);
          if(!audience.length)return reply({error:'No eligible verified recipients'},422);
          await env.DB.prepare('INSERT OR IGNORE INTO messages(id,fingerprint,title,body,route,category,audience,state,created_at) VALUES(?,?,?,?,?,?,?,?,?)').bind(message.id,fingerprint,message.title,message.body,message.route,message.category,JSON.stringify(audience),'pending',Date.now()).run();
          row=await env.DB.prepare('SELECT * FROM messages WHERE id=?').bind(message.id).first();
        }
        if(row.fingerprint!==fingerprint)return reply({error:'Conflicting message ID'},409);
        // Repair an interrupted recipient write before retrying the same send.
        await materializeRecipients(env.DB,row,fingerprint);
        try {
          const result=await provider(env,'notifications','POST',{app_id:env.ONESIGNAL_APP_ID,target_channel:'push',include_aliases:{external_id:JSON.parse(row.audience)},headings:{en:message.title},contents:{en:message.body},data:{route:message.route,messageId:message.id,category:message.category},idempotency_key:message.id});
          if(!result.id)throw Error('OneSignal found no subscribed recipients.');
          await env.DB.prepare("UPDATE messages SET provider_id=?,state='accepted',error=NULL WHERE id=?").bind(result.id,message.id).run();
          return reply({id:result.id,state:'accepted',recipients:result.recipients});
        } catch(error) {
          // Another retry may already have persisted provider acceptance. A late
          // network failure must not hide that accepted message from its inbox.
          await env.DB.prepare("UPDATE messages SET state='retryable',error=? WHERE id=? AND provider_id IS NULL").bind(error.message,message.id).run();throw error;
        }
      }
      return reply({error:'Not found'},404);
    }catch(error){return reply({error:error.message==='401'?'Sign in required':error.message},error.message==='401'?401:error.status||400);}
  }
};
