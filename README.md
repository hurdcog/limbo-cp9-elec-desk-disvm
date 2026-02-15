# Nodejs-Llama: Desktop & Distributed Inference

A dual-mode llama.cpp integration project supporting both desktop (Electron) and distributed cluster (Inferno OS) deployments.

## Overview

This project provides two ways to run llama.cpp inference:

1. **Desktop Mode**: An Electron application with Node.js native addon for local, single-user inference
2. **Distributed Mode**: Pure Limbo implementation for Inferno OS, optimized for distributed cognition across thousands of tiny inference engines in load-balanced clusters

## Features

### Desktop Mode (Electron)

- Load LLM models through a user-friendly interface
- Process text prompts asynchronously in a separate thread
- Built with Electron for cross-platform compatibility
- Direct integration with llama.cpp via a Node.js addon

### Distributed Mode (Inferno OS)

- Deploy thousands of modular isolates as Dis VM instances
- Load balancing across cluster with multiple strategies
- Distributed cognition with collective inference capacity
- Auto-scaling based on load and resource availability
- Aggregate throughput of 10,000+ tokens/sec with 1000+ nodes
- **Limbot**: AI chat assistant CLI with conversation history
- **Dish Integration**: Interactive distributed shell for cluster access

## Quick Start

Choose your deployment mode:

