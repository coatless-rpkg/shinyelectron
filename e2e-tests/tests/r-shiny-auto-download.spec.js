// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-r-autodownload');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('R Shiny - auto-download strategy', () => {
  // Auto-download downloads R runtime on first launch — needs network + time
  test.setTimeout(300000);

  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createTestApp(APP_DIR, `
      library(shiny)
      shinyApp(
        ui = fluidPage(h1("Auto-Download Test", id = "main-title")),
        server = function(input, output) {}
      )
    `);

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shiny',
      runtime_strategy: 'auto-download',
    });
  });

  test.beforeEach(async () => {
    electronApp = await launchApp(electronDir);
  });

  test.afterEach(async () => {
    if (electronApp) await electronApp.close();
  });

  test.afterAll(() => {
    if (fs.existsSync(TMP_DIR)) fs.rmSync(TMP_DIR, { recursive: true });
  });

  test('runtime manifest exists in built app', async () => {
    const manifestPath = path.join(electronDir, 'src', 'app', 'runtime-manifest.json');
    expect(fs.existsSync(manifestPath)).toBe(true);

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    expect(manifest.language).toBe('r');
    expect(manifest.download_url).toBeTruthy();
    expect(manifest.install_path).toBeTruthy();
  });

  test('window opens and shows lifecycle page', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    const url = window.url();
    expect(url).toContain('lifecycle.html');
  });

  test('shows download progress then loads app', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');

    // Should eventually navigate to localhost after download + start
    // First run downloads ~200MB portable R — can take 5+ minutes
    await window.waitForURL(/localhost/, { timeout: 280000 });

    await window.waitForSelector('#main-title', { timeout: 30000 });
    const title = await window.textContent('#main-title');
    expect(title).toBe('Auto-Download Test');
  });
});
