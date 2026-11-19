// Standard Firebase Rules REST publication. Ruleset creation performs server
// compilation; the emulator security suite must pass before calling this tool.
const fs=require('node:fs');
const root='https://firebaserules.googleapis.com/v1';
async function publishRules(client,previous,source){
 const url=`${root}/${previous.name}`;
 async function unchanged(){
  const current=(await client.request({url})).data;
  if(current.rulesetName!==previous.rulesetName)throw Error('Production rules changed since backup. Re-run preparation and tests before publishing.');
 }
 await unchanged();
 const ruleset=(await client.request({url:`${root}/projects/pharmawhisper-debd2/rulesets`,method:'POST',data:{source:{files:[{name:'firestore.rules',content:source}]}}})).data;
 if(!ruleset.name?.startsWith('projects/')||!ruleset.name.includes('/rulesets/'))throw Error('Rules compiler returned no valid ruleset.');
 await unchanged();
 await client.request({url,method:'PATCH',data:{release:{name:previous.name,rulesetName:ruleset.name}}});
 const deployed=(await client.request({url})).data;
 if(deployed.rulesetName!==ruleset.name)throw Error('Published ruleset could not be confirmed.');
 return deployed;
}
module.exports={publishRules};
if(require.main===module){
 (async()=>{
  const {GoogleAuth}=require('../functions/node_modules/google-auth-library');
  const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const folder='backend/build/firebase-rollout/';
  const previous=JSON.parse(fs.readFileSync(folder+'previous-release.json','utf8'));
  const deployed=await publishRules(client,previous,fs.readFileSync(folder+'merged.rules','utf8'));
  fs.writeFileSync(folder+'deployed-release.json',JSON.stringify(deployed,null,2));
  console.log('Firestore rules published and active release confirmed: '+deployed.rulesetName);
 })().catch(e=>{console.error(e.message);process.exitCode=1;});
}
