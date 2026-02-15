// DOM Elements
const modelPathInput = document.getElementById('model-path');
const selectModelBtn = document.getElementById('select-model-btn');
const promptInput = document.getElementById('prompt-input');
const processBtn = document.getElementById('process-btn');
const resultText = document.getElementById('result-text');
const loadingIndicator = document.getElementById('loading-indicator');
const statusDisplay = document.getElementById('status');
const modelInfo = document.getElementById('model-info');

// State
let isProcessing = false;
let logUpdateInterval = null;

// Event Listeners
selectModelBtn.addEventListener('click', async () => {
  try {
    updateStatus('Selecting model...');
    const modelPath = await window.llamaAPI.selectModel();
    
    if (modelPath) {
      modelPathInput.value = modelPath;
      
      // Extract filename for display
      const pathParts = modelPath.split(/[/\\]/);
      const filename = pathParts[pathParts.length - 1];
      
      modelInfo.textContent = `Selected model: ${filename}`;
      processBtn.disabled = !promptInput.value.trim();
      
      updateStatus('Model selected successfully');
    } else {
      updateStatus('Model selection cancelled');
    }
  } catch (error) {
    handleError('Error selecting model', error);
  }
});

promptInput.addEventListener('input', () => {
  processBtn.disabled = !modelPathInput.value || !promptInput.value.trim() || isProcessing;
});

processBtn.addEventListener('click', async () => {
  const modelPath = modelPathInput.value;
  const prompt = promptInput.value.trim();
  
  if (!modelPath || !prompt) {
    updateStatus('Please select a model and enter a prompt');
    return;
  }
  
  try {
    setProcessing(true);
    updateStatus('Processing prompt...');
    
    // Start polling the worker log to see progress
    startLogPolling();
    
    const result = await window.llamaAPI.processPrompt(modelPath, prompt);
    
    // Stop polling the log
    stopLogPolling();
    
    resultText.textContent = result;
    updateStatus('Prompt processed successfully');
  } catch (error) {
    stopLogPolling();
    resultText.textContent = `Error: ${error.message || 'Unknown error'}`;
    handleError('Failed to process prompt', error);
  } finally {
    setProcessing(false);
  }
});

// Helper Functions
function setProcessing(processing) {
  isProcessing = processing;
  processBtn.disabled = processing;
  selectModelBtn.disabled = processing;
  loadingIndicator.classList.toggle('hidden', !processing);
}

function updateStatus(message) {
  statusDisplay.textContent = message;
  console.log(message);
}

function handleError(message, error) {
  const errorMessage = error?.message || 'Unknown error';
  updateStatus(`${message}: ${errorMessage}`);
  console.error(message, error);
}

// Log polling functions
function startLogPolling() {
  // Clear any existing interval
  stopLogPolling();
  
  // Create a div to show the log
  if (!document.getElementById('worker-log')) {
    const logContainer = document.createElement('div');
    logContainer.id = 'worker-log';
    logContainer.className = 'worker-log';
    logContainer.innerHTML = '<h3>Worker Thread Log:</h3><pre id="log-content"></pre>';
    document.querySelector('.result-section').appendChild(logContainer);
  }
  
  // Start polling every second
  logUpdateInterval = setInterval(updateWorkerLog, 1000);
  updateWorkerLog(); // Do an initial update
}

function stopLogPolling() {
  if (logUpdateInterval) {
    clearInterval(logUpdateInterval);
    logUpdateInterval = null;
  }
}

async function updateWorkerLog() {
  try {
    const logContent = await window.llamaAPI.getWorkerLog();
    const logElement = document.getElementById('log-content');
    if (logElement) {
      logElement.textContent = logContent;
      logElement.scrollTop = logElement.scrollHeight; // Auto-scroll to bottom
    }
  } catch (error) {
    console.error('Error updating worker log:', error);
  }
}

// Initialize
loadingIndicator.classList.add('hidden'); // Ensure loading indicator is hidden on startup
updateStatus('Ready - Please select a model file'); 