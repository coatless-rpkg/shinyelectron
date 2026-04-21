// Native R Shiny backend — spawns Rscript child process running shiny::runApp()
const { EventEmitter } = require('events');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {
  waitForServer, findAvailablePort, killProcessTree,
  sortCandidatesByVersion, reportRuntimeCandidates
} = require('./utils');

class NativeRBackend extends EventEmitter {
  constructor() {
    super();
    this.rProcess = null;
  }

  /**
   * Scan common R installation directories and return the latest Rscript path.
   * @returns {string|null} Path to Rscript, or null if not found.
   */
  findRscriptInCommonLocations() {
    const candidates = [];

    if (process.platform === 'win32') {
      // Windows: R installs to Program Files\R\R-x.y.z\
      const searchDirs = [
        path.join(process.env.ProgramFiles || 'C:\\Program Files', 'R'),
        path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'R')
      ];

      for (const searchDir of searchDirs) {
        if (!fs.existsSync(searchDir)) continue;
        try {
          const entries = fs.readdirSync(searchDir).filter(d => d.startsWith('R-'));
          for (const entry of entries) {
            const rscriptPath = path.join(searchDir, entry, 'bin', 'Rscript.exe');
            if (fs.existsSync(rscriptPath)) {
              candidates.push({ version: entry.replace('R-', ''), path: rscriptPath });
            }
          }
        } catch { /* ignore permission errors */ }
      }
    } else if (process.platform === 'darwin') {
      // macOS: rig installs multiple versions to R.framework/Versions/x.y/
      const versionsDir = '/Library/Frameworks/R.framework/Versions';
      if (fs.existsSync(versionsDir)) {
        try {
          const entries = fs.readdirSync(versionsDir).filter(d => /^\d+\.\d+/.test(d));
          for (const entry of entries) {
            const rscriptPath = path.join(versionsDir, entry, 'Resources', 'bin', 'Rscript');
            if (fs.existsSync(rscriptPath)) {
              candidates.push({ version: entry, path: rscriptPath });
            }
          }
        } catch { /* ignore */ }
      }

      // Also check the Current symlink (CRAN default) and Homebrew
      const macPaths = [
        { path: '/Library/Frameworks/R.framework/Resources/bin/Rscript', version: '0.0.0' },
        { path: '/opt/homebrew/bin/Rscript', version: '0.0.0' },
        { path: '/usr/local/bin/Rscript', version: '0.0.0' }
      ];
      for (const entry of macPaths) {
        if (fs.existsSync(entry.path)) {
          // Avoid duplicates from rig scan
          if (!candidates.some(c => c.path === entry.path)) {
            candidates.push(entry);
          }
        }
      }
    } else {
      // Linux: package manager, source installs, rig
      const linuxPaths = [
        '/usr/bin/Rscript',
        '/usr/local/bin/Rscript'
      ];
      // rig/r-hub installs to /opt/R/x.y.z/bin/
      const optR = '/opt/R';
      if (fs.existsSync(optR)) {
        try {
          const entries = fs.readdirSync(optR).filter(d => /^\d+\.\d+/.test(d));
          for (const entry of entries) {
            const rscriptPath = path.join(optR, entry, 'bin', 'Rscript');
            if (fs.existsSync(rscriptPath)) {
              candidates.push({ version: entry, path: rscriptPath });
            }
          }
        } catch { /* ignore */ }
      }
      for (const p of linuxPaths) {
        if (fs.existsSync(p)) {
          candidates.push({ version: '0.0.0', path: p });
        }
      }
    }

