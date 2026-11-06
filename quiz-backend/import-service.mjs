import {randomUUID, createHash} from 'node:crypto';
import {parse} from 'csv-parse/sync';

export class ImportError extends Error {
  constructor(code, details={}) { super(code); this.code=code;this.details=details; }
}
const fail=(code,details)=>{throw new ImportError(code,details);};
const required=['question_id','professional_year','subject','topic','question','option_a','option_b','option_c','option_d','correct_option'];
const optional=['explanation','difficulty','status'];
const columns=[...required,...optional];
const limits={question_id:128,subject:150,topic:180,question:8000,explanation:12000,option_a:2000,option_b:2000,option_c:2000,option_d:2000};
const hash=value=>createHash('sha256').update(value).digest('hex');
const plain=value=>value!==null && typeof value==='object' && !Array.isArray(value);
const canonical=value=>JSON.stringify(value===null||typeof value!=='object'?value:Array.isArray(value)?value.map(v=>JSON.parse(canonical(v))):Object.fromEntries(Object.keys(value).sort().map(k=>[k,JSON.parse(canonical(value[k]))])));

export function validateTaxonomy(value) {
  if(!plain(value)||value.schema_version!==1||value.approved!==true||typeof value.version!=='string'||!/^[A-Za-z0-9_.-]{1,60}$/.test(value.version)||!plain(value.years)||!Object.keys(value.years).length) fail('taxonomy_unavailable');
  for(const [year,record] of Object.entries(value.years)){
    if(!['1','2','3','4','5'].includes(year)||!plain(record)||!plain(record.subjects)||!Object.keys(record.subjects).length)fail('taxonomy_unavailable');
    for(const [subject,info] of Object.entries(record.subjects)){
      if(!subject.trim()||subject.length>150||!plain(info)||!Array.isArray(info.topics)||!info.topics.length||new Set(info.topics).size!==info.topics.length||info.topics.some(t=>typeof t!=='string'||!t.trim()||t.length>180)) fail('taxonomy_unavailable');
    }
  }
  return hash(canonical({schema_version:1,version:value.version,years:value.years}));
}

export function validateCsv(csv,taxonomy) {
  validateTaxonomy(taxonomy);
  if(typeof csv!=='string'||Buffer.byteLength(csv,'utf8')>256*1024||Buffer.from(csv,'utf8').toString('utf8')!==csv||csv.includes('\0'))fail('invalid_csv',{line:1,field:'file',reason:'invalid_encoding_or_size'});
  let entries;
  try{entries=parse(csv,{bom:true,info:true,relax_column_count:true,max_record_size:60000});}
  catch(error){fail('invalid_csv',{line:Number.isSafeInteger(error.lines)&&error.lines>0?error.lines:1,field:'file',reason:'malformed_csv'});}
  const header=entries[0]?.record??[];
  if(new Set(header).size!==header.length||required.some(k=>!header.includes(k))||header.some(k=>!columns.includes(k)))fail('invalid_csv',{line:1,field:'header',reason:'invalid_columns'});
  const rows=[],seen=new Set();let previous=entries[0].info.lines;
  for(const entry of entries.slice(1)){
    const line=previous+1;previous=entry.info.lines;
    if(entry.record.every(v=>!v.trim()))continue;
    const error=(field,reason)=>fail('invalid_csv',{line,field,reason});
    if(rows.length>=200)error('file','maximum_200_rows_per_transaction');
    if(entry.record.length!==header.length)error('row','wrong_column_count');
    const item=Object.fromEntries(header.map((key,i)=>[key,entry.record[i].trim()]));
    for(const field of required)if(!item[field])error(field,'required');
    for(const [field,text] of Object.entries(item)){
      if(text.length>(limits[field]??128))error(field,'too_long');
      if(/^[=+\-@]/.test(text))error(field,'spreadsheet_formula_prefix');
      if(/<\s*(?:\/?[A-Za-z][^>]*|!DOCTYPE[^>]*)>/i.test(text))error(field,'html_not_allowed');
    }
    if(!/^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(item.question_id))error('question_id','unsafe_id');
    if(seen.has(item.question_id))error('question_id','duplicate_in_batch');seen.add(item.question_id);
    const subjects=taxonomy.years[item.professional_year]?.subjects;
    if(!Object.hasOwn(taxonomy.years,item.professional_year))error('professional_year','unknown_year');
    if(!subjects||!Object.hasOwn(subjects,item.subject))error('subject','unknown_subject_for_year');
    if(!subjects[item.subject].topics.includes(item.topic))error('topic','unknown_topic_for_subject');
    if(item.question.length<5)error('question','stem_too_short');
    const options=Object.fromEntries(['A','B','C','D'].map(letter=>[letter,item['option_'+letter.toLowerCase()]]));
    if(new Set(Object.values(options).map(v=>v.toLowerCase())).size!==4)error('options','options_must_be_distinct');
    if(!['A','B','C','D'].includes(item.correct_option))error('correct_option','must_be_A_B_C_D');
    if(!['','easy','medium','hard'].includes(item.difficulty??''))error('difficulty','unknown_difficulty');
    if(!['draft','active'].includes(item.status||'draft'))error('status','invalid_status');
    rows.push({questionId:item.question_id,professionalYear:Number(item.professional_year),subject:item.subject,topic:item.topic,stem:item.question,options,correctOption:item.correct_option,explanation:item.explanation??'',difficulty:item.difficulty??'',sourceRequestedStatus:item.status||'draft',status:'draft',version:1});
  }
  if(!rows.length)fail('invalid_csv',{line:2,field:'file',reason:'no_questions'});
  if(Buffer.byteLength(JSON.stringify(rows),'utf8')>700000)fail('invalid_csv',{line:1,field:'file',reason:'normalized_batch_too_large'});
  return rows;
}

