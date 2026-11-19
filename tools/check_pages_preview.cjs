// Smoke-test the packaged GitHub project Pages paths and real Flutter navigation.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.HYZEN_CHROMIUM || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--enable-unsafe-swiftshader']});
  try {
    const page = await browser.newPage({viewport: {width: 1000, height: 1000}});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (/overflowed by|Unhandled Exception/.test(message.text())) errors.push(message.text()); });
    const root = process.env.HYZEN_PREVIEW_URL || 'http://127.0.0.1:8080/pharm-d-with-hyzen/';
    const response = await page.goto(root);
    if (response.status() !== 200) throw Error('Preview shell did not load');
    await page.selectOption('#width', '390');
    const screens = ['/home', '/study', '/pdf-studio', '/settings', '/notifications', '/study-goals'];
    const output = path.resolve(process.env.HYZEN_QA_OUTPUT || 'hyzen_flutter/qa/pages-preview');
    fs.mkdirSync(output, {recursive: true});
    for (const route of screens) {
      await page.selectOption('#screen', route);
      await page.waitForFunction(route => document.querySelector('#app').contentWindow.location.hash === '#' + route, route);
      await page.frameLocator('#app').locator('flutter-view').waitFor();
      await page.waitForTimeout(2200);
      const app = page.frames().find(frame => frame.url().includes('/app/'));
      await app.waitForSelector('flutter-view');
      await page.waitForTimeout(1800);
      if (!app.url().endsWith('#' + route)) throw Error('Incorrect route: ' + app.url());
      const base = await app.locator('base').getAttribute('href');
      if (base !== '/pharm-d-with-hyzen/app/') throw Error('Incorrect project Pages base: ' + base);
      await page.locator('#app').screenshot({path: path.join(output, route.slice(1) + '.png')});
    }
    await page.selectOption('#scale', '2');
    await page.waitForTimeout(1000);
    await page.selectOption('#width', '320');
    if (await page.locator('#app').evaluate(node => node.getBoundingClientRect().width) !== 320) throw Error('Preview width control failed');
    const evidence = {screens, errors, baseHref: '/pharm-d-with-hyzen/app/', textScale: 2, width: 320, source: (await page.evaluate(async () => (await fetch('source-commit.txt', {cache: 'no-store'})).text())).trim(), published: root.startsWith('https://horizon003.github.io/')};
    fs.writeFileSync(path.join(output, 'evidence.json'), JSON.stringify(evidence, null, 2));
    console.log(JSON.stringify(evidence));
    if (errors.length) process.exitCode = 1;
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