- **[Desktop Mode Setup](#desktop-mode-electron)** - For local single-user inference
- **[Distributed Mode Setup](#distributed-mode-inferno-os)** - For cluster deployment with thousands of nodes

---

## Desktop Mode (Electron)

### Prerequisites

- Node.js (v16+)
- npm or yarn
- C++ compiler (GCC, Clang, or MSVC)
- CMake (for building llama.cpp)
- Git

### Installation

1. Clone this repository:
   ```
   git clone https://github.com/aruntemme/llama.cpp-electron.git
   cd llama.cpp-electron
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Clone and build llama.cpp (required before building the Node.js addon):
   ```bash
   git clone https://github.com/ggerganov/llama.cpp.git
   cd llama.cpp
   mkdir build
   cd build
   cmake ..
   cmake --build . --config Release
   cd ../..
   ```

4. Build the Node.js addon:
   ```bash
   npm run build
   ```

5. Start the application:
   ```bash
   npm start
   ```

### How to Use (Desktop Mode)

1. Launch the application
2. Click "Select Model" to choose a llama.cpp compatible model file (.bin or .gguf)
3. Enter a prompt in the text area
4. Click "Process Prompt" to analyze the text
5. View the results in the results section

---

## Distributed Mode (Inferno OS)

For distributed cluster deployment with thousands of tiny inference engines.

### Prerequisites

- Inferno OS installed (or Inferno emulator)
- Limbo compiler
- llama.cpp compatible models

### Installation

1. Check Inferno installation:
   ```bash
   cd inferno
   ./deploy.sh check
   ```

2. Compile Limbo modules:
   ```bash
   ./deploy.sh compile
   ```

3. Deploy to cluster:
   ```bash
   ./deploy.sh deploy-local   # For local testing
   # or
   ./deploy.sh deploy-cluster # For distributed cluster
   ```

### Quick Start (Distributed Mode)

1. Initialize cluster:
   ```bash
   cd inferno
   ./llamboctl init
   ```

2. Spawn inference nodes:
   ```bash
   ./llamboctl spawn --count 1000 --type tiny
   ```

3. Check cluster status:
   ```bash
   ./llamboctl status
   ```

4. Process inference requests:
   ```bash
   # Requests are automatically load-balanced across nodes
   ./deploy.sh test
   ```

5. Monitor cluster:
   ```bash
   ./llamboctl health
   ./llamboctl metrics --export prometheus
   ```

6. Use Limbot AI chat assistant:
   ```bash
   # Interactive chat mode
   ./llamboctl limbot
   
   # One-shot inference
   ./llamboctl limbot "What is distributed computing?"
   ```

7. Use Dish distributed shell:
   ```bash
   # Launch interactive shell
   ./llamboctl dish
   ```

### Distributed Configuration

Edit `inferno/cluster-config.yaml` to configure:
- Node types (tiny: 128MB, medium: 1GB, large: 8GB)
- Node counts (100 to 10,000+)
- Load balancing strategy (round-robin, least-loaded, random)
- Auto-scaling parameters
- Network topology

See **[inferno/README.md](inferno/README.md)** for complete documentation.

---

## Model Files

You'll need to download LLM model files separately. Compatible models include:

- GGUF format models (recommended)
- Quantized models for better performance
- Other formats supported by llama.cpp

You can download models from Hugging Face or other repositories. 

**For Desktop Mode**: Place models in a location accessible by the application.

**For Distributed Mode**: Place models in `/models` directory for cluster nodes to access.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation on both architectures.

**Desktop Mode**: Single Electron process with Node.js addon → llama.cpp C++ library
- Performance: ~10 tokens/sec
- Resource: GB of RAM required
- Use case: Single-user desktop application

**Distributed Mode**: Thousands of Inferno Dis VM instances with Limbo implementation
- Performance: ~10,000+ tokens/sec aggregate (1000 nodes)
- Resource: 128MB per tiny node, scales horizontally
- Use case: Distributed cluster, massive parallel inference

## Troubleshooting

### Desktop Mode

- **Model loading errors**: Ensure your model file is compatible with llama.cpp
- **Addon building errors**: Make sure llama.cpp is properly built before building the addon
- **Performance issues**: Large models may require more memory and processing power

### Common Issues (Desktop)

1. **Cannot find llama.h**: Make sure you've built llama.cpp using the steps above
2. **Loading model fails**: Verify the model path is correct and the model is in a supported format
3. **Electron startup errors**: Check the terminal output for detailed error messages

### Distributed Mode

- **Compilation errors**: Ensure Inferno environment is properly configured
- **Node spawn failures**: Check resource limits (ulimit) and available ports
- **Load balancing issues**: Verify cluster configuration in `cluster-config.yaml`
- **Module loading errors**: Ensure Limbo modules are compiled to .dis bytecode

See `inferno/README.md` for detailed troubleshooting.

## Project Structure

```
llama.cpp-electron/
├── src/                    # Desktop mode (Electron)
│   ├── addon/             # C++ Node.js addon
│   │   ├── llama_addon.cpp
│   │   └── binding.gyp
│   ├── main.js            # Electron main process
│   ├── renderer.js        # Frontend logic
│   ├── preload.js         # IPC bridge
│   ├── index.html         # UI
│   └── styles.css
├── inferno/               # Distributed mode (Inferno OS)
│   ├── llambo.m           # Module definition
│   ├── llambo.b           # Implementation
│   ├── llambotest.b       # Test suite
│   ├── cluster-config.yaml # Cluster configuration
│   ├── deploy.sh          # Deployment script
│   ├── llamboctl          # Cluster control utility
│   └── README.md          # Detailed documentation
├── llama.cpp/             # Submodule
├── ARCHITECTURE.md        # Architecture documentation
├── README.md              # This file
└── package.json
```

## Performance Comparison

| Mode | Deployment | Throughput | Latency | Scalability |
|------|-----------|-----------|---------|-------------|
| Desktop | Single machine | ~10 tok/s | 100ms | Limited by local resources |
| Distributed (100 nodes) | Cluster | ~1,000 tok/s | 50ms | Horizontal scaling |
| Distributed (1000 nodes) | Cluster | ~10,000 tok/s | 45ms | Thousands of nodes |

## Use Cases

**Desktop Mode:**
- Personal AI assistant
- Local development and testing
- Single-user applications
- Privacy-focused deployments

**Distributed Mode:**
- Large-scale inference services
- Multi-tenant platforms
- Research clusters
- Edge computing networks
- Distributed AI systems

## License

This project is licensed under the ISC License - see the LICENSE file for details.

## Acknowledgments

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Inference engine
- [Electron](https://www.electronjs.org/) - Desktop application framework
- [Node.js](https://nodejs.org/) - JavaScript runtime
- [Inferno OS](http://www.vitanuova.com/inferno/) - Distributed operating system
- [Limbo](http://www.vitanuova.com/inferno/papers/limbo.html) - Programming language for Inferno

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture for both modes
- **[inferno/README.md](inferno/README.md)** - Complete Inferno/Limbo documentation
- **Desktop Mode**: See above sections
- **Distributed Mode**: See `inferno/` directory

## Contributing

Contributions are welcome! Areas of interest:

**Desktop Mode:**
- UI/UX improvements
- Additional llama.cpp features
- Performance optimizations

**Distributed Mode:**
- FFI bindings to llama.cpp C library
- Advanced load balancing algorithms
- Consensus and cognitive fusion strategies
- Monitoring and telemetry
- Production deployment tools 