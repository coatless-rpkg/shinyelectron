// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createMultiAppProject } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-multi');
const PROJECT_DIR = path.join(TMP_DIR, 'project');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('Multi-App Launcher - r-shiny system', () => {
  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    // Create a multi-app project with two simple apps
    createMultiAppProject(PROJECT_DIR, [
      {
        id: 'app-alpha',
        name: 'Alpha App',
        description: 'First test app',
        code: `
          library(shiny)
          shinyApp(
            ui = fluidPage(h1("Alpha", id = "app-title")),
            server = function(input, output) {}
          )
        `,
      },
      {
        id: 'app-beta',
        name: 'Beta App',
        description: 'Second test app',
        code: `
          library(shiny)
          shinyApp(
            ui = fluidPage(h1("Beta", id = "app-title")),
            server = function(input, output) {}
          )
        `,
      },
    ]);

    // Build the multi-app Electron app
    electronDir = buildApp({
      appdir: PROJECT_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shiny',
      runtime_strategy: 'system',
    });
  });

  test.beforeEach(async () => {
    electronApp = await launchApp(electronDir);
  });

  test.afterEach(async () => {
    if (electronApp) {
      await electronApp.close();
    }
  });

  test.afterAll(() => {
    if (fs.existsSync(TMP_DIR)) {
      fs.rmSync(TMP_DIR, { recursive: true });
    }
  });

  test('launcher page renders with app cards', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');

    // Should show launcher.html
    const url = window.url();
    expect(url).toContain('launcher.html');

    // Should have two app cards
    const cards = await window.$$('.app-card');
    expect(cards.length).toBe(2);
  });

  test('app cards display correct names', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await window.waitForSelector('.app-card', { timeout: 10000 });

    const names = await window.$$eval('.app-name', els =>
      els.map(el => el.textContent)
    );
    expect(names).toContain('Alpha App');
    expect(names).toContain('Beta App');
  });

  test('app cards display descriptions', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await window.waitForSelector('.app-card', { timeout: 10000 });

    const descs = await window.$$eval('.app-desc', els =>
      els.map(el => el.textContent)
    );
    expect(descs).toContain('First test app');
    expect(descs).toContain('Second test app');
  });

  test('clicking an app card navigates away from launcher', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await window.waitForSelector('.app-card', { timeout: 10000 });

    // Click the first app card
    await window.click('.app-card');

    // Should navigate away from launcher.html
    await window.waitForFunction(
      () => !window.location.href.includes('launcher.html'),
      { timeout: 30000 }
    );

    const url = window.url();
    expect(url).not.toContain('launcher.html');
  });

  test('app icon shows first letter when no icon provided', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    await window.waitForSelector('.app-icon', { timeout: 10000 });

    const iconTexts = await window.$$eval('.app-icon', els =>
      els.map(el => el.textContent.trim())
    );
    // Should show first letter of app name
    expect(iconTexts).toContain('A');
    expect(iconTexts).toContain('B');
  });
});
