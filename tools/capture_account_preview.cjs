// Captures the actual Flutter source, using fixture-only auth/content adapters.
const {chromium} = require('playwright');
const fs = require('node:fs');
(async () => {
  const output = 'hyzen_flutter/qa/account-redesign';
  fs.mkdirSync(output, {recursive: true});
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  const errors = [];
  const evidence = {revision: process.env.GITHUB_SHA, captures: [], navigation: []};
  const destinations = ['Home', 'Study', 'Office Workspace', 'Shop', 'Downloads'];
  for (const theme of ['light', 'dark']) {
    for (const [name, path, title, height] of [
      ['account', '/profile', 'Account', 1100],
      ['account-info', '/profile/info', 'Account info', 1400],
      ['settings', '/settings', 'Settings', 1600],
      ['office', '/pdf-studio', 'Office Workspace', 844],
      ['downloads', '/downloads', 'Downloads', 844],
      ['study', '/study', 'Study', 844],
      ['notes', '/study/notes', 'Notes', 844],
      ['office-large-text', '/pdf-studio', 'Office Workspace', 844],
      ['notes-large-text', '/study/notes', 'Notes', 844],
      ['office-narrow', '/pdf-studio', 'Office Workspace', 800],
    ]) {
      const width = name.endsWith('narrow') || name.endsWith('large-text') ? 320 : 390;
      const page = await browser.newPage({viewport: {width, height}, deviceScaleFactor: 2,
        reducedMotion: name.endsWith('narrow') ? 'reduce' : 'no-preference'});
      page.on('pageerror', error => errors.push(String(error)));
      page.on('console', message => {
        if (/overflowed by|Unhandled Exception/.test(message.text())) errors.push(message.text());
      });
      await page.goto(`http://127.0.0.1:8080/pharm-d-with-hyzen/ui-review/?theme=${theme}&textScale=${name.endsWith('large-text') ? 2 : 1}#${path}`);
      await page.waitForSelector('flutter-view', {timeout: 90000});
      await page.waitForTimeout(3500);
      const enable = page.getByRole('button', {name: 'Enable accessibility'});
      if (await enable.count()) await enable.evaluate(button => button.click());
      try {
        // Flutter emits some headings as text and others as aria-labels.
        await page.getByText(title, {exact: true})
          .or(page.getByLabel(title, {exact: true}))
          .filter({visible: true}).first().waitFor({timeout: 30000});
      } catch (error) {
        await page.screenshot({path: `${output}/failure-${theme}-${name}.png`});
        fs.writeFileSync(`${output}/failure-${theme}-${name}.html`, await page.content());
        console.error(JSON.stringify({theme, name, url: page.url(), labels: await page.locator('[aria-label]').evaluateAll(nodes => nodes.map(n => n.getAttribute('aria-label')))}));
        throw error;
      }
      if (name.startsWith('office') || name === 'downloads') {
        // Warm CanvasKit's icon glyph atlas through real navigation. A cold
        // GPU readback can omit freshly rasterized foregrounds in Chromium.
        for (const [label, route] of [['Home','/home'],['Study','/study'],['Shop','/shop'],['Downloads','/downloads']]) {
          await page.getByRole('button',{name:label,exact:true}).click();
          await page.waitForURL(url => url.hash === '#'+route);
          await page.waitForTimeout(150);
        }
        const activeLabel = name.startsWith('office') ? 'Office Workspace' : 'Downloads';
        await page.getByRole('button', {name: activeLabel, exact: true}).click();
        await page.waitForURL(url => url.hash === `#${path}`);
        await page.waitForTimeout(300);
      }
      if (name.startsWith('office') || name === 'downloads') {
        // Verify all five actual accessible hit areas and their visual order.
        const bounds = [];
        const active = name.startsWith('office') ? 'Office Workspace' : 'Downloads';
        for (const label of destinations) {
          const item = page.getByRole('button', {name: label, exact: true}).filter({visible: true});
          if (await item.count() !== 1) throw Error(`${theme}/${name}: expected one ${label}`);
          if (await item.getAttribute('aria-current') !== String(label === active)) {
            throw Error(`${theme}/${name}: incorrect selected state for ${label}`);
          }
          const box = await item.boundingBox();
          if (!box || box.width < 48 || box.height < 48) throw Error(`Small target: ${label}`);
          bounds.push(box.x);
        }
        if (bounds.some((x, i) => i > 0 && x <= bounds[i - 1])) throw Error('Incorrect tab order');
      }
      // Semantics can be ready before CanvasKit submits its next painted frame.
      // Allow the restrained selection animation and font glyphs to settle.
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      await page.waitForTimeout(700);
      await page.mouse.move(0, 0);
      const filename = `${theme}-${name}.png`;
      await page.screenshot({path: `${output}/${filename}`});
      evidence.captures.push({filename, theme, path, width, height});
      if (name === 'office') {
        for (const [label, route] of [['Study', '/study'], ['Downloads', '/downloads'],
          ['Office Workspace', '/pdf-studio'], ['Shop', '/shop'], ['Home', '/home']]) {
          await page.getByRole('button', {name: label, exact: true}).filter({visible: true}).click();
          await page.waitForURL(url => url.hash === `#${route}`);
          evidence.navigation.push({theme, label, route, passed: true});
        }
      }
      await page.close();
    }
  }
  for (const theme of ['light', 'dark']) {
    for (const scenario of [
      {name: 'home', width: 390, height: 844},
      {name: 'home-overview', width: 390, height: 1500},
      {name: 'home-narrow', width: 320, height: 1000},
      {name: 'home-large-text', width: 320, height: 1200, scale: 2},
      {name: 'home-empty', width: 390, height: 844, empty: true},
    ]) {
      const page = await browser.newPage({viewport: {width: scenario.width, height: scenario.height}, deviceScaleFactor: 2, reducedMotion: 'reduce'});
      page.on('pageerror', error => errors.push(String(error)));
      page.on('console', message => { if (/overflowed by|Unhandled Exception/.test(message.text())) errors.push(message.text()); });
      await page.goto(`http://127.0.0.1:8080/pharm-d-with-hyzen/ui-review/?theme=${theme}&textScale=${scenario.scale || 1}&reduceMotion=true&scenario=${scenario.empty ? 'empty' : 'populated'}#/home`);
      await page.waitForSelector('flutter-view', {timeout: 90000});
      await page.waitForTimeout(2500);
      const enable = page.getByRole('button', {name: 'Enable accessibility'});
      if (await enable.count()) await enable.evaluate(button => button.click());
      await page.getByRole('button', {name: 'Continue to Study', exact: true}).waitFor({timeout: 30000});
      // Exercise real retained navigation before canvas readback.
      await page.getByRole('button', {name: 'Study', exact: true}).click();
      await page.waitForURL(url => url.hash === '#/study');
      await page.getByRole('button', {name: 'Home', exact: true}).click();
      await page.waitForURL(url => url.hash === '#/home');
      await page.mouse.move(0, 0);
      await page.waitForTimeout(1000);
      const filename = `${theme}-${scenario.name}.png`;
      await page.screenshot({path: `${output}/${filename}`});
      if (scenario.name === 'home-overview') {
        const snapshot = await page.locator('body').ariaSnapshot();
        fs.writeFileSync(`${output}/${theme}-home-accessibility.yml`, snapshot);
        // The real browser build has no seeded download records. Validate the
        // live Downloads hit area and preserve any runtime status suffix when
        // one is present, rather than requiring fabricated sample counts.
        const statusCard = page.getByRole('button', {name: /^Downloads(?:, .*)?$/});
        await statusCard.first().waitFor({timeout: 15000});
        evidence.homeStatus = {
          label: await statusCard.first().getAttribute('aria-label'),
          accessible: true,
        };
        if (await page.getByText('More from Hyzen', {exact: true}).count()) throw Error('Removed Home group remains');
      }
      evidence.captures.push({filename, theme, path: '/home', ...scenario, sampleData: true});
      await page.close();
    }
  }
  evidence.auth = [];
  for (const theme of ['light', 'dark']) {
    for (const scenario of [
      {name:'welcome',path:'/welcome',width:390,height:1000},
      {name:'login',path:'/login',width:390,height:900},
      {name:'login-narrow',path:'/login',width:320,height:900},
      {name:'login-large-text',path:'/login',width:320,height:1200,scale:2},
    ]) {
      const page = await browser.newPage({viewport:{width:scenario.width,height:scenario.height},deviceScaleFactor:2,reducedMotion:'reduce'});
      page.on('pageerror',error=>errors.push(String(error)));
      page.on('console',m=>{if(/overflowed by|Unhandled Exception/.test(m.text()))errors.push(m.text());});
      await page.goto(`http://127.0.0.1:8080/pharm-d-with-hyzen/ui-review/?theme=${theme}&textScale=${scenario.scale||1}&reduceMotion=true#${scenario.path}`);
      await page.waitForSelector('flutter-view',{timeout:90000});
      await page.waitForTimeout(2200);
      const enable=page.getByRole('button',{name:'Enable accessibility'});
      if(await enable.count())await enable.evaluate(b=>b.click());
      if(scenario.path==='/login') {
        await page.getByText('Welcome to PHARM D WITH HYZEN',{exact:true}).waitFor({timeout:30000});
        if(await page.getByText('Welcome back',{exact:true}).count())throw Error('Outdated login greeting');
        if(await page.getByRole('textbox').count())throw Error('Login form shown before account choice');
        await page.getByRole('button',{name:'Already a user? Log in',exact:true}).waitFor();
        await page.screenshot({path:`${output}/${theme}-${scenario.name}-choice.png`});
        await page.getByRole('button',{name:'Already a user? Log in',exact:true}).click();
        await page.getByRole('textbox').first().waitFor();
      } else {
        await page.getByRole('button',{name:'Get Started →',exact:true}).waitFor({timeout:30000});
      }
      await page.waitForTimeout(700);
      const filename=`${theme}-${scenario.name}.png`;
      await page.screenshot({path:`${output}/${filename}`});
      evidence.captures.push({filename,theme,...scenario,sampleData:true});
      if(scenario.name==='login') {
        await page.getByRole('button',{name:'Show password',exact:true}).click();
        await page.getByRole('button',{name:'Hide password',exact:true}).waitFor();
        await page.getByRole('button',{name:'Forgot password?',exact:true}).click();
        await page.getByText('Forgot your password?',{exact:true}).waitFor({timeout:30000});
        evidence.auth.push({theme,passwordVisibility:true,passwordRecovery:true});
      }
      await page.close();
    }
  }
  fs.writeFileSync(`${output}/browser-evidence.json`, JSON.stringify(evidence, null, 2));
  await browser.close();
  if (errors.length) throw new Error(errors.join('\n'));
})();
