// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-r-container');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('R Shiny - container strategy', () => {
  // Container strategy builds Docker image on first run — slow
  test.setTimeout(600000);

  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createTestApp(APP_DIR, `
      library(shiny)
      shinyApp(
        ui = fluidPage(h1("Container Test", id = "main-title")),
        server = function(input, output) {}
      )
    `);

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shiny',
      runtime_strategy: 'container',
    });
  });

  test.beforeEach(async () => {
    electronApp = await launchApp(electronDir);
  });

  test.afterEach(async () => {
    if (electronApp) await electronApp.close();
  });

  test.afterAll(() => {
    // Stop any lingering Docker containers from this test
    try {
      const { execSync } = require('child_process');
      const ids = execSync('docker ps -q --filter "ancestor=shinyelectron/r-shiny:latest"', { encoding: 'utf8' }).trim();
      if (ids) {
        execSync(`docker stop ${ids.split('\n').join(' ')}`, { stdio: 'ignore' });
        execSync(`docker rm -f ${ids.split('\n').join(' ')}`, { stdio: 'ignore' });
      }
    } catch { /* no containers to clean */ }

    if (fs.existsSync(TMP_DIR)) fs.rmSync(TMP_DIR, { recursive: true });
  });

  test('Dockerfile exists in built app', async () => {
    const dockerfilePath = path.join(electronDir, 'dockerfiles', 'Dockerfile');
    expect(fs.existsSync(dockerfilePath)).toBe(true);
  });

  test('window opens and shows lifecycle page', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    const url = window.url();
    expect(url).toContain('lifecycle.html');
  });

  test('container starts and app loads', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');

    // Container build + start can take a while
    await window.waitForURL(/localhost/, { timeout: 300000 });

    await window.waitForSelector('#main-title', { timeout: 30000 });
    const title = await window.textContent('#main-title');
    expect(title).toBe('Container Test');
  });
});
