const {chromium}=require('playwright');
const fs=require('node:fs');
(async()=>{
const out='hyzen_flutter/qa/1.5.11';fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || (fs.existsSync('/usr/bin/chromium')?'/usr/bin/chromium':'/usr/bin/google-chrome'),headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
const evidence={captures:[],checks:[],errors:[]};
for(const s of [
 {name:'login',route:'/login',width:390},
 {name:'login-narrow',route:'/login',width:320,scale:2},
 {name:'ranking',route:'/campus-rank',width:390},
 {name:'ranking-setup',route:'/campus-rank',width:320,scenario:'rank-setup',scale:1.3},
 {name:'study',route:'/study',width:390},
 {name:'home-content',route:'/home',width:390,height:1700},
 {name:'welcome-notice',route:'/home',width:390,scenario:'notice'},
 {name:'lectures',route:'/lectures',width:390},
]){
 const page=await browser.newPage({viewport:{width:s.width,height:s.height||900},deviceScaleFactor:1,reducedMotion:'reduce'});
 page.on('pageerror',e=>evidence.errors.push(String(e)));
 page.on('console',m=>{if(/overflowed by|Unhandled Exception/.test(m.text()))evidence.errors.push(m.text());});
 await page.goto(`http://127.0.0.1:8092/pharm-d-with-hyzen/app/?textScale=${s.scale||1}&reduceMotion=true&scenario=${s.scenario||'populated'}#${s.route}`);
 await page.waitForSelector('flutter-view',{timeout:90000});await page.waitForTimeout(2200);
 const enable=page.getByRole('button',{name:'Enable accessibility'});if(await enable.count())await enable.evaluate(b=>b.click());
 if(s.route==='/login'){
   await page.getByRole('button',{name:'Already a user? Log in',exact:true}).last().waitFor({timeout:20000});
   await page.screenshot({path:`${out}/${s.name}-choice.png`});
   await page.getByRole('button',{name:'Already a user? Log in',exact:true}).last().click();
   await page.getByRole('textbox').first().waitFor();await page.waitForTimeout(300);
 }
 await page.setViewportSize({width:s.width+1,height:s.height||900});
 await page.waitForTimeout(150);
 await page.setViewportSize({width:s.width,height:s.height||900});
 await page.screenshot();
 await page.waitForTimeout(300);
 await page.screenshot({path:`${out}/${s.name}.png`});
 fs.writeFileSync(`${out}/${s.name}.yml`,await page.locator('body').ariaSnapshot());
 evidence.captures.push(s);
 if(s.name==='ranking-setup'){
  await page.getByRole('textbox').fill('Haris');
  await page.getByText('Keep it private',{exact:true}).click();
  await page.getByRole('button',{name:'Confirm choices',exact:true}).click();
  await page.waitForTimeout(500);
  fs.writeFileSync(`${out}/ranking-after-save.yml`,await page.locator('body').ariaSnapshot());
  await page.screenshot({path:`${out}/ranking-after-save.png`});
  await page.getByRole('group',{name:/You’re studying privately/}).waitFor();
  await page.screenshot({path:`${out}/ranking-private-saved.png`});evidence.checks.push('first-visit explicit privacy choice saved');
 }
 if(s.name==='lectures'){
  await page.getByRole('button',{name:/^Lecture player demonstration/}).click();
  await page.waitForSelector('iframe[title="Lecture video"]',{timeout:20000});
  const src=await page.locator('iframe[title="Lecture video"]').getAttribute('src');
  if(!src.startsWith('https://www.youtube-nocookie.com/embed/M7lc1UVf-VE'))throw Error('Wrong embed');
  if(browser.contexts().reduce((n,c)=>n+c.pages().length,0)!==1)throw Error('External page opened');
  evidence.checks.push({embeddedLecture:true,src});await page.screenshot({path:`${out}/lecture-player.png`});
 }
 await page.close();
}
await browser.close();fs.writeFileSync(`${out}/browser-evidence.json`,JSON.stringify(evidence,null,2));console.log(JSON.stringify(evidence));if(evidence.errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1);});
