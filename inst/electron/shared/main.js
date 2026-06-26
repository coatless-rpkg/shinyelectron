// EPIPE is expected when container log streaming is torn down at shutdown.
process.on('uncaughtException', (err) => {
  if (err && err.code === 'EPIPE') return;
  console.error('Uncaught exception:', err);
  try {
    if (logStream) {
      logStream.write(`[${new Date().toISOString()}] [ERROR] uncaughtException: ${(err && err.stack) || err}\n`);
    }
  } catch { /* logging is best-effort */ }
  // Surface genuine faults instead of silently continuing in a half-broken state.
  process.exit(1);
});

const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const backend = require('./backends/{{backend_module}}');

// File logging -- writes to configured log directory or app userData
const LOG_LEVEL = '{{log_level}}';
const LOG_LEVELS = { debug: 0, info: 1, warn: 2, error: 3 };
const LOG_THRESHOLD = LOG_LEVEL in LOG_LEVELS ? LOG_LEVELS[LOG_LEVEL] : 1;

const logDir = '{{log_dir}}' || path.join(app.getPath('userData'), 'logs');
let logStream = null;

function initLogging() {
  try {
    fs.mkdirSync(logDir, { recursive: true });
    const logFile = path.join(logDir, `app-${new Date().toISOString().slice(0, 10)}.log`);
    logStream = fs.createWriteStream(logFile, { flags: 'a' });
  } catch { /* logging is best-effort */ }
}

function log(level, ...args) {
  if ((LOG_LEVELS[level] || 0) < LOG_THRESHOLD) return;
  const msg = `[${new Date().toISOString()}] [${level.toUpperCase()}] ${args.join(' ')}`;
  if (logStream) logStream.write(msg + '\n');
  if (level === 'error') console.error(...args);
  else console.log(...args);
}

// For multi-app mode, backends are loaded dynamically
let currentBackend = backend;
let appsManifest = null;

// Check if this is a multi-app build
const manifestPath = path.join(__dirname, 'apps-manifest.json');
if (fs.existsSync(manifestPath)) {
  appsManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const { checkManifestSchema } = require('./backends/utils');
  checkManifestSchema(appsManifest, 'apps');
}

function getBackendForApp(appType, runtimeStrategy) {
  if (runtimeStrategy === 'shinylive') return require('./backends/shinylive');
  if (runtimeStrategy === 'container') return require('./backends/container');
  if (appType.startsWith('r-')) return require('./backends/native-r');
  return require('./backends/native-py');
}

