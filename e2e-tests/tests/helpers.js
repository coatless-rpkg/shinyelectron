const { _electron: electron } = require('@playwright/test');
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

/**
 * Build a shinyelectron app and return the Electron app directory path.
 * @param {object} options
 * @param {string} options.appdir - Path to the Shiny app directory.
 * @param {string} options.destdir - Path to the output directory.
 * @param {string} [options.app_type] - App type (default: 'r-shiny').
 * @param {string} [options.runtime_strategy] - Runtime strategy (default: 'system').
 * @returns {string} Path to the electron-app directory.
 */
function buildApp({ appdir, destdir, app_type = 'r-shiny', runtime_strategy }) {
  // Clean previous build
  if (fs.existsSync(destdir)) {
    fs.rmSync(destdir, { recursive: true });
  }

  // Shinylive types don't use runtime_strategy; native types default to 'system'
  const isShinylive = app_type.endsWith('-shinylive');
  const strategyArg = isShinylive
    ? ''
    : `runtime_strategy = "${runtime_strategy || 'system'}",`;

  const rCode = `
    devtools::load_all("${path.resolve(__dirname, '..', '..')}");
    export(
      appdir = "${appdir.replace(/\\/g, '/')}",
      destdir = "${destdir.replace(/\\/g, '/')}",
      app_type = "${app_type}",
      ${strategyArg}
      sign = FALSE,
      build = TRUE,
      overwrite = TRUE,
      verbose = FALSE
    )
  `;

  execSync(`Rscript -e '${rCode.replace(/'/g, "\\'")}'`, {
    stdio: 'pipe',
    timeout: 600000,
  });

  return path.join(destdir, 'electron-app');
}

/**
 * Launch an Electron app with Playwright.
 * @param {string} electronAppDir - Path to the electron-app directory.
 * @returns {Promise<import('@playwright/test').ElectronApplication>}
 */
async function launchApp(electronAppDir) {
  const electronPath = require('electron');
  const app = await electron.launch({
    args: [electronAppDir],
    executablePath: electronPath,
  });
  return app;
}

/**
 * Create a temporary single-app Shiny project.
 * @param {string} tmpDir - Temp directory path.
 * @param {string} appCode - R code for app.R.
 */
function createTestApp(tmpDir, appCode) {
  fs.mkdirSync(tmpDir, { recursive: true });
  fs.writeFileSync(path.join(tmpDir, 'app.R'), appCode);
}

/**
 * Create a temporary multi-app project.
 * @param {string} tmpDir - Temp directory path.
 * @param {object[]} apps - Array of { id, name, description, code }.
 */
function createMultiAppProject(tmpDir, apps) {
  fs.mkdirSync(tmpDir, { recursive: true });

  const config = {
    app: { name: 'Test Suite', version: '1.0.0' },
    build: { type: 'r-shiny', runtime_strategy: 'system' },
    apps: apps.map(a => ({
      id: a.id,
      name: a.name,
      description: a.description || '',
      path: `./apps/${a.id}`,
    })),
  };

  // Write YAML config (simple serialization without external dependency)
  let yamlStr = `app:\n  name: "${config.app.name}"\n  version: "${config.app.version}"\n\nbuild:\n  type: "${config.build.type}"\n  runtime_strategy: "${config.build.runtime_strategy}"\n\napps:\n`;
  for (const a of config.apps) {
    yamlStr += `  - id: "${a.id}"\n    name: "${a.name}"\n    description: "${a.description}"\n    path: "${a.path}"\n`;
  }
  fs.writeFileSync(path.join(tmpDir, '_shinyelectron.yml'), yamlStr);

  // Create each app
  for (const a of apps) {
    const appDir = path.join(tmpDir, 'apps', a.id);
    fs.mkdirSync(appDir, { recursive: true });
    fs.writeFileSync(path.join(appDir, 'app.R'), a.code);
  }
}

/**
 * Create a temporary Python Shiny app.
 * @param {string} tmpDir - Temp directory path.
 * @param {string} appCode - Python code for app.py.
 */
function createPythonTestApp(tmpDir, appCode) {
  fs.mkdirSync(tmpDir, { recursive: true });
  fs.writeFileSync(path.join(tmpDir, 'app.py'), appCode);
}

module.exports = { buildApp, launchApp, createTestApp, createPythonTestApp, createMultiAppProject };
