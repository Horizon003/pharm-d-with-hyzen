const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const base=process.env.HYZEN_REVIEW_URL||'http://127.0.0.1:8080';
const output=process.env.HYZEN_REVIEW_OUTPUT||'hyzen_flutter/build/reference-browser-qa';
let browser;
(async()=>{
  fs.mkdirSync(output,{recursive:true});
  browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
  const evidence={appVersion:'1.5.6+15',captures:[],navigation:[],errors:[]};
  async function open(route,{width=390,height=844,scale=1}={}){
    const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1,colorScheme:'dark',reducedMotion:'reduce'});
    page.on('pageerror',error=>evidence.errors.push(String(error)));
    page.on('console',message=>{if(/overflowed by|Unhandled Exception|Another exception was thrown/.test(message.text()))evidence.errors.push(message.text());});
    await page.goto(`${base}/?theme=dark&textScale=${scale}&reduceMotion=true#${route}`);
    await page.waitForSelector('flutter-view',{timeout:90000});
    const enable=page.getByRole('button',{name:'Enable accessibility'});
    await enable.waitFor({state:'attached',timeout:30000});
    await enable.evaluate(node=>node.click());
    if(route==='/home') await page.getByRole('button',{name:'Home',exact:true}).waitFor({timeout:30000});
    await page.waitForTimeout(1800);
    return page;
  }
  const home=await open('/home');
  for(const [label,route] of [['Study','/study'],['Office Workspace','/pdf-studio'],['Shop','/shop'],['Downloads','/downloads'],['Home','/home']]){
    const button=home.getByRole('button',{name:label,exact:true});
    await button.click(); await home.waitForURL(url=>url.hash==='#'+route);
    await home.waitForTimeout(150);
    evidence.navigation.push({label,route,passed:true});
  }
  await home.screenshot({path:path.join(output,'home-navigation.png')});await home.close();
  for(const [name,route] of [['home','/home'],['study','/study'],['office','/pdf-studio'],['downloads','/downloads'],['profile','/profile'],['settings','/settings'],['goals','/study-goals'],['admin','/admin'],['welcome','/welcome']]){
    const page=await open(route);
    const text=await page.locator('flt-semantics').allTextContents();
    if(text.some(t=>/This page could not be found|Firebase has not been correctly initialized/.test(t)))throw Error(`Broken route: ${route}`);
    await page.screenshot({path:path.join(output,name+'.png')});
    evidence.captures.push({name,route,width:390,height:844,scale:1,osTheme:'dark',reducedMotion:true});await page.close();
  }
  for(const scenario of [{width:320,height:800,scale:2},{width:768,height:1024,scale:1},{width:844,height:390,scale:1}]){
    const page=await open('/home',scenario);
    for(let i=0;i<4;i++){await page.mouse.wheel(0,500);await page.waitForTimeout(100);}
    await page.screenshot({path:path.join(output,`home-${scenario.width}-${scenario.scale}.png`)});
    evidence.captures.push({name:'home-responsive',route:'/home',...scenario,osTheme:'dark',reducedMotion:true});await page.close();
  }
  await browser.close();fs.writeFileSync(path.join(output,'evidence.json'),JSON.stringify(evidence,null,2));
  if(evidence.errors.length)throw Error(JSON.stringify(evidence.errors));
  console.log(JSON.stringify({captures:evidence.captures.length,navigation:evidence.navigation.length,errors:evidence.errors.length}));
})().catch(async error=>{console.error(error);if(browser)await browser.close();process.exitCode=1});
