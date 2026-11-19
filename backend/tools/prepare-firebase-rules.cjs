// Read-only preparation. Credentials come from ADC; never log access tokens.
const fs = require('node:fs');
const {GoogleAuth} = require('../functions/node_modules/google-auth-library');
const {mergeRules} = require('./merge-firebase-rules.cjs');
const project = 'pharmawhisper-debd2';
(async () => {
  const auth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']});
  const client = await auth.getClient();
  const releaseUrl = `https://firebaserules.googleapis.com/v1/projects/${project}/releases/cloud.firestore`;
  const release = (await client.request({url: releaseUrl})).data;
  const ruleset = (await client.request({url: `https://firebaserules.googleapis.com/v1/${release.rulesetName}`})).data;
  const files = ruleset.source?.files || [];
  if (files.length !== 1 || !files[0].content) throw Error('Multi-file rules need an explicit review.');
  fs.mkdirSync('backend/build/firebase-rollout', {recursive: true});
  fs.writeFileSync('backend/build/firebase-rollout/previous.rules', files[0].content);
  fs.writeFileSync('backend/build/firebase-rollout/previous-release.json', JSON.stringify(release, null, 2));
  const fragment = fs.readFileSync('backend/firebase-study.rules.fragment', 'utf8');
  fs.writeFileSync('backend/build/firebase-rollout/merged.rules', mergeRules(files[0].content, fragment));
  fs.copyFileSync('backend/firestore.indexes.json', 'backend/build/firebase-rollout/indexes.json');
  fs.writeFileSync('backend/build/firebase-rollout/firebase.json', JSON.stringify({firestore: {
    rules: 'merged.rules', indexes: 'indexes.json'
  }, emulators: {firestore: {port: 8080}, ui: {enabled: false}}}, null, 2));
  console.log('Current production rules backed up; merged candidate prepared. No deployment performed.');
})().catch(error => { console.error(error.message); process.exitCode = 1; });