{{#updates_enabled}}
const { autoUpdater } = require('electron-updater');
const updaterLog = require('electron-log');
{{/updates_enabled}}

let mainWindow;
let isShuttingDown = false;
let serverRunning = false;
let actualPort = null;
let lastSelectedAppId = null;

// Window state persistence -- remembers size and position between sessions
const windowStatePath = path.join(app.getPath('userData'), 'window-state.json');

function loadWindowState() {
  try {
    if (fs.existsSync(windowStatePath)) {
      return JSON.parse(fs.readFileSync(windowStatePath, 'utf8'));
    }
  } catch { /* ignore corrupt state file */ }
  return null;
}

function saveWindowState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  try {
    const bounds = mainWindow.getBounds();
    const isMaximized = mainWindow.isMaximized();
    fs.writeFile(windowStatePath, JSON.stringify({ bounds, isMaximized }), () => {});
  } catch { /* ignore write errors */ }
}

// resize/move fire continuously during a drag; debounce so we write once the
// interaction settles rather than synchronously on every frame.
let saveWindowStateTimer = null;
function scheduleSaveWindowState() {
  if (saveWindowStateTimer) clearTimeout(saveWindowStateTimer);
  saveWindowStateTimer = setTimeout(saveWindowState, 400);
}
{{#tray_enabled}}
let tray = null;
let trayMenu = null;
{{/tray_enabled}}

{{#tray_enabled}}
function createTray() {
  const iconPath = path.join(__dirname, 'assets', '{{#tray_icon}}{{tray_icon}}{{/tray_icon}}{{^tray_icon}}icon.png{{/tray_icon}}');

  let trayIcon;
  if (fs.existsSync(iconPath)) {
    trayIcon = nativeImage.createFromPath(iconPath);
    trayIcon = trayIcon.resize({ width: 16, height: 16 });
  } else {
    // Create a simple default icon if none exists
    trayIcon = nativeImage.createEmpty();
  }

  tray = new Tray(trayIcon);
  tray.setToolTip('{{tray_tooltip}}');

  trayMenu = Menu.buildFromTemplate([
    {
      label: 'Status: Starting...',
      enabled: false,
      id: 'status'
    },
    { type: 'separator' },
    {
      label: 'Show',
      click: () => {
        if (mainWindow) {
          mainWindow.show();
          mainWindow.focus();
        }
      }
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => {
        app.isQuitting = true;
        app.quit();
      }
    }
  ]);

  tray.setContextMenu(trayMenu);

  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
}
{{/tray_enabled}}

{{#menu_enabled}}
function createMenu() {
  const isMac = process.platform === 'darwin';

  {{#menu_minimal}}
  // Minimal menu -- File, Edit, Help only
  const template = [
    ...(isMac ? [{
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    }] : []),
    {
      label: 'File',
      submenu: [
        isMac ? { role: 'close' } : { role: 'quit' }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' }
      ]
    },
    {{#is_multi_app}}
    {
      label: 'Apps',
      submenu: [
        {
          label: 'Back to Launcher',
          accelerator: 'CmdOrCtrl+L',
          click: () => {
            if (currentBackend) {
              currentBackend.removeAllListeners();
              currentBackend.stop();
            }
            if (mainWindow) mainWindow.loadFile('launcher.html');
          }
        }
      ]
    },
    {{/is_multi_app}}
    {
      label: 'Help',
      submenu: [
        {{#help_url}}
        {
          label: 'Documentation',
          click: async () => {
            const { shell } = require('electron');
            await shell.openExternal('{{help_url}}');
          }
        },
        {{/help_url}}
        {
          label: 'View Logs',
          click: () => {
            const { shell } = require('electron');
            shell.openPath(logDir);
          }
        },
        { type: 'separator' },
        {
          label: 'About',
          click: () => {
            const { dialog } = require('electron');
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'About {{app_name}}',
              message: '{{app_name}}',
              detail: 'Version {{app_version}}\n\nBuilt with shinyelectron'
            });
          }
        }
      ]
    }
  ];
  {{/menu_minimal}}
  {{^menu_minimal}}
  // Default menu -- full menu bar
  const template = [
    ...(isMac ? [{
      label: app.name,
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    }] : []),
    {
      label: 'File',
      submenu: [
        isMac ? { role: 'close' } : { role: 'quit' }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' }
      ]
    },
    {
      label: 'View',
      submenu: [
        { role: 'reload' },
        { role: 'forceReload' },
        {{#show_dev_tools}}
        { role: 'toggleDevTools' },
        {{/show_dev_tools}}
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' }
      ]
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' },
        { role: 'zoom' },
        ...(isMac ? [
          { type: 'separator' },
          { role: 'front' }
        ] : [
          { role: 'close' }
        ])
      ]
    },
    {{#is_multi_app}}
    {
      label: 'Apps',
      submenu: [
        {
          label: 'Back to Launcher',
          accelerator: 'CmdOrCtrl+L',
          click: () => {
            if (currentBackend) {
              currentBackend.removeAllListeners();
              currentBackend.stop();
            }
            if (mainWindow) mainWindow.loadFile('launcher.html');
          }
        }
      ]
    },
    {{/is_multi_app}}
    {
      label: 'Help',
      submenu: [
        {{#help_url}}
        {
          label: 'Documentation',
          click: async () => {
            const { shell } = require('electron');
            await shell.openExternal('{{help_url}}');
          }
        },
        {{/help_url}}
        {
          label: 'View Logs',
          click: () => {
            const { shell } = require('electron');
            shell.openPath(logDir);
          }
        },
        { type: 'separator' },
        {
          label: 'About',
          click: () => {
            const { dialog } = require('electron');
            dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'About {{app_name}}',
              message: '{{app_name}}',
              detail: 'Version {{app_version}}\n\nBuilt with shinyelectron'
            });
          }
        }
      ]
    }
  ];
  {{/menu_minimal}}

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}
{{/menu_enabled}}

{{#updates_enabled}}
function setupAutoUpdater() {
  autoUpdater.logger = updaterLog;
  autoUpdater.logger.transports.file.level = 'info';

  autoUpdater.autoDownload = {{#auto_download}}true{{/auto_download}}{{^auto_download}}false{{/auto_download}};
  autoUpdater.autoInstallOnAppQuit = {{#auto_install}}true{{/auto_install}}{{^auto_install}}false{{/auto_install}};

  autoUpdater.on('checking-for-update', () => {
    updaterLog.info('Checking for updates...');
  });

  autoUpdater.on('update-available', (info) => {
    updaterLog.info('Update available:', info.version);
    // Show non-intrusive notification instead of modal
    const { Notification } = require('electron');
    if (Notification.isSupported()) {
      const notification = new Notification({
        title: 'Update Available',
        body: `Version ${info.version} is available. Click to download.`,
        silent: true
      });
      notification.on('click', () => {
        autoUpdater.downloadUpdate();
      });
      notification.show();
    } else {
      // Fallback to log
      updaterLog.info(`Update ${info.version} available; user will be notified on next check`);
    }
  });

  autoUpdater.on('update-not-available', () => {
    updaterLog.info('No updates available');
  });

  autoUpdater.on('download-progress', (progress) => {
    updaterLog.info(`Download progress: ${progress.percent}%`);
  });

  autoUpdater.on('update-downloaded', (info) => {
    updaterLog.info('Update downloaded');
    const { dialog } = require('electron');
    dialog.showMessageBox(mainWindow, {
      type: 'info',
      title: 'Update Ready',
      message: 'A new version has been downloaded. Restart now to apply the update?',
      buttons: ['Restart', 'Later'],
      defaultId: 0
    }).then((result) => {
      if (result.response === 0) {
        autoUpdater.quitAndInstall();
      }
    });
  });

  autoUpdater.on('error', (err) => {
    updaterLog.error('AutoUpdater error:', err);
  });
}
{{/updates_enabled}}

function createWindow() {
  // Restore saved window state or use defaults.
  // Only apply saved x/y when the saved bounds are visible on at least one
  // currently connected display; a disconnected monitor would otherwise hide
  // the window off-screen with no way for the user to recover it.
  const savedState = loadWindowState();
  const windowWidth = (savedState && savedState.bounds) ? savedState.bounds.width : {{window_width}};
  const windowHeight = (savedState && savedState.bounds) ? savedState.bounds.height : {{window_height}};

  let windowX = undefined;
  let windowY = undefined;
  if (savedState && savedState.bounds) {
    const { x, y, width, height } = savedState.bounds;
    try {
      const displays = screen.getAllDisplays();
      const visible = displays.some(d => {
        const wa = d.workArea;
        // Intersection test: both rectangles must overlap by at least 1px
        return x < wa.x + wa.width && x + width > wa.x &&
               y < wa.y + wa.height && y + height > wa.y;
      });
      if (visible) {
        windowX = x;
        windowY = y;
      }
      // If not visible on any display, leave windowX/windowY undefined so
      // Electron centers the window on the primary display.
    } catch {
      // screen API unavailable (should not happen after app.whenReady);
      // fall back to centered window.
    }
  }

  // Create the browser window
  mainWindow = new BrowserWindow({
    width: windowWidth,
    height: windowHeight,
    x: windowX,
    y: windowY,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      preload: path.join(__dirname, 'preload.js'),
      enableRemoteModule: false,
      webSecurity: true,
      // Isolate each app's session to prevent Service Worker cache
      // cross-contamination between multiple shinyelectron apps
      partition: 'persist:{{app_slug}}'
    },
    {{#has_icon}}icon: path.join(__dirname, 'assets', '{{icon_file}}'),{{/has_icon}}
    show: false
  });

  if (savedState && savedState.isMaximized) {
    mainWindow.maximize();
  }

  // Save window state on resize/move (debounced; these events fire rapidly)
  mainWindow.on('resize', scheduleSaveWindowState);
  mainWindow.on('move', scheduleSaveWindowState);
  mainWindow.on('close', saveWindowState);

  // Multi-app: load launcher instead of starting backend immediately
  if (appsManifest) {
    mainWindow.loadFile('launcher.html');
  } else {
  // Load lifecycle page
  mainWindow.loadFile('lifecycle.html');
  }

  // Start backend server
  const port = {{server_port}};

  // Resolve app path -- for native backends, files are unpacked from ASAR
  let appPath = path.join(__dirname, 'src', 'app');
  const unpackedPath = appPath.replace('app.asar', 'app.asar.unpacked');
  if (unpackedPath !== appPath && fs.existsSync(unpackedPath)) {
    appPath = unpackedPath;
  }

  if (!appsManifest) {
  // Forward backend status to lifecycle page
  backend.on('status', (data) => {
    log('info', `[lifecycle] ${data.phase}: ${data.message || ''}`);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('lifecycle-status', data);
    }

    // Track server running state
    if (data.phase === 'server_ready') serverRunning = true;
    if (data.phase === 'stopping_server' || data.phase === 'error' || data.phase === 'server_crashed') serverRunning = false;

    // Update tray status
    {{#tray_enabled}}
    if (tray) {
      let statusText = 'Starting...';
      if (data.phase === 'server_ready') statusText = 'Running';
      else if (data.phase === 'error' || data.phase === 'server_crashed') statusText = 'Error';
      else if (data.phase === 'shutting_down') statusText = 'Shutting down...';
      else if (data.phase === 'finding_runtime') statusText = 'Finding runtime...';
      else if (data.phase === 'installing_packages') statusText = 'Installing packages...';
      else if (data.phase === 'checking_packages') statusText = 'Checking packages...';

      tray.setToolTip('{{app_name}} - ' + statusText);
      // Also update the Status menu item label so the context menu reflects
      // the current state (guards against older Electron builds missing
      // getMenuItemById by wrapping in try/catch).
      try {
        if (trayMenu) {
          const statusItem = trayMenu.getMenuItemById('status');
          if (statusItem) {
            statusItem.label = 'Status: ' + statusText;
            tray.setContextMenu(trayMenu);
          }
        }
      } catch { /* menu update is best-effort */ }
    }
    {{/tray_enabled}}
  });

  // Defensive: an 'error' event with no listener throws in Node and would
  // crash the main process, so always keep one attached.
  backend.on('error', (err) => {
    log('error', 'Backend error event:', err && err.message ? err.message : err);
  });

  backend.start({
    appPath: appPath,
    port: port,
    config: {{{backend_config_json}}}
  }).then(({ port: p }) => {
    actualPort = p;
    log('info', 'Server ready on port', actualPort);
    mainWindow.loadURL(`http://localhost:${actualPort}`);
  }).catch((err) => {
    log('error', 'Backend start failed:', err.message);
  });
  } // end if (!appsManifest)

  // Launch (or re-launch) a selected multi-app sub-app. Shared by the
  // select_app and retry IPC actions so retry re-attempts the SAME app
  // rather than the single-app defaults.
  function startSelectedApp(appId) {
    // Stop current backend and purge all listeners (status, error,
    // install-packages, runtime-selected) to prevent dangling handlers
    if (currentBackend) {
      currentBackend.removeAllListeners();
      currentBackend.stop();
    }

    var selectedApp = appsManifest && appsManifest.apps.find(function(a) { return a.id === appId; });
    if (!selectedApp) return;

    // Load the correct backend for this app, preferring per-app
    // runtime_strategy when present (mixed-strategy suites).
    var appStrategy = selectedApp.runtime_strategy || appsManifest.runtime_strategy;
    var appType = selectedApp.type || appsManifest.default_type;
    currentBackend = getBackendForApp(appType, appStrategy);

    // Forward status to lifecycle.html and track running state (so multi-app
    // builds get the same quit-confirmation / shutdown UI as single-app).
    currentBackend.on('status', function(data) {
      log('info', '[lifecycle] ' + data.phase + ': ' + (data.message || ''));
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('lifecycle-status', data);
      }
      if (data.phase === 'server_ready') serverRunning = true;
      if (data.phase === 'stopping_server' || data.phase === 'error' || data.phase === 'server_crashed') serverRunning = false;
      // Update tray status for multi-app mode (mirrors the single-app handler)
      {{#tray_enabled}}
      if (tray) {
        var statusText = 'Starting...';
        if (data.phase === 'server_ready') statusText = 'Running';
        else if (data.phase === 'error' || data.phase === 'server_crashed') statusText = 'Error';
        else if (data.phase === 'shutting_down') statusText = 'Shutting down...';
        else if (data.phase === 'finding_runtime') statusText = 'Finding runtime...';
        else if (data.phase === 'installing_packages') statusText = 'Installing packages...';
        else if (data.phase === 'checking_packages') statusText = 'Checking packages...';
        tray.setToolTip((selectedApp.name || '{{app_name}}') + ' - ' + statusText);
        try {
          if (trayMenu) {
            var statusItem = trayMenu.getMenuItemById('status');
            if (statusItem) {
              statusItem.label = 'Status: ' + statusText;
              tray.setContextMenu(trayMenu);
            }
          }
        } catch { /* menu update is best-effort */ }
      }
      {{/tray_enabled}}
    });
    // Defensive: never let an 'error' event with no listener crash the process.
    currentBackend.on('error', function(err) {
      log('error', 'Backend error event:', err && err.message ? err.message : err);
    });

    // Show lifecycle page during startup
    mainWindow.loadFile('lifecycle.html');

    // Resolve the app path (ASAR-aware)
    var selectedAppPath = path.join(__dirname, selectedApp.path);
    var unpackedAppPath = selectedAppPath.replace('app.asar', 'app.asar.unpacked');
    if (unpackedAppPath !== selectedAppPath && fs.existsSync(unpackedAppPath)) {
      selectedAppPath = unpackedAppPath;
    }

    // Start the backend
    // app_slug stays as the suite-level slug (for shared venv/runtime);
    // app_id identifies the sub-app (for per-app prefs/caching).
    currentBackend.start({
      appPath: selectedAppPath,
      port: port,
      config: Object.assign({}, {{{backend_config_json}}}, {
        app_type: appType,
        app_id: selectedApp.id
      })
    }).then(function(result) {
      actualPort = result.port;
      mainWindow.loadURL('http://localhost:' + actualPort);
    }).catch(function(err) {
      log('error', 'Backend start failed:', err.message);
    });
  }

  // Handle IPC actions from lifecycle.html and launcher.html (retry, quit, select_app, etc.)
  // Wrapped in try/catch: a backend emit or getBackendForApp throwing
  // should not crash the Electron main process silently.
  ipcMain.on('lifecycle-action', (_event, action) => {
    try {
    var actionType = typeof action === 'string' ? action : action.type;

    if (actionType === 'retry') {
      if (appsManifest) {
        // Multi-app: re-attempt the last selected app, or return to launcher.
        if (lastSelectedAppId) {
          startSelectedApp(lastSelectedAppId);
        } else {
          mainWindow.loadFile('launcher.html');
        }
      } else {
        mainWindow.loadFile('lifecycle.html');
        backend.start({ appPath, port, config: {{{backend_config_json}}} }).then(({ port: p }) => {
          actualPort = p;
          mainWindow.loadURL(`http://localhost:${actualPort}`);
        }).catch((err) => {
          log('error', 'Backend retry failed:', err.message);
        });
      }
    } else if (actionType === 'quit') {
      app.quit();
    } else if (actionType === 'install') {
      (currentBackend || backend).emit('install-packages', {
        libPath: action.libPath || 'system'
      });
    } else if (actionType === 'skip_install') {
      (currentBackend || backend).emit('skip-install');
    } else if (actionType === 'select_runtime') {
      (currentBackend || backend).emit('runtime-selected', { runtimePath: action.runtimePath });
    } else if (actionType === 'select_app') {
      lastSelectedAppId = action.appId;
      startSelectedApp(action.appId);

    } else if (actionType === 'back_to_launcher') {
      if (currentBackend) {
        currentBackend.removeAllListeners();
        currentBackend.stop();
      }
      mainWindow.loadFile('launcher.html');
    }
    } catch (err) {
      log('error', 'IPC action failed:', err && err.message ? err.message : err);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('lifecycle-status', {
          phase: 'error',
          message: 'Internal error handling action: ' + (err && err.message ? err.message : 'unknown')
        });
      }
    }
  });

  {{#menu_enabled}}
  createMenu();
  {{/menu_enabled}}
  {{^menu_enabled}}
  // Hide menu bar when menus are disabled
  mainWindow.setMenuBarVisibility(false);
  {{/menu_enabled}}

  // Clear Service Worker cache to prevent shinylive apps from serving
  // stale content when multiple apps share the same localhost origin
  mainWindow.webContents.session.clearStorageData({
    storages: ['serviceworkers', 'cachestorage']
  }).catch(() => {});

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    if (process.env.ELECTRON_DEV_TOOLS === 'true') {
      mainWindow.webContents.openDevTools();
    }
  });

  {{#tray_enabled}}
  {{#minimize_to_tray}}
  // Minimize to tray instead of taskbar
  mainWindow.on('minimize', (event) => {
    event.preventDefault();
    mainWindow.hide();
  });
  {{/minimize_to_tray}}
  {{/tray_enabled}}

  // Shutdown flow
  mainWindow.on('close', (event) => {
    {{#tray_enabled}}
    {{#close_to_tray}}
    if (!app.isQuitting && !isShuttingDown) {
      event.preventDefault();
      mainWindow.hide();
      return;
    }
    {{/close_to_tray}}
    {{/tray_enabled}}
    {{^tray_enabled}}
    if (!isShuttingDown && serverRunning) {
      event.preventDefault();
      const { dialog } = require('electron');
      const choice = dialog.showMessageBoxSync(mainWindow, {
        type: 'question',
        buttons: ['Quit', 'Cancel'],
        defaultId: 1,
        title: 'Close {{app_name}}',
        message: 'Are you sure you want to quit?'
      });

      if (choice === 0) {
        isShuttingDown = true;
        if (mainWindow && !mainWindow.isDestroyed()) {
          // Wait until the lifecycle page has loaded and subscribed, then show
          // the headline and START the backend teardown there, so the backend's
          // own status (stopping container, removing container, ...) reaches the
          // renderer and is shown as a breakdown under "Closing application...".
          mainWindow.webContents.once('did-finish-load', () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.send('lifecycle-status', {
                phase: 'shutting_down', message: 'Closing application...'
              });
            }
            if (currentBackend) {
              // Quit shortly after the backend reports teardown is complete;
              // the shutdown_timeout below is the hard fallback.
              const onExit = (d) => {
                if (d && d.phase === 'app_exit') {
                  currentBackend.removeListener('status', onExit);
                  setTimeout(() => app.quit(), 700);
                }
              };
              currentBackend.on('status', onExit);
              currentBackend.stop();
            }
          });
          mainWindow.loadFile('lifecycle.html');
        } else if (currentBackend) {
          currentBackend.stop();
        }
        setTimeout(() => app.quit(), {{shutdown_timeout}});
      }
      return;
    }
    {{/tray_enabled}}
    if (!isShuttingDown) {
      isShuttingDown = true;
      if (currentBackend) currentBackend.stop();
      // Don't preventDefault -- let the window close immediately
    }
  });

  // Handle window closed
  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// App event handlers
app.whenReady().then(() => {
  initLogging();
  log('info', 'App starting');
  log('info', 'Version: {{app_version}}');
  log('info', 'App type: {{app_type}}');
  log('info', 'Backend: {{backend_module}}');
  log('info', 'Platform:', process.platform, process.arch);
  log('info', 'Preferred port: {{server_port}}');
  createWindow();

  {{#tray_enabled}}
  createTray();
  {{/tray_enabled}}

  {{#updates_enabled}}
  setupAutoUpdater();
  {{#check_on_startup}}
  // Check for updates after app is ready
  setTimeout(() => {
    autoUpdater.checkForUpdatesAndNotify();
  }, 3000);
  {{/check_on_startup}}
  {{/updates_enabled}}

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (currentBackend) currentBackend.stop();
  // Always quit when window closes -- keeping a Shiny server running
  // in the background with no window doesn't make sense.
  // (Tray-enabled apps handle this differently via close-to-tray.)
  app.quit();
});

{{#tray_enabled}}
{{#close_to_tray}}
app.on('before-quit', () => {
  app.isQuitting = true;
});
{{/close_to_tray}}
{{/tray_enabled}}

app.on('before-quit', () => {
  if (currentBackend) currentBackend.stop();
});
