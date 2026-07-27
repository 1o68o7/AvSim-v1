/**
 * Capture avant/après tokens — chrome UI (badges, boutons, panneau).
 */
import { chromium } from "playwright";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = "/opt/cursor/artifacts/render-da";

async function screenshot(label, htmlPath) {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 640 } });
  await page.goto(`file://${htmlPath}`);
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${outDir}/${label}.png`, fullPage: true });
  await browser.close();
}

// CSS « avant » : theme main sans tokens (Fraunces / Source Sans 3)
const beforeCss = execSync("git show main:web/src/theme.css", { cwd: root }).toString();
const beforeHtml = readFileSync(resolve(root, "design-snapshot.html"), "utf8")
  .replace(
    '<link rel="stylesheet" href="../src/tokens.css" />',
    "",
  )
  .replace(
    '<link rel="stylesheet" href="../src/theme.css" />',
    `<style>${beforeCss}</style>`,
  );
writeFileSync(`${outDir}/snapshot-before.html`, beforeHtml);

const afterHtml = readFileSync(resolve(root, "design-snapshot.html"), "utf8");
writeFileSync(`${outDir}/snapshot-after.html`, afterHtml.replace(
  'href="../src/',
  `href="${root}/src/`,
));

await screenshot("render-da-before", `${outDir}/snapshot-before.html`);
await screenshot("render-da-after", `${outDir}/snapshot-after.html`);
console.log("Captures:", outDir);
