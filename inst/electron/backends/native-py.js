// Native Python Shiny backend — spawns Python child process running shiny run
const { EventEmitter } = require('events');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {
  waitForServer, findAvailablePort, killProcessTree,
  sortCandidatesByVersion, reportRuntimeCandidates
} = require('./utils');

class NativePyBackend extends EventEmitter {
  constructor() {
    super();
    this.pyProcess = null;
  }

  /**
   * Scan common Python installation directories and return the latest python path.
   * @returns {string|null} Path to python executable, or null if not found.
   */
  findPythonInCommonLocations() {
    const candidates = [];

    if (process.platform === 'win32') {
      // Windows: Python installs to various locations
      const searchBases = [
        path.join(process.env.LOCALAPPDATA || '', 'Programs', 'Python'),
        path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Python'),
        path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Python')
      ];

      // Also check the Windows Store / py launcher paths
      const pyLauncher = path.join(process.env.LOCALAPPDATA || '', 'Microsoft', 'WindowsApps', 'python.exe');
      if (fs.existsSync(pyLauncher)) {
        candidates.push({ version: '0.0.0', path: pyLauncher });
      }

      for (const base of searchBases) {
        if (!fs.existsSync(base)) continue;
        try {
          const entries = fs.readdirSync(base).filter(d => /^Python\d/i.test(d) || /^\d+\.\d+/.test(d));
          for (const entry of entries) {
            const pythonPath = path.join(base, entry, 'python.exe');
            if (fs.existsSync(pythonPath)) {
              const ver = entry.replace(/^Python/i, '').replace(/(\d)(\d)/, '$1.$2');
              candidates.push({ version: ver || '0.0.0', path: pythonPath });
            }
          }
        } catch { /* ignore */ }
      }
    } else if (process.platform === 'darwin') {
      // macOS: Homebrew, system, pyenv, python.org installer
      const macPaths = [
        '/opt/homebrew/bin/python3',
        '/usr/local/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/Current/bin/python3'
      ];
      for (const p of macPaths) {
        if (fs.existsSync(p)) {
          candidates.push({ version: '0.0.0', path: p });
          break;
        }
      }
    } else {
      // Linux: package manager, pyenv, deadsnakes
      const linuxPaths = [
        '/usr/bin/python3',
        '/usr/local/bin/python3'
      ];
      for (const p of linuxPaths) {
        if (fs.existsSync(p)) {
          candidates.push({ version: '0.0.0', path: p });
          break;
        }
      }
    }

    if (candidates.length === 0) return null;
    sortCandidatesByVersion(candidates);
    reportRuntimeCandidates(this, 'Python', candidates);
    return candidates;
  }

  /**
   * Find the Python executable.
   * Priority: config.python_executable > cached auto-downloaded runtime > system PATH > common locations
   * @param {object} config - Backend configuration.
   * @returns {string} Path to Python executable.
   */
  findPython(config) {
    this.emit('status', { phase: 'finding_runtime', message: 'Looking for Python...' });

    // 1. Explicit path from config
    if (config && config.python_executable) {
      this.emit('status', { phase: 'runtime_found', message: `Found Python: ${config.python_executable}` });
      return config.python_executable;
    }

    // 2. Check for bundled runtime embedded in the Electron app
    // Resolve ASAR-unpacked path (runtime files are extracted outside app.asar)
    let appBasePath = path.join(__dirname, '..');
    const unpackedBase = appBasePath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedBase !== appBasePath && fs.existsSync(unpackedBase)) {
      appBasePath = unpackedBase;
    }
    const runtimeDir = path.join(appBasePath, 'runtime', 'Python');
    if (fs.existsSync(runtimeDir)) {
      const pyExe = process.platform === 'win32' ? 'python.exe' : 'python3';
      try {
        const entries = fs.readdirSync(runtimeDir);
        for (const entry of entries) {
          const subdir = path.join(runtimeDir, entry);
          if (!fs.statSync(subdir).isDirectory()) continue;
          // Check common python-build-standalone layouts
          // Actual layout: runtime/Python/{version}/python/bin/python3
          const candidates = [
            path.join(subdir, 'python', 'bin', pyExe),
            path.join(subdir, 'python', 'bin', 'python'),
            path.join(subdir, 'python', pyExe),
            path.join(subdir, 'bin', pyExe),
            path.join(subdir, 'bin', 'python'),
            path.join(subdir, pyExe),
            path.join(subdir, 'install', 'bin', pyExe)
          ];
          for (const c of candidates) {
            if (fs.existsSync(c)) {
              console.log(`Found bundled Python: ${c}`);
              this.emit('status', { phase: 'runtime_found', message: `Found bundled Python` });
              return c;
            }
          }
        }
        // Flat layout: runtime/Python/bin/python3
        const flat = path.join(runtimeDir, 'bin', pyExe);
        if (fs.existsSync(flat)) {
          this.emit('status', { phase: 'runtime_found', message: `Found bundled Python` });
          return flat;
        }
      } catch (err) {
        console.warn('Error checking bundled Python runtime:', err.message);
      }
    }

