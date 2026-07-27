/**
 * Smoke fondation shadcn — index.css + theme legacy.
 */
import { chromium } from "playwright";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = "/opt/cursor/artifacts/shadcn-foundation";
mkdirSync(outDir, { recursive: true });

const html = readFileSync(resolve(root, "design-snapshot.html"), "utf8").replace(
  /href="\.\.\/src\//g,
  `href="${root}/src/`,
);
writeFileSync(`${outDir}/snapshot.html`, html);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 900, height: 640 } });
await page.goto(`file://${outDir}/snapshot.html`);
await page.waitForTimeout(400);
await page.screenshot({ path: `${outDir}/shadcn-foundation.png`, fullPage: true });
await browser.close();
console.log("Capture:", `${outDir}/shadcn-foundation.png`);
