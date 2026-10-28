import {HttpsError} from 'firebase-functions/v2/https';
import {PlayError} from './play-service.mjs';
export function playHandler(service, method) {
  if (!['lobby','start','get','save','submit','createDuel','joinDuel','duelStatus','cancelDuel'].includes(method)) throw new Error('Unknown quiz operation');
  return async request => {
    if (!request?.auth?.uid) throw new HttpsError('unauthenticated','Sign in to continue.');
    if (!request.app?.appId) throw new HttpsError('failed-precondition','App verification is required.');
    try { return await service[method](request.auth,request.data); }
    catch(error) {
      if (!(error instanceof PlayError)) throw new HttpsError('internal','Quiz request did not complete. Retry the same request.');
      const code=error.code==='unauthenticated'?'unauthenticated':
        ['invalid_request','invalid_answers'].includes(error.code)?'invalid-argument':
        ['attempt_unavailable','duel_unavailable'].includes(error.code)?'not-found':
        ['daily_limit','cooldown','invitation_limit'].includes(error.code)?'resource-exhausted':'failed-precondition';
      throw new HttpsError(code,error.code);
    }
  };
}
