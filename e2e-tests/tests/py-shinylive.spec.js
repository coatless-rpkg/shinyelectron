// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createPythonTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-py-shinylive');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('Python Shinylive', () => {
  test.setTimeout(180000);

  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    createPythonTestApp(APP_DIR, `
from shiny import App, ui

app_ui = ui.page_fluid(
    ui.h1("PyShinylive Test", id="main-title")
)

def server(input, output, session):
    pass

app = App(app_ui, server)
`);

    electronDir = buildApp({
      appdir: APP_DIR,
      destdir: BUILD_DIR,
      app_type: 'py-shinylive',
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
    // Shinylive starts Express server then navigates — may take a moment
    await window.waitForURL(/localhost/, { timeout: 60000 });
    const url = window.url();
    expect(url).toMatch(/localhost:\d+/);
  });

  test('serves with COOP/COEP headers', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 60000 });
    await window.waitForLoadState('load');

    const coopHeader = await window.evaluate(async () => {
      const resp = await fetch(document.location.href);
      return resp.headers.get('cross-origin-opener-policy');
    });
    expect(coopHeader).toBe('same-origin');
  });

  test('shinylive page has content', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 60000 });
    await window.waitForLoadState('load');

    const html = await window.content();
    expect(html.length).toBeGreaterThan(100);
  });
});
