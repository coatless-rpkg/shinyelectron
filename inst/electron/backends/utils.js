// Shared utilities for backend modules
const http = require('http');
const path = require('path');

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

// Default for lifecycle.startup_timeout. Keep in sync with
// SHINYELECTRON_DEFAULTS$lifecycle$startup_timeout in R/constants.R.
const DEFAULT_STARTUP_TIMEOUT_MS = 180000;

/**
 * How long a backend waits for its server to answer before reporting a
 * failed start: lifecycle.startup_timeout, passed in the backend config.
 * @param {object} config - Backend configuration.
 * @returns {number} Milliseconds.
 */
function startupTimeoutMs(config) {
  const ms = config && config.startup_timeout;
  return Number.isFinite(ms) && ms > 0 ? ms : DEFAULT_STARTUP_TIMEOUT_MS;
}

/**
 * Describe a duration for messages, e.g. 180000 -> "180 seconds".
 * @param {number} ms - Milliseconds.
 * @returns {string}
 */
function formatSeconds(ms) {
  const seconds = Math.round(ms / 100) / 10;
  return `${seconds} second${seconds === 1 ? '' : 's'}`;
}

// Path the readiness probe requests. Apps do not serve it, so Shiny answers
// with a quick 404 instead of running the app's UI function as it would for
// GET /; a UI that takes longer to render than one attempt could otherwise
// never count as ready. Any HTTP response means the server is up.
const READY_PROBE_PATH = '/__shinyelectron_ready__';

/**
 * Wait for a server to answer HTTP requests on 127.0.0.1. Every server this
 * waits for (native R and Python, and the container's port mapping) binds
 * 127.0.0.1, so the probe goes there rather than to whatever "localhost"
 * resolves to first, which can be ::1.
 * @param {number} port - Port to poll.
 * @param {object} options - Configuration.
 * @param {number} options.timeout - Max wait time in ms (default 30000).
 * @param {number} options.interval - Pause between attempts in ms (default 500).
 * @param {number} options.attemptTimeout - Cap on one attempt in ms
 *   (default 8000). Near the deadline an attempt gets the time left, or
 *   1000 ms if less remains.
 * @param {function} [options.isCancelled] - Checked before every attempt;
 *   once it returns true, polling stops and the promise rejects.
 * @returns {Promise<void>} Resolves when server responds, rejects on timeout
 *   or cancellation.
 */
