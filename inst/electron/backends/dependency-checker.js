// Dependency checker — checks and installs missing R/Python packages at launch
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { checkManifestSchema } = require('./utils');

/**
 * Read the dependencies manifest from the app directory.
 * @param {string} appPath - Path to the app directory.
 * @returns {object|null} Parsed manifest or null if not found.
 */
function readManifest(appPath) {
  const manifestPath = path.join(appPath, 'dependencies.json');
  if (!fs.existsSync(manifestPath)) return null;
  try {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    checkManifestSchema(manifest, 'dependencies');
    return manifest;
  } catch (err) {
    console.warn('Failed to read dependencies.json:', err.message);
    return null;
  }
}

/**
 * Check which R packages are missing.
 * @param {string[]} packages - Package names to check.
 * @param {string} rscript - Path to Rscript executable.
 * @param {string|null} libPath - Library path to check (null = R default).
 * @returns {Promise<string[]>} List of missing package names.
 */
async function checkMissingR(packages, rscript, libPath) {
  if (packages.length === 0) return [];

  // Sanitize package names — strip anything that isn't alphanumeric, dot, or dash
  const pkgList = packages.map(p => `"${p.replace(/[^a-zA-Z0-9._-]/g, '')}"`).join(',');
  let rCode;
  if (libPath) {
    // Escape backslashes and double quotes in libPath to prevent R code injection
    const safeLibPath = libPath.replace(/\\/g, '/').replace(/"/g, '\\"');
    rCode = `cat(jsonlite::toJSON(setdiff(c(${pkgList}), rownames(installed.packages(lib.loc="${safeLibPath}")))))`;
  } else {
    rCode = `cat(jsonlite::toJSON(setdiff(c(${pkgList}), rownames(installed.packages()))))`;
  }

  try {
    const result = execFileSync(rscript, ['-e', rCode], {
      encoding: 'utf8',
      timeout: 30000,
      stdio: ['ignore', 'pipe', 'pipe']
    });
    const parsed = JSON.parse(result.trim());
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.warn('Failed to check R packages:', err.message);
    return packages;
  }
}

/**
 * Check which Python packages are missing.
 * @param {string[]} packages - Package names to check.
 * @param {string} python - Path to Python executable.
 * @returns {Promise<string[]>} List of missing package names.
 */
async function checkMissingPy(packages, python) {
  if (packages.length === 0) return [];

  // Use pip show to check installed packages (handles module-name mismatches
  // like opencv-python→cv2 and scikit-learn→sklearn, which importlib can't)
  const crypto = require('crypto');
  const tmpFile = path.join(os.tmpdir(), `shinyelectron-check-${crypto.randomBytes(8).toString('hex')}.py`);
  const pyScript = `import json, subprocess, sys
pkgs = ${JSON.stringify(packages)}
missing = []
for p in pkgs:
    result = subprocess.run(
        [sys.executable, '-m', 'pip', 'show', p],
        capture_output=True, timeout=10
    )
    if result.returncode != 0:
        missing.append(p)
print(json.dumps(missing))
`;
  fs.writeFileSync(tmpFile, pyScript);

  try {
    const result = execFileSync(python, [tmpFile], {
      encoding: 'utf8',
      timeout: 60000,
      stdio: ['ignore', 'pipe', 'pipe']
    });
    fs.unlinkSync(tmpFile);
    return JSON.parse(result.trim());
  } catch (err) {
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
    console.warn('Failed to check Python packages:', err.message);
    return packages;
  }
}

/**
 * Install missing R packages (binary only).
 * @param {string[]} packages - Packages to install.
 * @param {string[]} repos - CRAN-like repository URLs.
 * @param {string} rscript - Path to Rscript.
 * @param {string|null} libPath - Target library path (null = R default).
 * @param {function} onProgress - Callback: (packageName, index, total) => void
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function installR(packages, repos, rscript, libPath, onProgress) {
  return new Promise((resolve) => {
    // Sanitize repo URLs — only allow URL-safe characters
    const repoStr = repos.map(r => `"${r.replace(/"/g, '')}"`).join(',');
    // Escape backslashes and double quotes in libPath to prevent R code injection
    const libArg = libPath ? `, lib="${libPath.replace(/\\/g, '/').replace(/"/g, '\\"')}"` : '';

    // Create lib directory if needed
    if (libPath) {
      fs.mkdirSync(libPath, { recursive: true });
    }

    let completed = 0;
    const total = packages.length;

    function installNext() {
      if (completed >= total) {
        resolve({ success: true });
        return;
      }

      const pkg = packages[completed];
      if (onProgress) onProgress(pkg, completed, total);

      // Sanitize package name before interpolating into R code
      const safePkg = pkg.replace(/[^a-zA-Z0-9._-]/g, '');
      const rCode = `install.packages("${safePkg}", repos=c(${repoStr}), type="binary", quiet=TRUE, dependencies=TRUE${libArg})`;

      try {
        execFileSync(rscript, ['-e', rCode], {
          timeout: 300000,
          stdio: 'ignore'
        });
        completed++;
        installNext();
      } catch (err) {
        resolve({ success: false, error: `Failed to install ${pkg}: ${err.message}` });
      }
    }

    installNext();
  });
}

/**
 * Install missing Python packages (binary only).
 * @param {string[]} packages - Packages to install.
 * @param {string[]} indexUrls - PyPI index URLs.
 * @param {string} python - Path to Python.
 * @param {string|null} libPath - Target directory (null = default).
 * @param {function} onProgress - Callback: (packageName, index, total) => void
 * @returns {Promise<{success: boolean, error?: string}>}
 */
function installPy(packages, indexUrls, python, libPath, onProgress) {
  return new Promise((resolve) => {
    if (onProgress) onProgress(packages[0], 0, packages.length);

    // Install using the provided Python (which may be a venv Python
    // created by native-py.js, avoiding PEP 668 errors)
    const installCmd = python;
    const args = ['-m', 'pip', 'install', '--only-binary', ':all:'];
    if (indexUrls && indexUrls.length > 0) {
      args.push('-i', indexUrls[0]);
    }
    if (libPath) {
      fs.mkdirSync(libPath, { recursive: true });
      args.push('--target', libPath);
    }
    args.push(...packages);

    try {
      execFileSync(installCmd, args, {
        timeout: 600000,
        stdio: ['ignore', 'pipe', 'pipe']
      });
      resolve({ success: true });
    } catch (err) {
      const stderr = err.stderr ? err.stderr.toString().trim() : '';
      const detail = stderr || err.message;
      resolve({ success: false, error: `Failed to install packages: ${detail}` });
    }
  });
}

/**
 * Check Linux system dependencies from manifest.
 * @param {object} manifest - Dependencies manifest with system_deps field.
 * @returns {string[]} List of missing system packages.
 */
function checkSystemDeps(manifest) {
  if (process.platform !== 'linux') return [];
  if (!manifest.system_deps) return [];

  let depsToCheck = [];
  try {
    const osRelease = fs.readFileSync('/etc/os-release', 'utf8');
    if (/debian|ubuntu/i.test(osRelease)) {
      depsToCheck = manifest.system_deps.debian || [];
    } else if (/fedora|rhel|centos/i.test(osRelease)) {
      depsToCheck = manifest.system_deps.fedora || [];
    }
  } catch { return []; }

  if (depsToCheck.length === 0) return [];

  const missing = [];
  for (const dep of depsToCheck) {
    try {
      execFileSync('dpkg', ['-s', dep], { stdio: 'ignore' });
    } catch {
      try {
        execFileSync('rpm', ['-q', dep], { stdio: 'ignore' });
      } catch {
        missing.push(dep);
      }
    }
  }
  return missing;
}

// --- Preferences ---

const PREFS_BASE = path.join(os.homedir(), '.shinyelectron', 'apps');

/**
 * Read saved preferences for an app.
 * @param {string} appSlug - App slug identifier.
 * @returns {object|null} Preferences or null.
 */
function readPreferences(appSlug) {
  const prefsPath = path.join(PREFS_BASE, appSlug, 'preferences.json');
  if (!fs.existsSync(prefsPath)) return null;
  try {
    return JSON.parse(fs.readFileSync(prefsPath, 'utf8'));
  } catch { return null; }
}

/**
 * Save preferences for an app.
 * @param {string} appSlug - App slug identifier.
 * @param {object} prefs - Preferences to save.
 */
function savePreferences(appSlug, prefs) {
  const prefsDir = path.join(PREFS_BASE, appSlug);
  fs.mkdirSync(prefsDir, { recursive: true });
  fs.writeFileSync(path.join(prefsDir, 'preferences.json'), JSON.stringify(prefs, null, 2));
}

/**
 * Resolve the library path for package installation.
 * @param {string} appSlug - App slug.
 * @param {object} config - Backend config (may have lib_path).
 * @param {object|null} prefs - Saved preferences.
 * @returns {string|null} Resolved library path, or null for system default.
 */
function resolveLibPath(appSlug, config, prefs) {
  if (prefs && prefs.lib_path) {
    if (prefs.lib_path === 'app-local') {
      return path.join(os.homedir(), '.shinyelectron', 'libraries', appSlug);
    }
    if (prefs.lib_path !== 'system') {
      return prefs.lib_path;
    }
    return null;
  }

  if (config && config.lib_path) {
    if (config.lib_path === 'app-local') {
      return path.join(os.homedir(), '.shinyelectron', 'libraries', appSlug);
    }
    if (config.lib_path !== 'system' && config.lib_path !== null) {
      return config.lib_path;
    }
  }

  return null;
}

module.exports = {
  readManifest,
  checkMissingR,
  checkMissingPy,
  installR,
  installPy,
  checkSystemDeps,
  readPreferences,
  savePreferences,
  resolveLibPath
};
