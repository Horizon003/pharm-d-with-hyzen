import {HttpsError} from 'firebase-functions/v2/https';
import {ImportError} from './import-service.mjs';

// Firebase verifies the tokens before constructing request.auth/request.app.
// These checks also fail closed if a future adapter bypasses the callable wrapper.
export function importHandler(service, method) {
  if (!['preview','commit','listQuestions','reviewQuestion','setPublication'].includes(method)) throw new Error('Unknown import operation');
  return async request => {
    if (!request?.auth?.uid) throw new HttpsError('unauthenticated','Sign in to continue.');
    if (!request.app?.appId) throw new HttpsError('failed-precondition','App verification is required.');
    try { return await service[method](request.auth, request.data); }
    catch (error) {
      if (!(error instanceof ImportError)) {
        throw new HttpsError('internal','Import did not complete. Retry the same confirmation.');
      }
      const code = error.code === 'unauthenticated' ? 'unauthenticated'
        : error.code === 'permission_denied' ? 'permission-denied'
        : ['invalid_request','invalid_csv'].includes(error.code) ? 'invalid-argument'
        : 'failed-precondition';
      // Validation diagnostics contain positions/codes only; never return an
      // arbitrary error.details map from the private service to a client.
      const details = {};
      if (error.code === 'invalid_csv') {
        if (Number.isSafeInteger(error.details?.line) && error.details.line > 0) details.line = error.details.line;
        for (const key of ['field','reason']) {
          const value = error.details?.[key];
          if (typeof value === 'string' && /^[A-Za-z0-9_]{1,80}$/.test(value)) details[key] = value;
        }
      }
      throw new HttpsError(code,error.code,details);
    }
  };
}

