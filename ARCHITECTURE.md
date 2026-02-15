# Nodejs-Llama Architecture

This document explains the architecture of the Nodejs-Llama project, which provides two deployment modes: a desktop Electron application and a distributed Inferno OS cluster.

## Overview

This project integrates llama.cpp (a C++ implementation of LLM inference) in two distinct ways:

1. **Desktop Mode (Electron)**: A Node.js native addon providing a user-friendly desktop interface
2. **Distributed Mode (Inferno)**: A pure Limbo implementation optimized for distributed cognition across thousands of tiny inference engines

## Component Architecture

### 1. Electron Application

- **Main Process** (`src/main.js`): Manages the application lifecycle, creates browser windows, and handles IPC communication with the renderer process.
- **Renderer Process** (`src/index.html`, `src/renderer.js`): Provides the user interface for selecting models, entering prompts, and displaying results.
- **Preload Script** (`src/preload.js`): Exposes a secure bridge between the renderer and main processes.

### 2. Node.js Native Addon

- **Addon Entry Point** (`src/addon/llama_addon.cpp`): Provides a JavaScript interface to the llama.cpp library.
- **Async Worker** (`LlamaWorker` class): Runs the LLM inference in a separate thread to avoid blocking the Node.js event loop.

### 3. llama.cpp Integration

- **Library Integration**: The native addon directly links to the llama.cpp library.
- **Model Loading**: The addon loads model files using llama.cpp's API.
- **Inference**: Text processing happens through llama.cpp's context and evaluation functions.

## Data Flow

1. **User Input**:
   - User selects a model file through the UI
   - User enters a prompt in the text area
   - User clicks "Process Prompt"

2. **Processing**:
   - The renderer process sends the model path and prompt to the main process via IPC
   - The main process calls the Node.js addon with these parameters
   - The addon creates an async worker to handle the operation in a separate thread
   - The worker loads the model and processes the prompt using llama.cpp
   - The result is passed back to the main process, then to the renderer for display

## Threading Model

- **Electron Main Thread**: Handles application logic and communication
- **Renderer Thread**: Manages UI interactions
- **Node.js Thread**: Handles JavaScript execution
- **Worker Thread**: Processes LLM operations via the native addon

## Key Design Decisions

1. **Using Node.js Native Addon**: Direct C++ integration allows for efficient memory management and better performance compared to spawning separate processes.

2. **Asynchronous Processing**: LLM inference can be computationally intensive, so all processing happens asynchronously to avoid UI freezing.

3. **Context Isolation**: The renderer process has no direct access to Node.js APIs for security reasons. All communication happens through the contextBridge.

4. **Standalone Operation**: The application includes all necessary components to run inference locally without external dependencies.

## Compilation Process

1. **llama.cpp**: Built as a static library using CMake
2. **Node.js Addon**: Compiled using node-gyp with direct references to llama.cpp headers
3. **Electron Application**: Packaged using electron-builder

## Extensibility

The architecture allows for several extension points:

- **Additional LLM Features**: The addon can be extended to support more llama.cpp features like token-by-token generation or different evaluation modes.
- **Model Management**: The application could be extended with model downloading, updating, or conversion features.
- **UI Enhancements**: The Electron-based UI can be enhanced with advanced features like chat interfaces, prompt templates, etc.

---

## Distributed Mode Architecture (Inferno OS)

The distributed mode provides a completely different deployment model optimized for massive scalability and distributed cognition. See `inferno/README.md` for detailed documentation.

### Component Architecture (Distributed)

#### 1. Limbo Modules

- **`llambo.m`**: Module definition with ADT types for models, contexts, tokens, cluster nodes, load balancers, and orchestrators
- **`llambo.b`**: Implementation providing inference engine and distributed clustering logic
- **`llambotest.b`**: Test suite demonstrating single inference, distributed clusters, and massive parallel processing

#### 2. Distributed Cluster Components

- **ClusterNode**: Individual inference engine running in isolated Dis VM instance
  - Own compute resources and execution context
  - Independent model loading and processing
  - Status tracking (idle, busy, error)
  - Capacity and load management

- **LoadBalancer**: Distributes requests across cluster nodes
  - Multiple strategies: round-robin, least-loaded, random
  - Health monitoring and failover
  - Real-time load tracking

- **Orchestrator**: Manages cluster lifecycle
  - Spawns/shuts down thousands of nodes
  - Auto-scaling based on load
  - Aggregates cluster statistics
  - Coordinates distributed cognition

#### 3. Inferno VM Instances

- **Modular Isolates**: Each node runs in its own Dis VM with complete isolation
- **Namespace Isolation**: Separate namespaces per instance (`/n/llambo/worker-XXXX`)
- **Resource Allocation**: Configurable CPU, memory per instance (128MB - 8GB)
- **Communication Protocol**: Styx (9P) for inter-instance messaging

### Data Flow (Distributed)

1. **Cluster Initialization**:
   - Orchestrator spawns N worker nodes (configurable: 100-10,000+)
   - Each node loads model in isolated Dis VM instance
   - Nodes register with load balancer
   - Health monitoring begins

2. **Request Processing**:
   - Client submits prompt to orchestrator
   - Orchestrator delegates to load balancer
   - Load balancer selects optimal node based on strategy
   - Selected node processes inference
   - Result returned through orchestrator to client

3. **Distributed Cognition**:
   - Multiple nodes can process same request in parallel
   - Results aggregated via consensus or weighted average
   - Cognitive fusion produces coherent output
   - Collective intelligence from thousands of tiny engines

### Deployment Topology

```
Global Orchestrator
├── Load Balancer (strategy: least-loaded)
│   ├── ClusterNode-0001 (tiny: 128MB, 0.1 CPU, model: llama-1b)
│   ├── ClusterNode-0002 (tiny: 128MB, 0.1 CPU, model: llama-1b)
│   ├── ... (thousands more tiny nodes)
│   ├── ClusterNode-1001 (medium: 1GB, 1 CPU, model: llama-7b)
│   ├── ... (hundreds of medium nodes)
│   ├── ClusterNode-1101 (large: 8GB, 4 CPU, model: llama-13b)
│   └── ... (tens of large nodes)
└── Monitoring & Metrics
```

### Key Design Decisions (Distributed)

1. **Pure Limbo Implementation**: Native Inferno code for optimal VM performance and portability across Dis instances

2. **Modular Isolates**: Each inference engine in separate VM instance prevents interference and enables true parallel execution

3. **Lightweight Nodes**: Tiny engines (128MB) allow deployment of thousands on modest hardware, aggregating to massive capacity

4. **Styx Protocol**: Native Inferno communication protocol for efficient inter-instance messaging with minimal overhead

5. **Load Balancing**: Multiple strategies (round-robin, least-loaded, random) adapt to different workload patterns

6. **Auto-Scaling**: Dynamic node spawning/shutdown based on utilization thresholds

7. **Distributed Cognition**: Consensus algorithms and cognitive fusion enable collective intelligence from thousands of independent inference engines

### Scalability & Performance

- **Single Desktop (Electron)**: 1 model, ~10 tokens/sec, GB RAM required
- **Distributed Cluster (Inferno)**: 1000+ models, ~10,000 tokens/sec aggregate, scales horizontally

### Configuration

Cluster behavior controlled via `inferno/cluster-config.yaml`:
- Node types and counts
- Resource allocations
- Load balancing strategy
- Auto-scaling parameters  
- Network topology
- Model distribution
- Cognitive fusion settings

See `inferno/README.md` for complete configuration reference and deployment instructions. 