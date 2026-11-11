import { chromium } from 'playwright';
import { mkdirSync } from 'fs';
mkdirSync('stills', { recursive: true });
const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
await p.goto('file://' + process.cwd() + '/index.html'); await p.waitForTimeout(300);
const errs=[]; p.on('console', m => errs.push(m.text()));
for (const t of process.argv.slice(2)) { await p.evaluate(t => seek(t), +t); await p.screenshot({ path: `stills/t${t}.png` }); }
console.log(errs.join('\n')); await b.close();
