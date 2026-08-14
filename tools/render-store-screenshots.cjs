const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');

async function main() {
  const root = path.resolve(__dirname, '..');
  const outputDir = path.join(root, 'assets', 'store-screenshots');
  const source = path.join(outputDir, 'showcase.html');
  fs.mkdirSync(outputDir, { recursive: true });

  const chromePath = process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ headless: true, executablePath: chromePath });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(source).href, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  for (let i = 1; i <= 3; i += 1) {
    const target = page.locator(`#screen-${i}`);
    await target.screenshot({ path: path.join(outputDir, `stockfloat-intro-${i}.png`) });
  }

  await browser.close();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
