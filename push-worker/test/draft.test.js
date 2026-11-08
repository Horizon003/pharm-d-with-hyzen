import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {materializeRecipients} from '../src/draft.js';
test('conflicting concurrent content cannot expand an immutable draft audience',async()=>{
 const sql=new DatabaseSync(':memory:');
 sql.exec('CREATE TABLE recipients(message_id TEXT,uid TEXT,PRIMARY KEY(message_id,uid))');
 const db={prepare(query){return {bind(...args){return {run(){sql.prepare(query).run(...args);}};}};},async batch(statements){for(const statement of statements)statement.run();}};
 const winner={id:'same-message',fingerprint:'first',audience:'["college-a-student"]'};
 const results=await Promise.allSettled([materializeRecipients(db,winner,'first'),materializeRecipients(db,winner,'conflicting')]);
 assert.equal(results[0].status,'fulfilled');assert.equal(results[1].status,'rejected');
 await materializeRecipients(db,winner,'first');
 assert.deepEqual(sql.prepare('SELECT uid FROM recipients').all().map(row=>row.uid),['college-a-student']);
 sql.close();
});
