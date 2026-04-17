// Shared utilities for backend modules
const http = require('http');

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

module.exports = { waitForServer, isPortAvailable, findAvailablePort, isOnline, killProcessTree };
