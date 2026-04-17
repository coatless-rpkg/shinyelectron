// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-r-bundled');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('R Shiny - bundled strategy', () => {
  // Bundled strategy downloads portable R + installs packages — can be very slow
  test.setTimeout(600000);

  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createTestApp(APP_DIR, `
      library(shiny)
      shinyApp(
        ui = fluidPage(h1("Bundled R Test", id = "main-title")),
        server = function(input, output) {}
      )
    `);

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shiny',
      runtime_strategy: 'bundled',
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

  test('bundled runtime directory exists in built app', async () => {
    // Verify the runtime was embedded at build time
    const runtimeDir = path.join(electronDir, 'runtime', 'R');
    expect(fs.existsSync(runtimeDir)).toBe(true);
  });

  test('window opens and shows lifecycle page', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    const url = window.url();
    expect(url).toContain('lifecycle.html');
  });

  test('Shiny app loads using bundled R', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 60000 });
    await window.waitForSelector('#main-title', { timeout: 30000 });
    const title = await window.textContent('#main-title');
    expect(title).toBe('Bundled R Test');
  });
});