function requestKeys(value,allowed) {if(!plain(value)||Object.keys(value).some(k=>!allowed.includes(k)))fail('invalid_request');}
export class QuizImportService {
  constructor(db,{adminUids=[],now=()=>Date.now()}={}){
    this.db=db;this.adminUids=new Set(adminUids);this.now=now;
    this.control=db.doc('quiz_control/import');this.taxonomy=db.doc('quiz_control/taxonomy');
  }
  authorize(auth){if(!auth?.uid)fail('unauthenticated');if(!this.adminUids.has(auth.uid))fail('permission_denied');}
  config(control,taxonomy){
    if(control?.enabled!==true)fail('feature_disabled');
    const digest=validateTaxonomy(taxonomy);
    if(control.taxonomyVersion!==taxonomy.version)fail('taxonomy_unavailable');return digest;
  }
  async preview(auth,data){
    this.authorize(auth);requestKeys(data,['csv']);
    const [control,taxonomy]=await this.db.getAll(this.control,this.taxonomy);
    const taxonomyHash=this.config(control.data(),taxonomy.data());
    const rows=validateCsv(data.csv,taxonomy.data());
    const batchId=randomUUID(),checksum=hash(data.csv),now=this.now(),expiresAt=now+15*60*1000;
    const record={actorUid:auth.uid,rows,checksum,taxonomyHash,taxonomyVersion:taxonomy.data().version,createdAt:now,expiresAt,state:'preview'};
    // Preview storage is private. No question record exists until explicit confirmation.
    await this.db.doc('quiz_import_batches/'+batchId).create(record);
    return {batchId,checksum,rowCount:rows.length,expiresAt:new Date(expiresAt).toISOString(),published:false,state:'preview'};
  }
  async commit(auth,data){
    this.authorize(auth);requestKeys(data,['batchId','checksum','idempotencyKey']);
    if(typeof data.batchId!=='string'||! /^[a-f0-9-]{36}$/.test(data.batchId)||typeof data.checksum!=='string'||! /^[a-f0-9]{64}$/.test(data.checksum)||typeof data.idempotencyKey!=='string'||! /^[A-Za-z0-9_-]{16,100}$/.test(data.idempotencyKey))fail('invalid_request');
    const batch=this.db.doc('quiz_import_batches/'+data.batchId);
    return this.db.runTransaction(async tx=>{
      const [control,taxonomy,snapshot]=await tx.getAll(this.control,this.taxonomy,batch);
      const taxonomyHash=this.config(control.data(),taxonomy.data());
      const record=snapshot.data();if(!record||record.actorUid!==auth.uid)fail('batch_unavailable');
      if(record.checksum!==data.checksum)fail('confirmation_mismatch');
      if(record.state==='committed'){
        if(record.idempotencyKey!==data.idempotencyKey)fail('already_committed');
        // Always reconstruct the public allowlist; never serialize a stored map.
        const count=record.rows.length;
        return {batchId:data.batchId,rowCount:count,imported:count,published:false,state:'committed'};
      }
      if(record.state!=='preview'||record.expiresAt<=this.now())fail('batch_expired');
      if(record.taxonomyHash!==taxonomyHash)fail('taxonomy_changed');
      if(!Array.isArray(record.rows)||!record.rows.length||record.rows.length>200)fail('batch_unavailable');
      const targets=record.rows.map(row=>this.db.doc('quiz_question_revisions/'+row.questionId+'__v1'));
      const existing=await tx.getAll(...targets);
      if(existing.some(s=>s.exists))fail('revision_conflict');
      const stamp=this.now();
      for(let i=0;i<targets.length;i++)tx.create(targets[i],{...record.rows[i],importBatch:data.batchId,createdBy:auth.uid,createdAt:stamp});
      const result={batchId:data.batchId,rowCount:targets.length,imported:targets.length,published:false,state:'committed'};
      tx.update(batch,{state:'committed',idempotencyKey:data.idempotencyKey,committedAt:stamp,result});
      return result;
    });
  }
}
