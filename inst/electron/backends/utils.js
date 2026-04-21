// Shared utilities for backend modules
const http = require('http');

/**
 * Debug logger gated by the SHINYELECTRON_DEBUG env var.
 * Set SHINYELECTRON_DEBUG=1 (or "true") to see diagnostic output in the
 * terminal where the packaged app was launched. Warnings and errors still
 * go straight to the console regardless of this flag.
 * @param  {...any} args - Arguments passed to console.log.
 */
const DEBUG_ENABLED = process.env.SHINYELECTRON_DEBUG === '1' ||
                      process.env.SHINYELECTRON_DEBUG === 'true';

function logDebug(...args) {
  if (DEBUG_ENABLED) console.log('[shinyelectron]', ...args);
}

/**
 * Wait for a server to be ready on localhost.
 * @param {number} port - Port to poll.
 * @param {object} options - Configuration.
 * @param {number} options.timeout - Max wait time in ms (default 30000).
 * @param {number} options.interval - Poll interval in ms (default 500).
 * @returns {Promise<void>} Resolves when server responds, rejects on timeout.
 */
function waitForServer(port, { timeout = 30000, interval = 500 } = {}) {
  return new Promise((resolve, reject) => {
    const start = Date.now();

    function check() {
      const req = http.get(`http://localhost:${port}`, (res) => {
        res.resume();
        resolve();
      });

      req.on('error', () => {
        if (Date.now() - start > timeout) {
          reject(new Error(`Server on port ${port} did not start within ${timeout}ms`));
        } else {
          setTimeout(check, interval);
        }
      });

      req.setTimeout(1000, () => {
        req.destroy();
        if (Date.now() - start > timeout) {
          reject(new Error(`Server on port ${port} did not start within ${timeout}ms`));
        } else {
          setTimeout(check, interval);
        }
      });
    }

    check();
  });
}

/**
 * Check if a TCP port is available on localhost.
 * @param {number} port - Port to check.
 * @returns {Promise<boolean>} True if available.
 */
function isPortAvailable(port) {
  return new Promise((resolve) => {
    const net = require('net');
    const server = net.createServer();
    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close(() => resolve(true));
    });
    server.listen(port, '127.0.0.1');
  });
}

/**
 * Find an available port starting from the given port.
 * @param {number} startPort - Port to start searching from.
 * @param {number} maxRetries - Maximum number of ports to try.
 * @param {function} onConflict - Optional callback: (attempted, next) => void
 * @returns {Promise<number>} An available port.
 */
async function findAvailablePort(startPort, maxRetries = 10, onConflict) {
  // First try the requested port
  if (await isPortAvailable(startPort)) return startPort;
  if (onConflict) onConflict(startPort, startPort + 1);

  // If taken, ask the OS for a random available port (avoids collisions
  // when multiple shinyelectron apps are running simultaneously)
  const net = require('net');
  const randomPort = await new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, '127.0.0.1', () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
    srv.on('error', reject);
  });
  if (onConflict) onConflict(startPort, randomPort);
  return randomPort;
}

/**
 * Check if the machine has internet connectivity.
 * @returns {Promise<boolean>} True if online.
 */
function isOnline() {
  return new Promise((resolve) => {
    const https = require('https');
    const req = https.get('https://cloud.r-project.org', { timeout: 5000 }, (res) => {
      res.resume();
      resolve(true);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
  });
}

/**
 * Kill a child process and its tree.
 * On Windows: taskkill /pid N /f /t
 * On Unix: SIGTERM, then SIGKILL after 500ms if still alive.
 * @param {object} proc - child_process instance with .pid
 */
function killProcessTree(proc) {
  if (!proc || !proc.pid) return;
  try {
    if (process.platform === 'win32') {
      const { execFileSync } = require('child_process');
      execFileSync('taskkill', ['/pid', String(proc.pid), '/f', '/t'], { stdio: 'ignore' });
    } else {
      proc.kill('SIGTERM');
      setTimeout(() => {
        try { process.kill(proc.pid, 'SIGKILL'); } catch { /* already dead */ }
      }, 500);
    }
  } catch (err) {
    console.error('Error killing process:', err.message);
  }
}

/**
 * Sort runtime candidates by version descending (latest first).
 * Versions are compared numerically component-by-component; non-numeric
 * parts and unknown versions (e.g. "0.0.0") sort last.
 * @param {Array<{version: string, path: string}>} candidates
 * @returns {Array<{version: string, path: string}>} sorted in place
 */
function sortCandidatesByVersion(candidates) {
  candidates.sort((a, b) => {
    const pa = a.version.split('.').map(Number);
    const pb = b.version.split('.').map(Number);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      const diff = (pb[i] || 0) - (pa[i] || 0);
      if (diff !== 0) return diff;
    }
    return 0;
  });
  return candidates;
}

/**
 * Log scanned runtime candidates and emit a status event on `emitter`.
 * If multiple candidates are found, the caller may offer a version picker
 * (the detail.versions payload supports that flow).
 * @param {EventEmitter} emitter - Backend instance emitting status events.
 * @param {string} label - Runtime label ("R" or "Python").
 * @param {Array<{version: string, path: string}>} candidates - Sorted candidates.
 */
function reportRuntimeCandidates(emitter, label, candidates) {
  if (!candidates || candidates.length === 0) return;
  if (candidates.length > 1) {
    logDebug(`Found ${candidates.length} ${label} installations:`);
    candidates.forEach(c => logDebug(`  ${label} ${c.version}: ${c.path}`));
    logDebug(`Using latest: ${label} ${candidates[0].version}`);
    emitter.emit('status', {
      phase: 'runtime_found',
      message: `Found ${candidates.length} ${label} installations, using ${label} ${candidates[0].version}`,
      detail: { versions: candidates.map(c => ({ version: c.version, path: c.path })) }
    });
  } else {
    logDebug(`Found ${label} installation: ${candidates[0].path}`);
  }
}

// Current manifest schema version. Bump in lockstep with
// R/constants.R::MANIFEST_SCHEMA_VERSION. Older apps built against an
// older R version may ship older manifests — we warn rather than crash.
const MANIFEST_SCHEMA_VERSION = '1';

/**
 * Validate a parsed manifest object has the expected schema version.
 * Emits a console warning on mismatch but never throws — graceful
 * degradation is preferable to a crash on user machines.
 * @param {object} manifest - Parsed JSON manifest from R.
 * @param {string} label - e.g. "dependencies", "runtime", "apps".
 */
function checkManifestSchema(manifest, label) {
  if (!manifest || typeof manifest !== 'object') return;
  const v = manifest.schema_version;
  if (!v) {
    console.warn(`[shinyelectron] ${label} manifest has no schema_version; built with an older shinyelectron (expected v${MANIFEST_SCHEMA_VERSION})`);
    return;
  }
  if (v !== MANIFEST_SCHEMA_VERSION) {
    console.warn(`[shinyelectron] ${label} manifest schema version mismatch: got v${v}, expected v${MANIFEST_SCHEMA_VERSION}. Some features may not work correctly.`);
  }
}

module.exports = {
  waitForServer,
  isPortAvailable,
  findAvailablePort,
  isOnline,
  killProcessTree,
  sortCandidatesByVersion,
  reportRuntimeCandidates,
  MANIFEST_SCHEMA_VERSION,
  checkManifestSchema,
  logDebug
};
