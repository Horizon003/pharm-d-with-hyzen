// Recipient rows always come from the winning immutable draft, including retry
// recovery. A competing request cannot expand that audience before validation.
export async function materializeRecipients(db, row, fingerprint) {
  if (row.fingerprint !== fingerprint) {
    const error = new Error('Conflicting message ID');
    error.status = 409;
    throw error;
  }
  const audience = JSON.parse(row.audience);
  for (let i = 0; i < audience.length; i += 200) {
    await db.batch(audience.slice(i, i + 200).map(uid => db.prepare(
      'INSERT OR IGNORE INTO recipients(message_id,uid) VALUES(?,?)'
    ).bind(row.id, uid)));
  }
}
