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
// server-only control/taxonomy documents deny imports. Gameplay is gated separately below.
export const previewQuizCsv=onCall(options,importHandler(service,'preview'));
export const commitQuizCsv=onCall(options,importHandler(service,'commit'));

// Undeployed candidate. Deploy its required composite index with the functions.
// Hourly bounded cleanup retains audit metadata and never publishes questions.
export const expireQuizCsvPreviews=onSchedule({schedule:'every 60 minutes',
  timeZone:'Etc/UTC',maxInstances:1,memory:'256MiB',timeoutSeconds:120},
  async()=>{await expireImportPreviews(getFirestore());});


import {QuizPlayService} from './play-service.mjs';
import {playHandler} from './play-handlers.mjs';
const play = new QuizPlayService(getFirestore());
// Default off: explicit approved server policy, memberships and pools required.
export const startQuiz = onCall(options, playHandler(play, 'start'));
export const getQuiz = onCall(options, playHandler(play, 'get'));
export const saveQuiz = onCall(options, playHandler(play, 'save'));
export const submitQuiz = onCall(options, playHandler(play, 'submit'));
export const createQuizDuel = onCall(options, playHandler(play, 'createDuel'));
export const joinQuizDuel = onCall(options, playHandler(play, 'joinDuel'));
export const getQuizDuel = onCall(options, playHandler(play, 'duelStatus'));
export const cancelQuizDuel = onCall(options, playHandler(play, 'cancelDuel'));

export const quizLobby = onCall(options, playHandler(play, 'lobby'));

import {QuizAdminService} from './admin-service.mjs';
const quizAdmin = new QuizAdminService(getFirestore(), {
  adminUids:(process.env.HYZEN_QUIZ_ADMIN_UIDS??'').split(',').map(v=>v.trim()).filter(Boolean),
});
export const listQuizQuestions = onCall(options, importHandler(quizAdmin, 'listQuestions'));
export const reviewQuizQuestion = onCall(options, importHandler(quizAdmin, 'reviewQuestion'));
export const setQuizPublication = onCall(options, importHandler(quizAdmin, 'setPublication'));