    // 3. Check for auto-downloaded runtime via manifest
    if (config && config.runtime_strategy === 'auto-download') {
      try {
        const appBasePath = path.join(__dirname, '..');
        const manifestPath = path.join(appBasePath, 'src', 'app', 'runtime-manifest.json');
        if (fs.existsSync(manifestPath)) {
          const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
          if (manifest.language === 'python') {
            const { findCachedRuntime } = require('./runtime-downloader');
            const cached = findCachedRuntime(manifest);
            if (cached) {
              this.emit('status', { phase: 'runtime_found', message: `Found Python: ${cached}` });
              return cached;
            }
          }
        }
      } catch (err) {
        console.warn('Failed to check cached runtime:', err.message);
      }
    }

    // 3. Try system PATH first
    const pathCmds = process.platform === 'win32' ? ['python.exe'] : ['python3', 'python'];
    for (const cmd of pathCmds) {
      try {
        const { execFileSync } = require('child_process');
        execFileSync(cmd, ['--version'], { stdio: 'ignore' });
        this.emit('status', { phase: 'runtime_found', message: `Found Python: ${cmd}` });
        return cmd;
      } catch { /* not on PATH */ }
    }

    // 4. Scan common installation directories
    const candidates = this.findPythonInCommonLocations();
    if (candidates && candidates.length > 0) {
      this.emit('status', { phase: 'runtime_found', message: `Found Python: ${candidates[0].path}` });
      return candidates[0].path;
    }

