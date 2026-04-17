// Secure IPC bridge for lifecycle.html
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('lifecycle', {
  onStatus: (callback) => {
    ipcRenderer.on('lifecycle-status', (_event, data) => callback(data));
  },
  retry: () => ipcRenderer.send('lifecycle-action', { type: 'retry' }),
  quit: () => ipcRenderer.send('lifecycle-action', { type: 'quit' }),
  install: (data) => ipcRenderer.send('lifecycle-action', { type: 'install', ...data }),
  skipInstall: () => ipcRenderer.send('lifecycle-action', { type: 'skip_install' }),
  selectRuntime: (data) => ipcRenderer.send('lifecycle-action', { type: 'select_runtime', ...data }),
  selectApp: (appId) => ipcRenderer.send('lifecycle-action', { type: 'select_app', appId }),
  backToLauncher: () => ipcRenderer.send('lifecycle-action', { type: 'back_to_launcher' })
});
