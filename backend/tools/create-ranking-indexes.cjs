// Additive REST creation avoids deleting any existing production indexes.
const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const root = 'https://firestore.googleapis.com/v1';
const database = 'projects/pharmawhisper-debd2/databases/(default)';
function signature(index) {
 return JSON.stringify({queryScope:index.queryScope,fields:index.fields.filter(f=>f.fieldPath!=='__name__').map(f=>({fieldPath:f.fieldPath,order:f.order,arrayConfig:f.arrayConfig,vectorConfig:f.vectorConfig}))});
}
(async()=>{
 const auth=new GoogleAuth({scopes:['https://www.googleapis.com/auth/datastore']});
 const client=await auth.getClient();
 const request=async(url,method='GET',data)=> (await client.request({url,method,data})).data;
 const proposed=JSON.parse(fs.readFileSync('backend/firestore.indexes.json','utf8')).indexes;
 for(const group of [...new Set(proposed.map(i=>i.collectionGroup))]) {
  const url=`${root}/${database}/collectionGroups/${group}/indexes`;
  let page='', existing=[];
  do {
   const data=await request(`${url}${page?'?pageToken='+encodeURIComponent(page):''}`);
   existing.push(...data.indexes||[]); page=data.nextPageToken||'';
  }while(page);
  const operations=[];
  for(const index of proposed.filter(i=>i.collectionGroup===group)) {
   const found=existing.find(i=>signature(i)===signature(index));
   if(found) {
    if(found.state==='NEEDS_REPAIR')throw Error('An existing ranking index requires repair: '+found.name);
    if(found.state!=='READY')operations.push({index:found.name});
    continue;
   }
   const {collectionGroup,...body}=index;
   const operation=await request(url,'POST',body);
   operations.push({operation:operation.name});
  }
  const until=Date.now()+12*60*1000;
  while(operations.length) {
   if(Date.now()>until)throw Error('Ranking indexes still building. Re-run deployment after they finish; prior rules retained.');
   for(let i=operations.length-1;i>=0;i--) {
    const item=operations[i];
    const data=await request(`${root}/${item.operation||item.index}`);
    if(data.error || data.state==='NEEDS_REPAIR')throw Error('Ranking index creation failed.');
    if(data.done || data.state==='READY')operations.splice(i,1);
   }
   if(operations.length)await new Promise(resolve=>setTimeout(resolve,10000));
  }
 }
 console.log('Required ranking indexes ready; existing indexes retained.');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
