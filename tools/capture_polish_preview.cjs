const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
let browser;
(async()=>{
 const output=path.resolve('hyzen_flutter/qa/polish-browser');fs.mkdirSync(output,{recursive:true});
 browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,recordVideo:{dir:output,size:{width:390,height:844}}});
 const page=await context.newPage();const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(/overflowed by|Unhandled Exception/.test(m.text()))errors.push(m.text());});
 await page.goto('http://127.0.0.1:8080/?reduceMotion=false#/home');
 await page.waitForSelector('flutter-view');await page.waitForTimeout(3000);
 await page.screenshot({path:path.join(output,'home.png')});
 // Capture normal canvas/keyboard interaction at a fixed review viewport.
 // The separate native widget tests assert routes, scopes and semantics.
 await page.mouse.click(145,414);await page.waitForTimeout(300);
 const input=page.locator('input.flt-text-editing');await input.fill('Pharmacology');await page.waitForTimeout(600);
 if(await input.inputValue()!=='Pharmacology')throw Error('Query was not retained');
 await page.mouse.click(110,462);await page.waitForTimeout(300);
 await page.screenshot({path:path.join(output,'home-search.png')});
 await page.mouse.click(338,414);await page.mouse.click(160,55);await page.mouse.wheel(0,245);await page.waitForTimeout(400);
 await page.screenshot({path:path.join(output,'home-stats.png')});
 await page.mouse.click(351,54);await page.waitForTimeout(500);
 await page.screenshot({path:path.join(output,'notifications.png')});
 await page.goto('http://127.0.0.1:8080/?reduceMotion=false#/home');await page.waitForSelector('flutter-view');await page.waitForTimeout(3800);
 await context.close();const video=await page.video().path();fs.copyFileSync(video,path.join(output,'motion-preview.webm'));
 await browser.close();browser=null;
 fs.writeFileSync(path.join(output,'evidence.json'),JSON.stringify({errors,queryRetained:true,description:'Actual Flutter web fixture using normal canvas input, no production backend writes; browser/software rendering, not native FPS evidence.'},null,2));
 console.log(JSON.stringify({output,errors}));if(errors.length)process.exitCode=1;
})().catch(async e=>{console.error(e);if(browser)await browser.close();process.exitCode=1;});
