// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-r-shinylive');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('R Shinylive', () => {
  // Shinylive conversion + WebR download can be slow
  test.setTimeout(180000);

  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createTestApp(APP_DIR, `
      library(shiny)
      shinyApp(
        ui = fluidPage(h1("Shinylive Test", id = "main-title")),
        server = function(input, output) {}
      )
    `);

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'r-shinylive',
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

  test('window opens and serves on localhost', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 120000 });
    const url = window.url();
    expect(url).toMatch(/localhost:\d+/);
  });

  // Read the server response from Node rather than from inside the page:
  // shinylive registers a service worker and reloads, which destroys the
  // page execution context and makes in-page fetch()/content() flaky.
  function httpGet(url) {
    const http = require('http');
    return new Promise((resolve, reject) => {
      http.get(url, (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ headers: res.headers, body }));
      }).on('error', reject);
    });
  }

  test('serves with required COOP/COEP headers', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 120000 });

    const { headers } = await httpGet(window.url());
    expect(headers['cross-origin-opener-policy']).toBe('same-origin');
    expect(headers['cross-origin-embedder-policy']).toBe('require-corp');
  });

  test('shinylive page serves content', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 120000 });

    const { body } = await httpGet(window.url());
    expect(body.length).toBeGreaterThan(100);
  });
});
