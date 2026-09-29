// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-startup-timeout');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

// The app never starts listening, and a short lifecycle.startup_timeout makes
// the readiness wait give up after 5 seconds.
test.describe('Startup timeout - r-shiny system', () => {
  test.setTimeout(120000);
  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createTestApp(APP_DIR, `
      library(shiny)
      Sys.sleep(1e6)
    `);
    fs.writeFileSync(
      path.join(APP_DIR, '_shinyelectron.yml'),
      'lifecycle:\n  startup_timeout: 5000\n'
    );

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shiny',
      runtime_strategy: 'system',
    });
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

  /**
   * Wait for the error screen, then make sure nothing replaces it.
   * @param {import('@playwright/test').Page} window
   */
  async function expectErrorScreenToStay(window) {
    await window.waitForSelector('#state-error.active', { timeout: 60000 });
    await expect(window.locator('#error-title')).toHaveText('Failed to start');
    await expect(window.locator('#error-message')).toContainText('within 5 seconds');

    await window.waitForTimeout(3000);
    await expect(window.locator('#state-error')).toHaveClass(/active/);
    await expect(window.locator('#state-shutdown')).not.toHaveClass(/active/);
    await expect(window.locator('#btn-retry')).toBeVisible();
    await expect(window.locator('#btn-quit')).toBeVisible();
  }

  test('the error screen stays up with Retry after a startup timeout', async () => {
    electronApp = await launchApp(electronDir);
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');

    await expectErrorScreenToStay(window);

    // Retry reloads the lifecycle page, times out again, and lands on the
    // error screen once more.
    await window.click('#btn-retry');
    await window.waitForSelector('#state-error.active', { state: 'detached', timeout: 10000 });
    await expectErrorScreenToStay(window);
  });
});
