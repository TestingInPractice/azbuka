const fs = require('fs');
const { chromium } = require('/Users/halapinvv/qwen-gate/node_modules/playwright');

(async () => {
  const dataUrl = fs.readFileSync('/tmp/azbuka-m4a/harness/url.txt', 'utf8').trim();
  const browser = await chromium.launch({ channel: 'chrome', args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto('file:///tmp/azbuka-m4a/harness/harness.html');
  const result = await page.evaluate((url) => window.runProbe(url), dataUrl);
  console.log(JSON.stringify({ result, errors }, null, 1));
  await browser.close();
})().catch((e) => { console.error('PROBE_CRASH', e); process.exit(1); });