function waitForServer(port, {
  timeout = 30000, interval = 500, attemptTimeout = 8000, isCancelled = null
} = {}) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    let finished = false;
    const finish = (settle, value) => {
      if (finished) return;
      finished = true;
      settle(value);
    };

    function check() {
      if (finished) return;
      if (isCancelled && isCancelled()) {
        finish(reject, new Error(`Stopped waiting for the server on port ${port}`));
        return;
      }
      const remaining = timeout - (Date.now() - start);
      if (remaining <= 0) {
        finish(reject, new Error(`Server on port ${port} did not start within ${timeout}ms`));
        return;
      }

      // However an attempt fails, exactly one retry is scheduled, so only one
      // attempt is ever in flight.
      let attemptTimer = null;
      let retried = false;
      const retry = () => {
        clearTimeout(attemptTimer);
        if (retried) return;
        retried = true;
        setTimeout(check, interval);
      };

      const req = http.get(
        { host: '127.0.0.1', port, path: READY_PROBE_PATH, agent: false },
        (res) => {
          clearTimeout(attemptTimer);
          res.resume();
          finish(resolve);
        }
      );
      req.on('error', retry);

      // Cap each attempt so a connection that never answers cannot stall
      // polling until the overall deadline. Destroying the request emits
      // 'error', which schedules the next attempt.
      attemptTimer = setTimeout(
        () => req.destroy(new Error('Readiness probe timed out')),
        Math.min(attemptTimeout, Math.max(1000, remaining))
      );
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
 * Find an available port.
 * Tries the requested port first; if taken, asks the OS for a random free
 * port (port 0).  This avoids collisions when multiple shinyelectron apps
 * run simultaneously without needing a manual retry loop.
 * @param {number} startPort - Preferred port.
 * @param {function} [onConflict] - Optional callback: (attempted, assigned) => void
 * @returns {Promise<number>} An available port.
 */
async function findAvailablePort(startPort, onConflict) {
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

// Processes killProcessTree() was already asked to kill. A second request is
// ignored rather than signalling the process again.
const killRequested = new WeakSet();

/**
 * Kill a child process and its tree. Only the first call for a given
 * process does anything.
 * On Windows: taskkill /pid N /f /t
 * On Unix: SIGTERM, then SIGKILL after 500ms if still alive.
 * @param {object} proc - child_process instance with .pid
 */
function killProcessTree(proc) {
  if (!proc || !proc.pid || killRequested.has(proc)) return;
  killRequested.add(proc);
  try {
    if (process.platform === 'win32') {
      const { execFileSync } = require('child_process');
      execFileSync('taskkill', ['/pid', String(proc.pid), '/f', '/t'], { stdio: 'ignore' });
    } else {
      proc.kill('SIGTERM');
      setTimeout(() => {
        // Skip the fallback once the process has exited: its PID may already
        // belong to another process.
        if (proc.exitCode !== null || proc.signalCode !== null) return;
        try { process.kill(proc.pid, 'SIGKILL'); } catch { /* already dead */ }
      }, 500);
    }
  } catch (err) {
    console.error('Error killing process:', err.message);
  }
}

/**
 * Whether a child process was spawned and has not exited yet.
 * @param {object} proc - child_process instance.
 * @returns {boolean}
 */
function isProcessRunning(proc) {
  return Boolean(proc && proc.pid && proc.exitCode === null && proc.signalCode === null);
}

/**
 * Wait for a child process to exit.
 * Listens for 'exit' rather than 'close': 'close' also waits for every
 * process that inherited the child's stdio, such as a helper the app started
 * in the background, so it can fire long after the child itself is gone.
 * @param {object} proc - child_process instance.
 * @returns {Promise<void>} Resolves once the process has exited; right away
 *   if it has already exited or never started.
 */
function waitForExit(proc) {
  if (!isProcessRunning(proc)) return Promise.resolve();
  return new Promise((resolve) => proc.once('exit', () => resolve()));
}

/**
 * Error for a backend start() that stop() or a newer start() superseded.
 * main.js ignores it: a superseded start has nothing left to show.
 * @returns {Error} Error with code 'START_SUPERSEDED'.
 */
function startSupersededError() {
  const err = new Error('Backend start was superseded by stop() or a newer start()');
  err.code = 'START_SUPERSEDED';
  return err;
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

/**
 * Compare two dotted numeric version strings (e.g. "4.6.0", "3.14").
 * Missing trailing components are treated as 0.
 * @param {string} a
 * @param {string} b
 * @returns {number} 1 if a > b, -1 if a < b, 0 if equal.
 */
function compareVersions(a, b) {
  const pa = String(a).split('.').map(Number);
  const pb = String(b).split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const diff = (pa[i] || 0) - (pb[i] || 0);
    if (diff !== 0) return diff > 0 ? 1 : -1;
  }
  return 0;
}

/**
 * Return true if `version` is greater than or equal to `minimum`.
 * Both are dotted numeric version strings.
 * @param {string} version
 * @param {string} minimum
 * @returns {boolean}
 */
function meetsMinimumVersion(version, minimum) {
  return compareVersions(version, minimum) >= 0;
}

// Current manifest schema version. Bump in lockstep with
// R/constants.R::MANIFEST_SCHEMA_VERSION. Older apps built against an
// older R version may ship older manifests -- we warn rather than crash.
const MANIFEST_SCHEMA_VERSION = '2';

/**
 * Validate a parsed manifest object has the expected schema version.
 * Emits a console warning on mismatch but never throws -- graceful
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

/**
 * Resolve the runtime-manifest.json path for an app, relative to its own app
 * directory. Works for both single-app (src/app) and multi-app
 * (src/apps/<id>) layouts because the manifest always sits inside appPath.
 * @param {string} appPath - Resolved (ASAR-aware) path to the app directory.
 * @returns {string} Path to that app's runtime-manifest.json.
 */
function resolveRuntimeManifestPath(appPath) {
  return path.join(appPath, 'runtime-manifest.json');
}

module.exports = {
  startupTimeoutMs,
  formatSeconds,
  waitForServer,
  isPortAvailable,
  findAvailablePort,
  isOnline,
  killProcessTree,
  isProcessRunning,
  waitForExit,
  startSupersededError,
  sortCandidatesByVersion,
  reportRuntimeCandidates,
  compareVersions,
  meetsMinimumVersion,
  MANIFEST_SCHEMA_VERSION,
  checkManifestSchema,
  resolveRuntimeManifestPath,
  logDebug
};
