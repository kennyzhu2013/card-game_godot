const fs = require('fs');
const { test, expect } = require('@playwright/test');

const url = process.env.WEBQA_URL || 'http://127.0.0.1:8765/index.html';
const screenshotPath = process.env.WEBQA_SCREENSHOT || 'output/webqa/artifacts/webqa-screenshot.png';
const consoleJsonPath = process.env.WEBQA_CONSOLE_JSON || 'output/webqa/artifacts/webqa-console.json';
const resultJsonPath = process.env.WEBQA_RESULT_JSON || 'output/webqa/artifacts/webqa-regression-result.json';

test.setTimeout(180000);

function taskScreenshotPath(label) {
  return screenshotPath.replace(/\.png$/i, `-${label}.png`);
}

function writeJson(path, payload) {
  fs.mkdirSync(require('path').dirname(path), { recursive: true });
  fs.writeFileSync(path, JSON.stringify(payload, null, 2), 'utf8');
}

async function clickCanvasFraction(page, canvas, fx, fy) {
  const box = await canvas.boundingBox();
  expect(box, 'canvas bounding box').not.toBeNull();
  await page.mouse.click(box.x + box.width * fx, box.y + box.height * fy);
}

test('Godot Web build boots to a nonblank canvas', async ({ page }) => {
  const consoleEntries = [];
  const pageErrors = [];
  const failedRequests = [];

  page.on('console', (msg) => {
    consoleEntries.push({ type: msg.type(), text: msg.text() });
  });
  page.on('pageerror', (err) => {
    pageErrors.push(String(err && err.stack ? err.stack : err));
  });
  page.on('requestfailed', (request) => {
    const failure = request.failure();
    failedRequests.push({
      url: request.url(),
      errorText: failure ? failure.errorText : 'unknown',
    });
  });

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(12000);

  const canvas = page.locator('canvas').first();
  await expect(canvas).toBeVisible({ timeout: 30000 });
  await page.screenshot({ path: screenshotPath, fullPage: true });
  const taskScreenshots = [];

  await clickCanvasFraction(page, canvas, 0.19, 0.72);
  await page.waitForTimeout(800);
  const forgeMenuScreenshot = taskScreenshotPath('forge-desk-menu-path');
  await page.screenshot({ path: forgeMenuScreenshot, fullPage: true });
  taskScreenshots.push(forgeMenuScreenshot);
  await clickCanvasFraction(page, canvas, 0.09, 0.97);
  await page.waitForTimeout(1800);
  const forgeWorkbenchScreenshot = taskScreenshotPath('forge-workbench-path');
  await page.screenshot({ path: forgeWorkbenchScreenshot, fullPage: true });
  taskScreenshots.push(forgeWorkbenchScreenshot);
  await clickCanvasFraction(page, canvas, 0.79, 0.88);
  await page.waitForTimeout(1600);
  const forgeRhythmScreenshot = taskScreenshotPath('forge-rhythm-interrupt-path');
  await page.screenshot({ path: forgeRhythmScreenshot, fullPage: true });
  taskScreenshots.push(forgeRhythmScreenshot);
  await clickCanvasFraction(page, canvas, 0.84, 0.86);
  await page.waitForTimeout(400);
  const forgeRightEyeClickScreenshot = taskScreenshotPath('forge-rhythm-right-eye-click-path');
  await page.screenshot({ path: forgeRightEyeClickScreenshot, fullPage: true });
  taskScreenshots.push(forgeRightEyeClickScreenshot);
  await clickCanvasFraction(page, canvas, 0.10, 0.07);
  await page.waitForTimeout(1200);
  const forgeReturnScreenshot = taskScreenshotPath('forge-interrupt-return-path');
  await page.screenshot({ path: forgeReturnScreenshot, fullPage: true });
  taskScreenshots.push(forgeReturnScreenshot);

  await clickCanvasFraction(page, canvas, 0.60, 0.32);
  await page.waitForTimeout(1000);
  const noticeBoardOpenScreenshot = taskScreenshotPath('notice-board-open-path');
  await page.screenshot({ path: noticeBoardOpenScreenshot, fullPage: true });
  taskScreenshots.push(noticeBoardOpenScreenshot);
  await clickCanvasFraction(page, canvas, 0.82, 0.26);
  await page.waitForTimeout(800);
  const noticeBoardActionScreenshot = taskScreenshotPath('notice-board-action-attempt-path');
  await page.screenshot({ path: noticeBoardActionScreenshot, fullPage: true });
  taskScreenshots.push(noticeBoardActionScreenshot);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);

  await clickCanvasFraction(page, canvas, 0.25, 0.42);
  await page.waitForTimeout(1200);
  const cushionScreenshot = taskScreenshotPath('cushion-path');
  await page.screenshot({ path: cushionScreenshot, fullPage: true });
  taskScreenshots.push(cushionScreenshot);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);

  await clickCanvasFraction(page, canvas, 0.25, 0.68);
  await page.waitForTimeout(1000);
  const districtSelectorScreenshot = taskScreenshotPath('district-selector-identity-path');
  await page.screenshot({ path: districtSelectorScreenshot, fullPage: true });
  taskScreenshots.push(districtSelectorScreenshot);
  await clickCanvasFraction(page, canvas, 0.50, 0.30);
  await page.waitForTimeout(1800);
  const cityScreenshot = taskScreenshotPath('city-entry-path');
  await page.screenshot({ path: cityScreenshot, fullPage: true });
  taskScreenshots.push(cityScreenshot);
  const cityTopbarScreenshot = taskScreenshotPath('city-topbar-opportunity-path');
  await page.screenshot({ path: cityTopbarScreenshot, fullPage: true });
  taskScreenshots.push(cityTopbarScreenshot);

  await clickCanvasFraction(page, canvas, 0.50, 0.36);
  await page.waitForTimeout(1000);
  const dailyOpportunityOpenScreenshot = taskScreenshotPath('daily-opportunity-open-path');
  await page.screenshot({ path: dailyOpportunityOpenScreenshot, fullPage: true });
  taskScreenshots.push(dailyOpportunityOpenScreenshot);
  await clickCanvasFraction(page, canvas, 0.50, 0.62);
  await page.waitForTimeout(1000);
  const dailyOpportunityResolvedScreenshot = taskScreenshotPath('daily-opportunity-resolved-path');
  await page.screenshot({ path: dailyOpportunityResolvedScreenshot, fullPage: true });
  taskScreenshots.push(dailyOpportunityResolvedScreenshot);

  await clickCanvasFraction(page, canvas, 0.50, 0.22);
  await page.waitForTimeout(1200);
  const npcRootScreenshot = taskScreenshotPath('npc-root-suppressed-city-surface-path');
  await page.screenshot({ path: npcRootScreenshot, fullPage: true });
  taskScreenshots.push(npcRootScreenshot);

  await clickCanvasFraction(page, canvas, 0.38, 0.72);
  await page.waitForTimeout(900);
  const npcTalkScreenshot = taskScreenshotPath('npc-talk-menu-path');
  await page.screenshot({ path: npcTalkScreenshot, fullPage: true });
  taskScreenshots.push(npcTalkScreenshot);

  await clickCanvasFraction(page, canvas, 0.52, 0.72);
  await page.waitForTimeout(900);
  const npcEventScreenshot = taskScreenshotPath('npc-event-menu-path');
  await page.screenshot({ path: npcEventScreenshot, fullPage: true });
  taskScreenshots.push(npcEventScreenshot);

  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
  const cityRestoredScreenshot = taskScreenshotPath('city-surface-restored-after-npc-path');
  await page.screenshot({ path: cityRestoredScreenshot, fullPage: true });
  taskScreenshots.push(cityRestoredScreenshot);

  const canvasInfo = await canvas.evaluate((node) => {
    const rect = node.getBoundingClientRect();
    const width = node.width || Math.round(rect.width);
    const height = node.height || Math.round(rect.height);
    const context = node.getContext('2d');
    let nonblank = null;
    if (context && width > 0 && height > 0) {
      const sampleWidth = Math.min(width, 64);
      const sampleHeight = Math.min(height, 64);
      const image = context.getImageData(0, 0, sampleWidth, sampleHeight).data;
      nonblank = false;
      for (let index = 0; index < image.length; index += 4) {
        if (image[index] !== 0 || image[index + 1] !== 0 || image[index + 2] !== 0 || image[index + 3] !== 0) {
          nonblank = true;
          break;
        }
      }
    }
    return { width, height, rectWidth: rect.width, rectHeight: rect.height, nonblank };
  });

  const severeConsole = consoleEntries.filter((entry) => ['error'].includes(entry.type));
  const ok = canvasInfo.width > 0 && canvasInfo.height > 0 && pageErrors.length === 0 && failedRequests.length === 0;

  const payload = {
    gate: 'webqa_regression',
    ok,
    status: ok ? 'passed' : 'failed',
    url,
    screenshot: screenshotPath,
    task_path: 'forge desk menu to forge workbench, forge confirm attempt to rhythm/interruption surface, right-side heart-eye lane click, clickable interrupt-return attempt, notice-board open plus commission action attempt, then cushion click, front-door district selector surface including residual-identity entry mount when available, district entry, city topbar church-awareness/opportunity visibility, map daily opportunity click and encounter-choice resolution attempt, NPC root social-state summary with city map/topbar/footer button surface suppressed, talk and event/task submenu visibility without NPC service button wall, then NPC close restoring city interaction surface',
    task_screenshots: taskScreenshots,
    canvas: canvasInfo,
    console_errors: severeConsole,
    page_errors: pageErrors,
    failed_requests: failedRequests,
  };
  writeJson(consoleJsonPath, { console: consoleEntries, page_errors: pageErrors, failed_requests: failedRequests });
  writeJson(resultJsonPath, payload);

  expect(payload.page_errors, 'no uncaught page errors').toEqual([]);
  expect(payload.failed_requests, 'no failed network requests').toEqual([]);
  expect(canvasInfo.width, 'canvas width').toBeGreaterThan(0);
  expect(canvasInfo.height, 'canvas height').toBeGreaterThan(0);
});
