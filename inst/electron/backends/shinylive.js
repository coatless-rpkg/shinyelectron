// Shinylive backend — serves static shinylive app with required CORS headers
const { EventEmitter } = require('events');
const express = require('express');
const serveStatic = require('serve-static');

class ShinyliveBackend extends EventEmitter {
  constructor() {
    super();
    this.server = null;
  }

  async start({ appPath, port, config }) {
    this.removeAllListeners();
    const { isOnline } = require('./utils');

    this.emit('status', { phase: 'starting_server', message: 'Starting server...' });

    // Shinylive apps need to download WebR/Pyodide on first load (~30MB)
    // Warn if offline so users aren't stuck on a blank page
    const online = await isOnline();
    if (!online) {
      this.emit('status', {
        phase: 'error',
        message: 'No internet connection detected.\n\nShinylive apps need to download WebAssembly resources on first load. Please connect to the internet and try again.'
      });
      throw new Error('No internet connection — shinylive requires network access for first load');
    }

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
        console.log(`Shinylive server running on http://127.0.0.1:${actualPort}`);
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
