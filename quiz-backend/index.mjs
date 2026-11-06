import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {onCall} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {QuizImportService} from './import-service.mjs';
import {importHandler} from './callable-handlers.mjs';
import {expireImportPreviews} from './preview-retention.mjs';

initializeApp();
const service=new QuizImportService(getFirestore(),{
  adminUids:(process.env.HYZEN_QUIZ_ADMIN_UIDS??'').split(',').map(v=>v.trim()).filter(Boolean),
});
const options={enforceAppCheck:true,maxInstances:1,memory:'256MiB',timeoutSeconds:60};
// No automatic deployment/configuration is included. Empty admin list and missing
// server-only control/taxonomy documents deny all work. No student endpoint exists.
export const previewQuizCsv=onCall(options,importHandler(service,'preview'));
export const commitQuizCsv=onCall(options,importHandler(service,'commit'));

// Undeployed candidate. Deploy its required composite index with the functions.
// Hourly bounded cleanup retains audit metadata and never publishes questions.
export const expireQuizCsvPreviews=onSchedule({schedule:'every 60 minutes',
  timeZone:'Etc/UTC',maxInstances:1,memory:'256MiB',timeoutSeconds:120},
  async()=>{await expireImportPreviews(getFirestore());});
