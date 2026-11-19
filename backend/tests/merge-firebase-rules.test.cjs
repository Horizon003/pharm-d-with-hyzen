const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {mergeRules} = require('../tools/merge-firebase-rules.cjs');
const fragment = fs.readFileSync('backend/firebase-study.rules.fragment', 'utf8');
const source = `rules_version = '2';
service cloud.firestore {
 match /databases/{database}/documents {
  // a string with } and { must not change scopes
  function helper() { return 'literal }'; }
  match /settings/{id} { allow read: if true; allow write: if false; }
  match /campusMemberships/{uid} { allow read: if false; }
 }
}`;
test('merge retains unrelated policy and replaces only canonical membership', () => {
 const merged = mergeRules(source, fragment);
 assert.ok(merged.includes("function helper() { return 'literal }'; }"));
 assert.ok(merged.includes('match /settings/{id} { allow read: if true; allow write: if false; }'));
 assert.equal((merged.match(/match \/campusMemberships/g) || []).length, 1);
 assert.ok(merged.includes('!existsAfter(publicRankPath(uid))'));
});
test('merge is idempotent and refuses ambiguous or unmarked native policies', () => {
 const once = mergeRules(source, fragment);
 const twice = mergeRules(once, fragment);
 assert.equal((twice.match(/function studyAdmin/g) || []).length, 1);
 assert.throws(() => mergeRules(source.replace('function helper()', 'function studyAdmin()'), fragment));
 assert.throws(() => mergeRules(source + '\n// BEGIN HYZEN FIREBASE NATIVE STUDY', fragment));
});
