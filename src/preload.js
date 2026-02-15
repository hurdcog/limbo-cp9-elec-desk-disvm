const { contextBridge, ipcRenderer } = require('electron');

// Expose APIs to the renderer process
contextBridge.exposeInMainWorld('llamaAPI', {
  processPrompt: (modelPath, prompt) => {
    return ipcRenderer.invoke('process-prompt', modelPath, prompt);
  },
  selectModel: () => {
    return ipcRenderer.invoke('select-model');
  },
  getWorkerLog: () => {
    return ipcRenderer.invoke('get-worker-log');
  }
}); 