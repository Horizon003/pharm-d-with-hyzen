import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
export function fixture() {
  const sql=new DatabaseSync(':memory:');
  sql.exec(readFileSync(new URL('../schema.sql',import.meta.url),'utf8'));
  function prepare(query,args=[]) {
    return {bind(...values){return prepare(query,values);},
      execute(){return query.startsWith('SELECT')?{results:sql.prepare(query).all(...args)}:{meta:{changes:Number(sql.prepare(query).run(...args).changes)}};},
      async run(){return this.execute();},
      async first(){return sql.prepare(query).get(...args)||null;},
      async all(){return {results:sql.prepare(query).all(...args)};}};
  }
  return {sql,db:{prepare,async batch(statements){sql.exec('BEGIN');try{const results=statements.map(s=>s.execute());sql.exec('COMMIT');return results;}catch(e){sql.exec('ROLLBACK');throw e;}}}};
}
