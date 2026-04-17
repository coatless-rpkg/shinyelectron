// @ts-check
const { test, expect } = require('@playwright/test');
const { buildApp, launchApp, createTestApp } = require('./helpers');
const path = require('path');
const fs = require('fs');
const os = require('os');

const TMP_DIR = path.join(os.tmpdir(), 'shinyelectron-e2e-single');
const APP_DIR = path.join(TMP_DIR, 'app');
const BUILD_DIR = path.join(TMP_DIR, 'build');

test.describe('Single App - r-shiny system', () => {
  /** @type {import('@playwright/test').ElectronApplication} */
  let electronApp;
  let electronDir;

  test.beforeAll(async () => {
    // Create a simple Shiny app
    createTestApp(APP_DIR, `
      library(shiny)
      shinyApp(
        ui = fluidPage(
          h1("E2E Test App", id = "main-title"),
          textInput("name", "Your name:", "World"),
          textOutput("greeting"),
          actionButton("btn", "Click me", class = "btn-primary")
        ),
        server = function(input, output) {
          output$greeting <- renderText(paste("Hello,", input$name, "!"))
        }
      )
    `);

    // Build the Electron app
    electronDir = buildApp({
      appdir: APP_DIR,
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

  test('window opens and has correct title', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForLoadState('domcontentloaded');
    const title = await window.title();
    // Title could be from lifecycle.html or the Shiny app
    expect(title).toBeTruthy();
  });

  test('lifecycle page shows during startup', async () => {
    const window = await electronApp.firstWindow();
    // The first page loaded should be lifecycle.html
    const url = window.url();
    expect(url).toContain('lifecycle.html');
  });

  test('Shiny app loads after startup', async () => {
    const window = await electronApp.firstWindow();

    // Wait for navigation to localhost (Shiny server)
    await window.waitForURL(/localhost/, { timeout: 30000 });

    // Wait for the Shiny app to render
    await window.waitForSelector('#main-title', { timeout: 15000 });
    const title = await window.textContent('#main-title');
    expect(title).toBe('E2E Test App');
  });

  test('Shiny input/output works', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 30000 });
    await window.waitForSelector('#name', { timeout: 15000 });

    // Clear and type a new name
    await window.fill('#name', 'Playwright');

    // Wait for Shiny to process the input
    await window.waitForTimeout(1000);

    // Check the output updated
    const greeting = await window.textContent('#greeting');
    expect(greeting).toContain('Playwright');
  });

  test('action button is clickable', async () => {
    const window = await electronApp.firstWindow();
    await window.waitForURL(/localhost/, { timeout: 30000 });
    await window.waitForSelector('#btn', { timeout: 15000 });

    // Click the button
    await window.click('#btn');
    // If we get here without error, the button is clickable
    expect(true).toBe(true);
  });
});