    if (candidates.length === 0) return null;
    sortCandidatesByVersion(candidates);
    reportRuntimeCandidates(this, 'R', candidates);
    return candidates;
  }

  /**
   * Find the Rscript executable.
   * Priority: config.r_executable > cached auto-downloaded runtime > system PATH > common locations
   * @param {object} config - Backend configuration.
   * @returns {string} Path to Rscript executable.
   */
  findRscript(config) {
    this.emit('status', { phase: 'finding_runtime', message: 'Looking for R...' });

    // 1. Explicit path from config
    if (config && config.r_executable) {
      const result = config.r_executable;
      this.emit('status', { phase: 'runtime_found', message: `Found R: ${result}` });
      return result;
    }

    // 2. Check for bundled runtime embedded in the Electron app
    // Resolve ASAR-unpacked path (runtime files are extracted outside app.asar)
    let appBasePath = path.join(__dirname, '..');
    const unpackedBase = appBasePath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedBase !== appBasePath && fs.existsSync(unpackedBase)) {
      appBasePath = unpackedBase;
    }
    const runtimeDir = path.join(appBasePath, 'runtime', 'R');
    if (fs.existsSync(runtimeDir)) {
      // Search for Rscript in the bundled portable-r directory
      try {
        const entries = fs.readdirSync(runtimeDir);
        for (const entry of entries) {
          const subdir = path.join(runtimeDir, entry);
          if (!fs.statSync(subdir).isDirectory()) continue;
          // Check for portable-r-{version} subdirectory inside
          const subEntries = fs.readdirSync(subdir);
          for (const sub of subEntries) {
            if (sub.startsWith('portable-r-')) {
              const rscriptName = process.platform === 'win32' ? 'Rscript.exe' : 'Rscript';
              const candidate = path.join(subdir, sub, 'bin', rscriptName);
              if (fs.existsSync(candidate)) {
                console.log(`Found bundled R: ${candidate}`);
                this.emit('status', { phase: 'runtime_found', message: `Found bundled R: ${sub}` });
                return candidate;
              }
            }
          }
          // Also check flat layout: runtime/R/{version}/bin/Rscript
          const flatCandidate = path.join(subdir, 'bin', process.platform === 'win32' ? 'Rscript.exe' : 'Rscript');
          if (fs.existsSync(flatCandidate)) {
            console.log(`Found bundled R: ${flatCandidate}`);
            this.emit('status', { phase: 'runtime_found', message: `Found bundled R` });
            return flatCandidate;
          }
        }
      } catch (err) {
        console.warn('Error checking bundled runtime:', err.message);
      }
    }

    // 3. Check for auto-downloaded runtime via manifest
    if (config && config.runtime_strategy === 'auto-download') {
      try {
        const appBasePath = path.join(__dirname, '..');
        const manifestPath = path.join(appBasePath, 'src', 'app', 'runtime-manifest.json');
        if (fs.existsSync(manifestPath)) {
          const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
          const { findCachedRuntime } = require('./runtime-downloader');
          const cached = findCachedRuntime(manifest);
          if (cached) {
            this.emit('status', { phase: 'runtime_found', message: `Found R: ${cached}` });
            return cached;
          }
        }
      } catch (err) {
        console.warn('Failed to check cached runtime:', err.message);
      }
    }

    // 3. Try system PATH first
    const pathCmd = process.platform === 'win32' ? 'Rscript.exe' : 'Rscript';
    try {
      const { execFileSync } = require('child_process');
      execFileSync(pathCmd, ['--version'], { stdio: 'ignore' });
      this.emit('status', { phase: 'runtime_found', message: `Found R: ${pathCmd}` });
      return pathCmd; // Found on PATH
    } catch {
      // Not on PATH, try common locations
    }

    // 4. Scan common installation directories
    const candidates = this.findRscriptInCommonLocations();
    if (candidates && candidates.length > 0) {
      this.emit('status', { phase: 'runtime_found', message: `Found R: ${candidates[0].path}` });
      return candidates[0].path;
    }

    // 5. Last resort — return default and let it fail with a clear error
    this.emit('status', { phase: 'runtime_found', message: `Found R: ${pathCmd}` });
    return pathCmd;
  }

  /**
   * Start the native R Shiny server.
   * @param {object} options
   * @param {string} options.appPath - Path to the Shiny app directory.
   * @param {number} options.port - Port to listen on.
   * @param {object} options.config - Backend configuration.
   * @returns {Promise<{port: number}>} Resolves when the Shiny server is ready.
   */
  async start({ appPath, port, config }) {
    this.removeAllListeners();

    // Resolve ASAR-unpacked base path for runtime and library access
    let appBasePath = path.join(__dirname, '..');
    const unpackedStart = appBasePath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedStart !== appBasePath && fs.existsSync(unpackedStart)) {
      appBasePath = unpackedStart;
    }

    let rscript = this.findRscript(config || {});

    // For auto-download strategy, download runtime if not found on system
    if (config && config.runtime_strategy === 'auto-download') {
      try {
        const appBasePath = path.join(__dirname, '..');
        const manifestPath = path.join(appBasePath, 'src', 'app', 'runtime-manifest.json');
        if (fs.existsSync(manifestPath)) {
          const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
          const { findCachedRuntime, downloadRuntime } = require('./runtime-downloader');

          if (!findCachedRuntime(manifest)) {
            const { isOnline } = require('./utils');
            if (!await isOnline()) {
              this.emit('status', {
                phase: 'error',
                message: 'This app needs to download R on first launch but no internet connection was detected.\n\nPlease check your network connection and try again.'
              });
              throw new Error('No internet connection for runtime download');
            }
            console.log('R runtime not found, downloading...');
            this.emit('status', { phase: 'downloading_runtime', message: 'Downloading R runtime...' });
            rscript = await downloadRuntime(manifest, (msg, pct) => {
              console.log(`[Runtime] ${msg}`);
              this.emit('status', { phase: 'downloading_runtime', message: `[Runtime] ${msg}` });
            });
          }
        }
      } catch (err) {
        this.emit('status', { phase: 'error', message: `Failed to set up R runtime: ${err.message}`, detail: { stderr: err.message } });
        throw new Error(`Failed to set up R runtime: ${err.message}`);
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
        rscript = pickerPrefs.runtime_path;
        this.emit('status', { phase: 'runtime_found', message: `Using saved R: ${rscript}` });
      }
    } else if (promptVersion) {
      // Check if multiple versions were found
      const rCandidates = this.findRscriptInCommonLocations();
      if (rCandidates && rCandidates.length > 1) {
        this.emit('status', {
          phase: 'runtime_versions_found',
          message: `Found ${rCandidates.length} R installations`,
          detail: { versions: rCandidates }
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

        rscript = selectedPath;
        this.emit('status', { phase: 'runtime_found', message: `Selected R: ${rscript}` });
      }
    }

    // Check and install dependencies (skip for bundled — packages are baked in at build time)
    const checker = require('./dependency-checker');
    const manifest = checker.readManifest(appPath);
    const isBundled = fs.existsSync(path.join(appBasePath, 'runtime', 'R'));

    if (!isBundled && manifest && manifest.packages && manifest.packages.length > 0) {
      this.emit('status', { phase: 'checking_packages', message: 'Checking R packages...' });

      const appSlug = config?.app_slug || 'default';
      const prefs = checker.readPreferences(appSlug);
      let libPath = checker.resolveLibPath(appSlug, config, prefs);

      // Include bundled library if it exists
      const bundledLibCheck = path.join(appBasePath, 'runtime', 'R', 'library');
      const checkLibPath = fs.existsSync(bundledLibCheck) ? bundledLibCheck : libPath;

      const missing = await checker.checkMissingR(manifest.packages, rscript, checkLibPath);

      if (missing.length > 0) {
        const promptBeforeInstall = config?.prompt_before_install ?? false;
        const systemDeps = checker.checkSystemDeps(manifest);

        if (promptBeforeInstall && !prefs) {
          // Emit confirmation request and wait for user action via IPC
          this.emit('status', {
            phase: 'awaiting_install_confirmation',
            message: `${missing.length} packages need to be installed`,
            detail: { missing, all: manifest.packages, system_deps: systemDeps }
          });

          await new Promise((resolveInstall, rejectInstall) => {
            this.once('install-packages', async (data) => {
              const chosenPath = data.libPath === 'app-local'
                ? path.join(os.homedir(), '.shinyelectron', 'libraries', appSlug)
                : data.libPath === 'system' ? null : data.libPath;

              checker.savePreferences(appSlug, { lib_path: data.libPath });
              libPath = chosenPath;

              const result = await checker.installR(missing, manifest.repos || [], rscript, chosenPath, (pkg, idx, total) => {
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
          // Auto-install
          if (systemDeps.length > 0) {
            this.emit('status', { phase: 'checking_packages', message: `System libraries may be needed: ${systemDeps.join(', ')}` });
          }

          const result = await checker.installR(missing, manifest.repos || [], rscript, libPath, (pkg, idx, total) => {
            this.emit('status', { phase: 'installing_packages', message: `Installing ${pkg}...`, detail: { index: idx, total } });
          });

          if (!result.success) {
            this.emit('status', { phase: 'install_error', message: result.error });
            throw new Error(result.error);
          }
        }
      }
    }

    // Find an available port, retrying on conflicts
    const actualPort = await findAvailablePort(
      port,
      config?.port_retry_count || 10,
      (attempted, next) => {
        this.emit('status', { phase: 'port_conflict', message: `Port ${attempted} in use, trying ${next}...` });
      }
    );

    this.emit('status', { phase: 'starting_server', message: 'Starting R Shiny server...' });

    return new Promise((resolve, reject) => {
      // Resolve library path — check for bundled library first
      const bundledLib = path.join(appBasePath, 'runtime', 'R', 'library');
      const checker2 = require('./dependency-checker');
      const userLibPath = checker2.resolveLibPath(config?.app_slug || 'default', config, checker2.readPreferences(config?.app_slug || 'default'));

      // Build .libPaths() with bundled lib (if exists) and user lib (if set)
      // Escape paths to prevent R code injection via crafted directory names
      const libPaths = [];
      if (fs.existsSync(bundledLib)) libPaths.push(bundledLib.replace(/\\/g, '/').replace(/"/g, '\\"'));
      if (userLibPath) libPaths.push(userLibPath.replace(/\\/g, '/').replace(/"/g, '\\"'));

      const safeAppPath = appPath.replace(/\\/g, '/').replace(/'/g, "\\'").replace(/"/g, '\\"');

      let rCode;
      if (libPaths.length > 0) {
        const libPathsR = libPaths.map(p => `"${p}"`).join(', ');
        rCode = `.libPaths(c(${libPathsR}, .libPaths())); shiny::runApp('${safeAppPath}', port = ${actualPort}, host = '127.0.0.1', launch.browser = FALSE)`;
      } else {
        rCode = `shiny::runApp('${safeAppPath}', port = ${actualPort}, host = '127.0.0.1', launch.browser = FALSE)`;
      }

      console.log(`Starting R Shiny server on port ${actualPort}...`);
      console.log(`Rscript command: ${rscript}`);
      console.log(`App path: ${appPath}`);

      this.rProcess = spawn(rscript, ['-e', rCode], {
        stdio: ['ignore', 'pipe', 'pipe'],
        env: { ...process.env }
      });

      let stderr = '';

      this.rProcess.stdout.on('data', (data) => {
        console.log(`[R stdout] ${data.toString().trim()}`);
      });

      this.rProcess.stderr.on('data', (data) => {
        const msg = data.toString().trim();
        stderr += msg + '\n';
        console.log(`[R stderr] ${msg}`);

        // Surface R's progress as lifecycle status updates so the splash
        // screen shows what's happening instead of sitting frozen.
        if (/Listening on/.test(msg)) {
          this.emit('status', { phase: 'starting_server', message: 'R server listening, loading app...' });
        } else if (/Loading required package/.test(msg)) {
          const pkg = msg.replace(/.*Loading required package:\s*/, '');
          this.emit('status', { phase: 'starting_server', message: `Loading package: ${pkg}` });
        } else if (/Downloading.*font/i.test(msg)) {
          this.emit('status', { phase: 'starting_server', message: msg.trim() });
        } else if (/Attaching package/.test(msg)) {
          const pkg = msg.replace(/.*Attaching package:\s*/, '').replace(/['']/g, '');
          this.emit('status', { phase: 'starting_server', message: `Attaching: ${pkg}` });
        }
      });

      this.rProcess.on('error', (err) => {
        this.rProcess = null;
        reject(new Error(`Failed to start Rscript: ${err.message}\n\nIs R installed and Rscript on your PATH?`));
      });

      this.rProcess.on('close', (code) => {
        this.rProcess = null;
        if (code !== null && code !== 0) {
          const msg = `R process exited unexpectedly (code ${code})`;
          console.error(msg);
          console.error(`R stderr output:\n${stderr}`);
          this.emit('status', {
            phase: 'server_crashed',
            message: msg,
            detail: { stderr, code }
          });
        }
      });

      waitForServer(actualPort, { timeout: 60000, interval: 500 })
        .then(() => {
          console.log(`R Shiny server ready on http://localhost:${actualPort}`);
          this.emit('status', { phase: 'server_ready', message: 'R Shiny server ready' });
          resolve({ port: actualPort });
        })
        .catch((err) => {
          this.stop();
          this.emit('status', {
            phase: 'error',
            message: `R Shiny server failed to start within 60 seconds.`,
            detail: { stderr }
          });
          reject(new Error(
            `R Shiny server failed to start within 60 seconds.\n\n` +
            `R stderr output:\n${stderr}\n\n` +
            `Possible causes:\n` +
            `- Rscript is not installed or not on PATH\n` +
            `- The shiny package is not installed in R\n` +
            `- The app has errors that prevent it from starting\n` +
            `- Port ${actualPort} is already in use`
          ));
        });
    });
  }

  /**
   * Stop the native R Shiny server.
   */
  stop() {
    this.emit('status', { phase: 'stopping_server', message: 'Stopping R server...' });
    if (this.rProcess) {
      console.log('Stopping R Shiny server...');
      killProcessTree(this.rProcess);
      this.rProcess = null;
    }
    this.emit('status', { phase: 'app_exit' });
  }
}

module.exports = new NativeRBackend();
