import { chromium } from 'playwright';
import { mkdirSync } from 'fs';
mkdirSync('frames', { recursive: true });
const FPS = 100 / 3, SUB = 6;               // 33.3 fps output, 6 motion-blur subframes each
const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2 });
await p.goto('file://' + process.cwd() + '/index.html'); await p.waitForTimeout(400);
const T = await p.evaluate(() => T), N = Math.round(T * FPS) * SUB;
for (let i = 0; i < N; i++) {
  // subframes trail the output frame time so blur sits behind motion
  await p.evaluate(t => seek(t), (i + 1 - SUB) / (FPS * SUB));
  await p.screenshot({ path: `frames/${String(i).padStart(5, '0')}.png` });
}
await b.close(); console.log(N, 'subframes');
