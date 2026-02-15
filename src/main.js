const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

// Load the native addon
let llamaAddon;
try {
  llamaAddon = require('../src/addon/build/Release/llama_addon.node');
  console.log('[Main Process] Successfully loaded llama_addon native module');
} catch (err) {
  console.error('[Main Process] Failed to load llama_addon:', err);
  process.exit(1); // Exit if addon can't be loaded
}

let mainWindow;

function createWindow() {
  console.log('[Main Process] Creating main window');
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));
  console.log('[Main Process] Loaded HTML file');
  
  // Open DevTools 
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
    console.log('[Main Process] DevTools opened (development mode)');
  }
  
  // Log when window is ready
  mainWindow.webContents.on('did-finish-load', () => {
    console.log('[Main Process] Window fully loaded');
  });
}

app.whenReady().then(() => {
  console.log('[Main Process] Electron app ready');
  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) {
      console.log('[Main Process] App activated with no windows, creating window');
      createWindow();
    }
  });
});

app.on('window-all-closed', function () {
  console.log('[Main Process] All windows closed');
  if (process.platform !== 'darwin') {
    console.log('[Main Process] Quitting application (not macOS)');
    app.quit();
  }
});

// Handle prompt processing request from renderer
ipcMain.handle('process-prompt', async (event, modelPath, prompt) => {
  console.log(`[Main Process] Processing prompt request received:
  - Model path: ${modelPath}
  - Prompt: "${prompt.substring(0, 50)}${prompt.length > 50 ? '...' : ''}"`);
  
  try {
    // If modelPath is relative, make it absolute based on app resources
    if (!path.isAbsolute(modelPath)) {
      const absolutePath = path.join(app.getAppPath(), '..', 'models', modelPath);
      console.log(`[Main Process] Converting relative path to absolute: ${absolutePath}`);
      modelPath = absolutePath;
    }

    // Check if model file exists
    if (!fs.existsSync(modelPath)) {
      console.error(`[Main Process] Error: Model file not found at ${modelPath}`);
      throw new Error(`Model file not found: ${modelPath}`);
    }
    
    console.log(`[Main Process] Model file exists, sending to addon for processing`);

    // Use the native addon to process the prompt
    const result = await new Promise((resolve, reject) => {
      llamaAddon.processPrompt(modelPath, prompt, (err, result) => {
        if (err) {
          console.error('[Main Process] Addon processing error:', err);
          reject(err);
        } else {
          console.log('[Main Process] Addon processing completed successfully');
          resolve(result);
        }
      });
    });
    
    console.log('[Main Process] Processing completed, returning result to renderer');
    return result;
  } catch (error) {
    console.error('[Main Process] Error processing prompt:', error);
    throw error;
  }
});

// Handle worker log request from renderer
ipcMain.handle('get-worker-log', async (event) => {
  console.log('[Main Process] Worker log requested');
  
  try {
    const log = llamaAddon.getWorkerLog();
    console.log('[Main Process] Successfully retrieved worker log');
    return log;
  } catch (error) {
    console.error('[Main Process] Error retrieving worker log:', error);
    throw error;
  }
});

// Handle model selection dialog
ipcMain.handle('select-model', async () => {
  console.log('[Main Process] Select model dialog requested');
  
  try {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openFile'],
      filters: [
        { name: 'Models', extensions: ['bin', 'gguf'] }
      ]
    });
    
    if (!result.canceled && result.filePaths.length > 0) {
      console.log(`[Main Process] Model selected: ${result.filePaths[0]}`);
      return result.filePaths[0];
    }
    
    console.log('[Main Process] Model selection canceled');
    return null;
  } catch (error) {
    console.error('[Main Process] Error selecting model:', error);
    throw error;
  }
}); 