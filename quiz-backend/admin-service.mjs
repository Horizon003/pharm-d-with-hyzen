import {createHash} from 'node:crypto';
import {FieldPath} from 'firebase-admin/firestore';
import {QuizImportService, ImportError} from './import-service.mjs';
const fail = code => { throw new ImportError(code); };
const hash = value => createHash('sha256').update(value).digest('hex');
const revisionId = value => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}__v[1-9][0-9]*$/.test(value);
const keys = (value, allowed) => {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).some(k => !allowed.includes(k))) fail('invalid_request');
};
// A deliberate allowlist: neither import actor IDs nor private audit records
// are part of question content. Only allowlisted administrators see answer keys.
function question(id, q) {
  if (!q || id !== `${q.questionId}__v${q.version}` || !Number.isSafeInteger(q.version) || q.version < 1 ||
      !Number.isInteger(q.professionalYear) || q.professionalYear < 1 || q.professionalYear > 5 ||
      typeof q.subject !== 'string' || typeof q.topic !== 'string' ||
      typeof q.stem !== 'string' || q.stem.length < 5 || q.stem.length > 8000 ||
      !q.options || !['A','B','C','D'].every(k => typeof q.options[k] === 'string' && q.options[k].length > 0 && q.options[k].length <= 2000) ||
      !['A','B','C','D'].includes(q.correctOption) || typeof q.explanation !== 'string') fail('revision_unavailable');
  return {revision:id, questionId:q.questionId, version:q.version, professionalYear:q.professionalYear,
    subject:q.subject, topic:q.topic, stem:q.stem,
    options:Object.fromEntries(['A','B','C','D'].map(k => [k,q.options[k]])),
    correctOption:q.correctOption, explanation:q.explanation, difficulty:q.difficulty ?? ''};
}
export class QuizAdminService extends QuizImportService {
  async listQuestions(auth, data) {
    this.authorize(auth); keys(data, ['after']);
    if (data.after !== undefined && !revisionId(data.after)) fail('invalid_request');
    const [control,taxonomy] = await this.db.getAll(this.control,this.taxonomy);
    this.config(control.data(),taxonomy.data());
    let query = this.db.collection('quiz_question_revisions').orderBy(FieldPath.documentId()).limit(21);
    if (data.after) query = query.startAfter(data.after);
    const snapshot = await query.get(), page = snapshot.docs.slice(0,20);
    return {items:page.map(s => {const q=question(s.id,s.data()); return {
      revision:q.revision, questionId:q.questionId, professionalYear:q.professionalYear,
      subject:q.subject, topic:q.topic, stem:q.stem};}),
      nextCursor:snapshot.size > 20 ? page.at(-1).id : null};
  }
  async reviewQuestion(auth,data) {
    this.authorize(auth); keys(data,['revision']);
    if (!revisionId(data.revision)) fail('invalid_request');
    return this.db.runTransaction(async tx => {
      const [control,taxonomy,revision,publication] = await tx.getAll(this.control,this.taxonomy,
        this.db.doc('quiz_question_revisions/'+data.revision),this.db.doc('quiz_publications/'+data.revision));
      this.config(control.data(),taxonomy.data());
      const content=question(data.revision,revision.data());
      return {question:content,contentHash:hash(JSON.stringify(content)),
        enabled:publication.data()?.enabled===true,publicationVersion:publication.data()?.version ?? 0};
    });
  }
  async setPublication(auth,data) {
    this.authorize(auth); keys(data,['revision','contentHash','enabled','reviewed','expectedVersion','requestId']);
    if (!revisionId(data.revision) || typeof data.contentHash !== 'string' || !/^[a-f0-9]{64}$/.test(data.contentHash) ||
        typeof data.enabled !== 'boolean' || data.reviewed !== true || !Number.isSafeInteger(data.expectedVersion) || data.expectedVersion < 0 ||
        typeof data.requestId !== 'string' || !/^[A-Za-z0-9_-]{16,100}$/.test(data.requestId)) fail('invalid_request');
    const publication=this.db.doc('quiz_publications/'+data.revision);
    const audit=this.db.doc('quiz_publication_audit/'+hash(auth.uid+'\0'+data.requestId));
    const requestHash=hash(JSON.stringify([data.revision,data.contentHash,data.enabled,data.expectedVersion]));
    return this.db.runTransaction(async tx => {
      const [control,taxonomy,revision,previous,operation]=await tx.getAll(this.control,this.taxonomy,
        this.db.doc('quiz_question_revisions/'+data.revision),publication,audit);
      this.config(control.data(),taxonomy.data());
      const content=question(data.revision,revision.data());
      if (hash(JSON.stringify(content)) !== data.contentHash) fail('confirmation_mismatch');
      if (operation.exists) {
        const old=operation.data();
        if (old.requestHash !== requestHash) fail('confirmation_mismatch');
        return {revision:data.revision,enabled:old.enabled,version:old.version};
      }
      const version=previous.data()?.version ?? 0;
      if (!Number.isSafeInteger(version) || version !== data.expectedVersion) fail('publication_conflict');
      const topics=taxonomy.data().years[String(content.professionalYear)]?.subjects[content.subject]?.topics;
      if (data.enabled && !topics?.includes(content.topic)) fail('taxonomy_changed');
      const result={revision:data.revision,enabled:data.enabled,version:version+1};
      tx.set(publication,{...result,contentHash:data.contentHash,reviewedBy:auth.uid,reviewedAt:this.now()});
      tx.create(audit,{...result,actorUid:auth.uid,requestHash,createdAt:this.now()});
      return result;
    });
  }
}
