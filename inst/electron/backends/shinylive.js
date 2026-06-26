// Shinylive backend -- serves static shinylive app with required CORS headers
const { EventEmitter } = require('events');
const express = require('express');
const serveStatic = require('serve-static');

class ShinyliveBackend extends EventEmitter {
  constructor() {
    super();
    this.server = null;
  }

  async start({ appPath, port, config }) {
    // Note: do NOT removeAllListeners() here; it would wipe the main process's
    // 'status'/'error' subscribers. This backend registers no one-shot
    // internal listeners, so there is nothing to clear.
    const { logDebug } = require('./utils');

    // shinylive::export() bundles the WebR/Pyodide runtime and the app's
    // package wasm into the app, so it runs fully offline. We intentionally do
    // NOT probe the network here: a bundled app must launch without internet.
    // (Only packages that export() could not bundle would be fetched by
    // WebR/Pyodide at runtime, which they surface inside the app themselves.)
    this.emit('status', { phase: 'starting_server', message: 'Starting server...' });

    return new Promise((resolve, reject) => {
      const app = express();

      app.use(serveStatic(appPath, {
        setHeaders: (res, filePath) => {
          res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
          res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
          res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
        }
      }));

      // Bind to port 0 so the OS assigns a guaranteed-unique port.
      // This prevents collisions when multiple shinylive apps run
      // simultaneously (findAvailablePort has TOCTOU race conditions).
      this.server = app.listen(0, '127.0.0.1', () => {
        const actualPort = this.server.address().port;
        logDebug(`Shinylive server running on http://127.0.0.1:${actualPort}`);
        this.emit('status', { phase: 'server_ready', message: 'Server ready' });
        resolve({ port: actualPort });
      });

      this.server.on('error', (err) => {
        this.emit('status', { phase: 'error', message: err.message, detail: { error: err } });
        reject(err);
      });
    });
  }

  stop() {
    this.emit('status', { phase: 'stopping_server', message: 'Stopping server...' });
    if (this.server) {
      this.server.close();
      this.server = null;
    }
    this.emit('status', { phase: 'app_exit' });
  }
}

module.exports = new ShinyliveBackend();
