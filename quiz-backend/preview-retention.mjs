// Expired, uncommitted CSV previews cannot be confirmed. Remove their question
// payload but retain a small private audit tombstone. Draft revisions and
// committed batches are never changed by this task.
export async function expireImportPreviews(db, {now = Date.now(), limit = 100} = {}) {
  if (!Number.isSafeInteger(now) || now < 0 || !Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
    throw new Error('Invalid retention bounds');
  }
  const candidates = await db.collection('quiz_import_batches')
    .where('state','==','preview').where('expiresAt','<=',now)
    .orderBy('expiresAt').limit(limit).get();
  let expired = 0;
  for (const candidate of candidates.docs) {
    const changed = await db.runTransaction(async tx => {
      const snapshot = await tx.get(candidate.ref), record = snapshot.data();
      if (!record || record.state !== 'preview' || !Number.isFinite(record.expiresAt) || record.expiresAt > now) return false;
      tx.set(candidate.ref, {state:'expired', actorUid:record.actorUid,
        checksum:record.checksum, taxonomyVersion:record.taxonomyVersion,
        createdAt:record.createdAt, expiresAt:record.expiresAt, expiredAt:now,
        rowCount:Array.isArray(record.rows) ? record.rows.length : 0});
      return true;
    });
    if (changed) expired++;
  }
  return {scanned:candidates.size,expired};
}
