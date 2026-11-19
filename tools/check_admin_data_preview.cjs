// Real Flutter UI; isolated in-memory admin adapter, browser file APIs.
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const output=process.env.HYZEN_ADMIN_QA||'/tmp/hyzen-admin-qa';fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const errors=[],checks=[];
 try {
  const page=await browser.newPage({viewport:{width:390,height:1000},deviceScaleFactor:1,reducedMotion:'reduce'});
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(/overflowed by|Unhandled Exception/.test(m.text()))errors.push(m.text());});
  const base=process.env.HYZEN_APP_PREVIEW||'http://127.0.0.1:8092/pharm-d-with-hyzen/app/';
  async function ready(){
   await page.locator('flutter-view').waitFor({timeout:90000});await page.waitForTimeout(1000);
   const enable=page.getByRole('button',{name:'Enable accessibility'});
   if(await enable.count())await enable.evaluate(b=>b.click());
  }
  async function route(value){await page.evaluate(v=>{location.hash='#'+v},value);await page.waitForTimeout(700);}
  async function button(name){
   const b=page.getByRole('button',{name,exact:true}).last();
   for(let n=0;n<8;n++){
    if(await b.count() && await b.isVisible())return b;
    await page.mouse.wheel(0,450);await page.waitForTimeout(200);
   }
   throw Error('Button missing: '+name);
  }
  await page.goto(base+'?reduceMotion=true#/admin/import');await ready();
  for(const [label,ext] of [['CSV template','csv'],['JSON template','json'],['Excel template','xlsx']]){
   const target=await button(label);const [download]=await Promise.all([page.waitForEvent('download',{timeout:10000}),target.click()]);
   if(!download.suggestedFilename().endsWith('.'+ext))throw Error('Wrong template format');
   const destination=path.join(output,download.suggestedFilename());await download.saveAs(destination);
   if(ext==='xlsx' && fs.readFileSync(destination).subarray(0,2).toString()!=='PK')throw Error('Excel binary corrupted');
   checks.push('download '+ext);
  }
  const source='Type,Professional Year,Semester,Subject,Section,Topic,File Name,Link\nNotes,2nd Professional,Semester 1,Pharmacology,Notes,ANS,QA revision,https://example.org/qa.pdf\nNotes,2nd Professional,Semester 1,Pharmacology,Notes,ANS,Bad URL,http://example.org/bad.pdf';
  const chooseButton=await button('Choose import files');const [choose]=await Promise.all([page.waitForEvent('filechooser'),chooseButton.click()]);
  await choose.setFiles({name:'qa-mixed.csv',mimeType:'text/csv',buffer:Buffer.from(source)});
  const commit=await button('Import 1 new files');await page.waitForTimeout(400);
  await page.screenshot({path:path.join(output,'admin-import-preview-390.png')});
  await commit.click();await page.waitForTimeout(600);checks.push('mixed valid/invalid preview and import');
  await route('/admin/manage/data');
  const exportButton=await button('Export full backup');const [backup]=await Promise.all([page.waitForEvent('download'),exportButton.click()]);const backupPath=path.join(output,'backup.json');await backup.saveAs(backupPath);
  if(!fs.readFileSync(backupPath,'utf8').includes('QA revision'))throw Error('Imported file absent from backup');
  checks.push('backup contains imported content');
  await page.screenshot({path:path.join(output,'admin-data-manager-390.png')});
  await route('/admin/manage/history');await (await button('Undo')).click();await (await button('Undo import')).click();
  await page.waitForTimeout(800);
  fs.writeFileSync(path.join(output,'undo-text.txt'),(await page.locator('flt-semantics').allTextContents()).join('\n'));
  await page.screenshot({path:path.join(output,'after-undo.png')});
  await page.waitForFunction(()=>Array.from(document.querySelectorAll('flt-semantics')).some(n=>n.textContent.includes('Undone')));checks.push('batch undo');
  await page.screenshot({path:path.join(output,'admin-history-390.png')});
  await route('/admin/manage/data');const restoreButton=await button('Restore JSON backup');const [restore]=await Promise.all([page.waitForEvent('filechooser'),restoreButton.click()]);
  await restore.setFiles(backupPath);await (await button('Restore')).click();await page.waitForTimeout(500);checks.push('backup restore');
  for(const width of [320,768]){
   await page.setViewportSize({width,height:1000});await route('/admin/import');await page.waitForTimeout(400);
   await page.screenshot({path:path.join(output,'admin-import-'+width+'.png')});
   checks.push('layout '+width);
  }
  const revision=(await page.evaluate(async url=>(await fetch(url,{cache:'no-store'})).text(),new URL('../source-commit.txt',base).href)).trim();
  const result={checks,errors,source:revision,fixtureOnly:true,realFlutter:true};fs.writeFileSync(path.join(output,'evidence.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
  if(errors.length)process.exitCode=1;
 }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
