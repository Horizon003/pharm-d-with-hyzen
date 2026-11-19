const { chromium } = require('playwright');
const path = require('path');
const http = require('http');
const fs = require('fs');
(async()=>{
const root=path.resolve(__dirname,'../../..');
const server=http.createServer((req,res)=>{const p=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!p.startsWith(root+path.sep)){res.writeHead(403);return res.end();}fs.readFile(p,(err,data)=>{if(err){res.writeHead(404);return res.end();}const ext=path.extname(p);res.setHeader('Content-Type',ext==='.html'?'text/html':ext==='.png'?'image/png':ext==='.ttf'?'font/ttf':'application/octet-stream');res.end(data);});});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser = await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page = await browser.newPage({viewport:{width:1148,height:1000},deviceScaleFactor:2});
await page.goto(`http://127.0.0.1:${server.address().port}/docs/design-review/font-choice/preview.html`);
await page.evaluate(()=>document.fonts.ready);
const fonts = await page.evaluate(()=>Array.from(document.fonts).map(f=>({family:f.family,status:f.status})));
if(fonts.some(f=>f.status!=='loaded'))throw Error(JSON.stringify(fonts));
await page.screenshot({path:path.join(__dirname,'font-comparison.png'),fullPage:true});
console.log(JSON.stringify({fonts,screenshot:'font-comparison.png'}));
await browser.close();
server.close();
})();