    // 5. Last resort
    const fallback = process.platform === 'win32' ? 'python.exe' : 'python3';
    this.emit('status', { phase: 'runtime_found', message: `Found Python: ${fallback}` });
    return fallback;
  }

  /**
   * Start the native Python Shiny server.
   * @param {object} options
   * @param {string} options.appPath - Path to the Shiny app directory.
   * @param {number} options.port - Port to listen on.
   * @param {object} options.config - Backend configuration.
   * @returns {Promise<{port: number}>} Resolves when the Shiny server is ready.
   */
  async start({ appPath, port, config }) {
    this.removeAllListeners();

    // Resolve ASAR-unpacked base path for runtime access
    let startBasePath = path.join(__dirname, '..');
    const unpackedStart = startBasePath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedStart !== startBasePath && fs.existsSync(unpackedStart)) {
      startBasePath = unpackedStart;
    }

    let python = this.findPython(config || {});

    // For auto-download strategy, download runtime if not found on system
    if (config && config.runtime_strategy === 'auto-download') {
      try {
        const appBasePath = path.join(__dirname, '..');
        const manifestPath = path.join(appBasePath, 'src', 'app', 'runtime-manifest.json');
        if (fs.existsSync(manifestPath)) {
          const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
          if (manifest.language === 'python') {
            const { findCachedRuntime, downloadRuntime } = require('./runtime-downloader');

            if (!findCachedRuntime(manifest)) {
              const { isOnline } = require('./utils');
              if (!await isOnline()) {
                this.emit('status', {
                  phase: 'error',
                  message: 'This app needs to download Python on first launch but no internet connection was detected.\n\nPlease check your network connection and try again.'
                });
                throw new Error('No internet connection for runtime download');
              }
              console.log('Python runtime not found, downloading...');
              this.emit('status', { phase: 'downloading_runtime', message: 'Downloading Python runtime...' });
              python = await downloadRuntime(manifest, (msg, pct) => {
                console.log(`[Runtime] ${msg}`);
                this.emit('status', { phase: 'downloading_runtime', message: msg, progress: pct });
              });
            }
          }
        }
      } catch (err) {
        const error = new Error(`Failed to set up Python runtime: ${err.message}`);
        this.emit('error', error);
        throw error;
      }
    }

    // Runtime version picker
    const promptVersion = config?.prompt_runtime_version ?? false;
    const pickerChecker = require('./dependency-checker');
    const appSlugPicker = config?.app_slug || 'default';
    const pickerPrefs = pickerChecker.readPreferences(appSlugPicker);

    // Check if user has a saved runtime preference
    if (pickerPrefs && pickerPrefs.runtime_path) {
      if (fs.existsSync(pickerPrefs.runtime_path)) {
        python = pickerPrefs.runtime_path;
        this.emit('status', { phase: 'runtime_found', message: `Using saved Python: ${python}` });
      }
    } else if (promptVersion) {
      // Check if multiple versions were found
      const pyCandidates = this.findPythonInCommonLocations();
      if (pyCandidates && pyCandidates.length > 1) {
        this.emit('status', {
          phase: 'runtime_versions_found',
          message: `Found ${pyCandidates.length} Python installations`,
          detail: { versions: pyCandidates }
        });

        // Wait for user selection
        const selectedPath = await new Promise((resolve) => {
          this.once('runtime-selected', (data) => {
            // Save preference
            const currentPrefs = pickerChecker.readPreferences(appSlugPicker) || {};
            currentPrefs.runtime_path = data.runtimePath;
            pickerChecker.savePreferences(appSlugPicker, currentPrefs);
            resolve(data.runtimePath);
          });
        });

        python = selectedPath;
        this.emit('status', { phase: 'runtime_found', message: `Selected Python: ${python}` });
      }
    }

    // For system/auto-download strategy, ensure a venv exists so we can
    // install packages without PEP 668 "externally managed" errors
    const isBundled = fs.existsSync(path.join(startBasePath, 'runtime', 'Python'));
    if (!isBundled) {
      const appSlugVenv = config?.app_slug || 'default';
      const venvDir = path.join(os.homedir(), '.shinyelectron', 'venvs', appSlugVenv);
      const venvPy = process.platform === 'win32'
        ? path.join(venvDir, 'Scripts', 'python.exe')
        : path.join(venvDir, 'bin', 'python3');

      if (!fs.existsSync(venvPy)) {
        this.emit('status', { phase: 'checking_packages', message: 'Creating Python virtual environment...' });
        try {
          const { execFileSync } = require('child_process');
          fs.mkdirSync(venvDir, { recursive: true });
          execFileSync(python, ['-m', 'venv', venvDir], { timeout: 60000, stdio: 'ignore' });
          console.log(`Created venv at ${venvDir}`);
          this.emit('status', { phase: 'checking_packages', message: 'Python environment ready' });
        } catch (err) {
          console.warn('Failed to create venv:', err.message);
        }
      }

      if (fs.existsSync(venvPy)) {
        python = venvPy;
        this.emit('status', { phase: 'runtime_found', message: `Using Python venv: ${venvDir}` });
      }
    }

    // Check and install dependencies (skip for bundled — packages baked in at build time)
    const checker = require('./dependency-checker');
    const manifest = checker.readManifest(appPath);

    if (!isBundled && manifest && manifest.packages && manifest.packages.length > 0) {
      this.emit('status', { phase: 'checking_packages', message: 'Checking Python packages...' });

      const appSlug = config?.app_slug || 'default';
      const prefs = checker.readPreferences(appSlug);
      const libPath = checker.resolveLibPath(appSlug, config, prefs);

      const missing = await checker.checkMissingPy(manifest.packages, python);

      if (missing.length > 0) {
        const promptBeforeInstall = config?.prompt_before_install ?? false;

        if (promptBeforeInstall && !prefs) {
          this.emit('status', {
            phase: 'awaiting_install_confirmation',
            message: `${missing.length} packages need to be installed`,
            detail: { missing, all: manifest.packages, system_deps: [] }
          });

          await new Promise((resolveInstall, rejectInstall) => {
            this.once('install-packages', async (data) => {
              const chosenPath = data.libPath === 'app-local'
                ? path.join(os.homedir(), '.shinyelectron', 'libraries', appSlug)
                : data.libPath === 'system' ? null : data.libPath;

              checker.savePreferences(appSlug, { lib_path: data.libPath });

              const result = await checker.installPy(missing, manifest.index_urls || [], python, chosenPath, (pkg, idx, total) => {
                this.emit('status', { phase: 'installing_packages', message: `Installing ${pkg}...`, detail: { index: idx, total } });
              });

              if (!result.success) {
                this.emit('status', { phase: 'install_error', message: result.error });
                rejectInstall(new Error(result.error));
              } else {
                resolveInstall();
              }
            });

            this.once('skip-install', () => resolveInstall());
          });
        } else {
          const result = await checker.installPy(missing, manifest.index_urls || [], python, libPath, (pkg, idx, total) => {
            this.emit('status', { phase: 'installing_packages', message: `Installing ${pkg}...`, detail: { index: idx, total } });
          });

          if (!result.success) {
            this.emit('status', { phase: 'install_error', message: result.error });
            throw new Error(result.error);
          }
        }
      }
    }

    // Port retry: find an available port starting from the requested one
    const actualPort = await findAvailablePort(port, 10, (attempted, next) => {
      console.log(`Port ${attempted} is in use, trying ${next}...`);
      this.emit('status', { phase: 'port_conflict', message: `Port ${attempted} in use, trying ${next}...`, attempted, next });
    });

    return new Promise((resolve, reject) => {
      // shiny run uses --app-dir for the directory and app:app as the module reference
      // See: https://shiny.posit.co/py/api/core/run_app.html
      const args = [
        '-m', 'shiny',
        'run',
        '--host', '127.0.0.1',
        '--port', String(actualPort),
        '--app-dir', appPath,
        '--no-dev-mode',
        'app:app'
      ];

      console.log(`Starting Python Shiny server on port ${actualPort}...`);
      console.log(`Python command: ${python}`);
      console.log(`App path: ${appPath}`);
      this.emit('status', { phase: 'starting_server', message: 'Starting Python Shiny server...', port: actualPort });

      const checker3 = require('./dependency-checker');
      const finalPyLibPath = checker3.resolveLibPath(config?.app_slug || 'default', config, checker3.readPreferences(config?.app_slug || 'default'));

      const spawnEnv = { ...process.env };
      const pythonPaths = [];

      // Add bundled site-packages if present
      const bundledSitePackages = path.join(startBasePath, 'runtime', 'Python', 'lib', 'python', 'site-packages');
      if (fs.existsSync(bundledSitePackages)) {
        pythonPaths.push(bundledSitePackages);
      }
      // Also search for version-specific site-packages (e.g., lib/python3.12/site-packages)
      const bundledLib = path.join(startBasePath, 'runtime', 'Python', 'lib');
      if (fs.existsSync(bundledLib)) {
        try {
          for (const d of fs.readdirSync(bundledLib)) {
            if (d.startsWith('python')) {
              const sp = path.join(bundledLib, d, 'site-packages');
              if (fs.existsSync(sp)) pythonPaths.push(sp);
            }
          }
        } catch { /* ignore */ }
      }

      // Add user lib path if configured
      if (finalPyLibPath) {
        pythonPaths.push(finalPyLibPath);
      }

      if (pythonPaths.length > 0) {
        const existing = spawnEnv.PYTHONPATH || '';
        spawnEnv.PYTHONPATH = pythonPaths.join(path.delimiter) + (existing ? path.delimiter + existing : '');
      }

      this.pyProcess = spawn(python, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        env: spawnEnv
      });

      let stderr = '';

      this.pyProcess.stdout.on('data', (data) => {
        console.log(`[Python stdout] ${data.toString().trim()}`);
      });

      this.pyProcess.stderr.on('data', (data) => {
        const msg = data.toString().trim();
        stderr += msg + '\n';
        console.log(`[Python stderr] ${msg}`);

        // Surface Python's progress as lifecycle status updates
        if (/Uvicorn running on/.test(msg)) {
          this.emit('status', { phase: 'starting_server', message: 'Python server listening, loading app...' });
        } else if (/Application startup complete/.test(msg)) {
          this.emit('status', { phase: 'starting_server', message: 'Application startup complete, waiting for first response...' });
        } else if (/Waiting for application startup/.test(msg)) {
          this.emit('status', { phase: 'starting_server', message: 'Starting Shiny application...' });
        }
      });

      this.pyProcess.on('error', (err) => {
        this.pyProcess = null;
        const error = new Error(`Failed to start Python: ${err.message}\n\nIs Python installed and on your PATH?`);
        this.emit('error', error);
        reject(error);
      });

      this.pyProcess.on('close', (code) => {
        this.pyProcess = null;
        if (code !== null && code !== 0) {
          const msg = `Python process exited unexpectedly (code ${code})`;
          console.error(msg);
          console.error(`Python stderr output:\n${stderr}`);
          this.emit('status', {
            phase: 'server_crashed',
            message: msg,
            detail: { stderr, code }
          });
        }
      });

      waitForServer(actualPort, { timeout: 60000, interval: 500 })
        .then(() => {
          console.log(`Python Shiny server ready on http://localhost:${actualPort}`);
          this.emit('status', { phase: 'server_ready', message: 'Python Shiny server ready', port: actualPort });
          resolve({ port: actualPort });
        })
        .catch((err) => {
          this.stop();
          const error = new Error(
            `Python Shiny server failed to start within 60 seconds.\n\n` +
            `Python stderr output:\n${stderr}\n\n` +
            `Possible causes:\n` +
            `- Python is not installed or not on PATH\n` +
            `- The shiny package is not installed (run: pip install shiny)\n` +
            `- The app has errors that prevent it from starting\n` +
            `- Port ${actualPort} is already in use`
          );
          this.emit('error', error);
          reject(error);
        });
    });
  }

  /**
   * Stop the native Python Shiny server.
   */
  stop() {
    if (this.pyProcess) {
      console.log('Stopping Python Shiny server...');
      this.emit('status', { phase: 'stopping_server', message: 'Stopping Python Shiny server...' });
      killProcessTree(this.pyProcess);
      this.pyProcess = null;
    }
    this.emit('status', { phase: 'app_exit' });
  }
}

module.exports = new NativePyBackend();
