const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const express = require('express');
const serveStatic = require('serve-static');
const fs = require('fs');

let mainWindow;
let server;

function createWindow() {
  // Create the browser window
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      webSecurity: true
    },
    {{#has_icon}}icon: path.join(__dirname, 'assets', 'icon.png'),{{/has_icon}}
    show: false
  });

  // Load the shinylive app

  // Start local server for shinylive app
  const serverApp = express();
  const appPath = path.join(__dirname, 'src', 'app');

  serverApp.use(serveStatic(appPath, {
    setHeaders: (res, path) => {
      // Set CORS headers for shinylive
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      // Hashes are required for inline styles and module loads used by shinylive
      //res.setHeader('Content-Security-Policy', "default-src 'self' data: blob:; style-src 'self' sha256-+pCr5n6DcB3FeE1tada/DZh/T86yK3TcLBXwhYncDaI= sha256-vjfJ7oqqz0UNGMRfzy1Ys+FCp0IMfoBL6lGmP7TIO/M=");
    }
  }));

  const port = 3838;
  server = serverApp.listen(port, 'localhost', () => {
    console.log(`Shinylive server running on http://localhost:${port}`);
    mainWindow.loadURL(`http://localhost:${port}`);
  });

  // Hide menu bar
  mainWindow.setMenuBarVisibility(false);


  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();

    // Open DevTools in development
    if (process.env.ELECTRON_DEV_TOOLS === 'true') {
      mainWindow.webContents.openDevTools();
    }
  });

  // Handle window closed
  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// App event handlers
app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {

  if (server) {
    server.close();
  }

  if (process.platform !== 'darwin') {
    app.quit();
  }
});


app.on('before-quit', () => {
  if (server) {
    server.close();
  }
});
