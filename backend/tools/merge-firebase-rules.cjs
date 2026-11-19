const fs = require('node:fs');
const BEGIN = '// BEGIN HYZEN FIREBASE NATIVE STUDY';
const END = '// END HYZEN FIREBASE NATIVE STUDY';
// Mask comments/strings while preserving offsets and structural braces.
function structural(source) {
  return source.replace(/\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"/g,
    text => text.replace(/[^\n]/g, ' '));
}
function closeBrace(mask, opening) {
  let depth = 0;
  for (let i = opening; i < mask.length; i++) {
    if (mask[i] === '{') depth++;
    if (mask[i] === '}' && --depth === 0) return i;
  }
  throw Error('Unbalanced Firestore rules; source left untouched.');
}
function mergeRules(original, fragment) {
  let source = original;
  const start = source.indexOf(BEGIN), end = source.indexOf(END);
  if ((start >= 0) !== (end >= 0)) throw Error('Incomplete native-study markers.');
  if (start >= 0) {
    if (end < start || source.indexOf(BEGIN, start + BEGIN.length) >= 0) throw Error('Ambiguous native-study markers.');
    source = source.slice(0, start) + source.slice(end + END.length);
  }
  let mask = structural(source);
  const root = /match\s+\/databases\/\{[^}]+\}\/documents\s*\{/g;
  const roots = [...mask.matchAll(root)];
  if (roots.length !== 1) throw Error('Expected exactly one database documents scope.');
  const opening = roots[0].index + roots[0][0].length - 1;
  let closing = closeBrace(mask, opening);
  const membership = /match\s+\/campusMemberships\/\{[^}]+\}\s*\{/g;
  const blocks = [...mask.matchAll(membership)];
  if (blocks.length > 1) throw Error('Multiple membership rules require manual review.');
  if (blocks.length) {
    const block = blocks[0], at = block.index;
    const to = closeBrace(mask, at + block[0].length - 1) + 1;
    if (at <= opening || to > closing) throw Error('Membership outside expected scope.');
    source = source.slice(0, at) + source.slice(to);
    closing -= to - at;
    mask = structural(source);
  }
  // Refuse unmarked previous native implementations instead of OR-ing two policies.
  if (/function\s+(studyAdmin|studyOwner|statePath|projectedRank)\s*\(/.test(mask) ||
      /match\s+\/(studyUsers\/\{[^}]+\}\/state|professionalRanks)\//.test(mask)) {
    throw Error('Unmarked native-study policy exists; review before merging.');
  }
  return source.slice(0, closing).trimEnd() + '\n\n' + BEGIN + '\n' +
    fragment.trimEnd() + '\n' + END + '\n  ' + source.slice(closing);
}
module.exports = {mergeRules};
if (require.main === module) {
  const [, , source, output] = process.argv;
  if (!source || !output) throw Error('Usage: node merge-firebase-rules.cjs current.rules merged.rules');
  fs.writeFileSync(output, mergeRules(fs.readFileSync(source, 'utf8'),
    fs.readFileSync('backend/firebase-study.rules.fragment', 'utf8')));
}
