#!/bin/bash

#
# Llambo FFI Build Script
#
# This script handles the complete build process for the Inferno/Limbo FFI:
# 1. Builds the C module with llama.cpp bindings
# 2. Compiles Limbo modules (.m -> .dis)
# 3. Sets up Styx file server for distributed access
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFERNO_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$INFERNO_DIR")"
C_MODULE_DIR="$INFERNO_DIR/c-module"
LLAMA_CPP_DIR="$PROJECT_ROOT/llama.cpp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Inferno is available
check_inferno() {
    log_info "Checking Inferno environment..."
    
    if [ -z "$INFERNO_ROOT" ]; then
        log_warning "INFERNO_ROOT not set, checking common locations..."
        
        for path in /usr/inferno /opt/inferno ~/inferno; do
            if [ -d "$path" ]; then
                export INFERNO_ROOT="$path"
                log_success "Found Inferno at $INFERNO_ROOT"
                return 0
            fi
        done
        
        log_error "Inferno not found. Please install Inferno OS or set INFERNO_ROOT"
        return 1
    fi
    
    log_success "Inferno environment OK: $INFERNO_ROOT"
    return 0
}

# Build llama.cpp if needed
build_llama_cpp() {
    log_info "Checking llama.cpp build..."
    
    if [ ! -d "$LLAMA_CPP_DIR" ]; then
        log_error "llama.cpp not found at $LLAMA_CPP_DIR"
        log_info "Clone llama.cpp: git clone https://github.com/ggerganov/llama.cpp.git"
        return 1
    fi
    
    if [ ! -f "$LLAMA_CPP_DIR/build/src/libllama.a" ]; then
        log_warning "llama.cpp not built, building now..."
        
        cd "$LLAMA_CPP_DIR"
        mkdir -p build
        cd build
        cmake .. || return 1
        cmake --build . --config Release || return 1
        
        log_success "llama.cpp built successfully"
    else
        log_success "llama.cpp already built"
    fi
    
    cd "$SCRIPT_DIR"
    return 0
}

# Build C module
build_c_module() {
    log_info "Building C FFI module..."
    
    cd "$C_MODULE_DIR"
    
    # Check if we can use make
    if ! command -v make &> /dev/null; then
        log_error "make not found, please install build tools"
        return 1
    fi
    
    # Build
    make clean || true
    make all || {
        log_error "C module build failed"
        return 1
    }
    
    log_success "C module built: llambo_c.so"
    cd "$SCRIPT_DIR"
    return 0
}

# Compile Limbo modules
compile_limbo() {
    log_info "Compiling Limbo modules..."
    
    # Check for limbo compiler
    LIMBO_COMPILER=""
    
    if command -v limbo &> /dev/null; then
        LIMBO_COMPILER="limbo"
    elif [ -f "$INFERNO_ROOT/bin/limbo" ]; then
        LIMBO_COMPILER="$INFERNO_ROOT/bin/limbo"
    else
        log_warning "Limbo compiler not found in PATH or INFERNO_ROOT"
        log_warning "Skipping Limbo compilation (compile manually with: limbo -o llambo_styx.dis llambo_styx.b)"
        return 0
    fi
    
    cd "$INFERNO_DIR"
    
    # Compile llambo_styx
    if [ -f "llambo_styx.b" ]; then
        log_info "Compiling llambo_styx.b..."
        $LIMBO_COMPILER -o llambo_styx.dis llambo_styx.b || {
            log_warning "Failed to compile llambo_styx.b (non-fatal)"
        }
    fi
    
    log_success "Limbo modules compiled"
    cd "$SCRIPT_DIR"
    return 0
}

# Install C module
install_c_module() {
    log_info "Installing C module..."
    
    cd "$C_MODULE_DIR"
    
    if [ -d "$INFERNO_ROOT" ]; then
        make install || {
            log_warning "Installation to Inferno failed, copying to local lib/"
            mkdir -p "$INFERNO_DIR/lib"
            cp llambo_c.so "$INFERNO_DIR/lib/"
        }
    else
        log_warning "Inferno not found, copying to local lib/"
        mkdir -p "$INFERNO_DIR/lib"
        cp llambo_c.so "$INFERNO_DIR/lib/"
    fi
    
    log_success "C module installed"
    cd "$SCRIPT_DIR"
    return 0
}

# Generate documentation
generate_docs() {
    log_info "Generating FFI documentation..."
    
    cat > "$INFERNO_DIR/FFI-USAGE.md" << 'EOF'
# Llambo FFI Usage Guide

## Overview

The Llambo FFI (Foreign Function Interface) provides native C bindings to llama.cpp
for high-performance LLM inference in Inferno OS.

## Architecture

```
Limbo Application
       ↓
llambo_c.m (FFI Module Declaration)
       ↓
llambo_c.so (C Shared Library)
       ↓
llama.cpp (C++ Inference Engine)
```

## Using the FFI Module Directly

### Loading the Module

```limbo
implement Example;

include "sys.m";
    sys: Sys;

include "llambo_c.m";
    llambo_c: Llambo_c;

init(nil: ref Draw->Context, nil: list of string)
{
    sys = load Sys Sys->PATH;
    llambo_c = load Llambo_c Llambo_c->PATH;
    
    # Load a model
    model_id := llambo_c->load_model("/models/llama-7b.gguf", 1, 0);
    if (model_id < 0) {
        sys->print("Failed to load model\n");
        return;
    }
    
    # Run inference
    result := llambo_c->infer(model_id, "Hello, world!", 128, 0.8);
    sys->print("Result: %s\n", result);
    
    # Clean up
    llambo_c->free_model(model_id);
}
```

## Using the Styx File Server

The Styx wrapper provides distributed access to the C library across Dis VM boundaries.

### Starting the Server

```bash
# Mount the llambo file server
mount {llambo_styx} /n/llambo
```

### File Hierarchy

```
/n/llambo/
    ctl         - Control file for model management
    clone       - Clone file to create new model instances
    models/     - Directory of loaded models
        0/
            data    - Inference data file
            info    - Model information
            status  - Model status
```

### Using the File Interface

```bash
# Load a model
echo "load /models/llama-7b.gguf 1 0" > /n/llambo/ctl

# Run inference
echo "Hello, world!|128|0.8" > /n/llambo/models/0/data
cat /n/llambo/models/0/data

# Get model info
cat /n/llambo/models/0/info

# Free model
echo "free 0" > /n/llambo/ctl
```

## FFI Function Reference

### load_model(path, use_mmap, n_gpu_layers)

Loads a llama.cpp model from file.

- `path`: Full path to model file (.gguf format)
- `use_mmap`: 1 to use memory mapping, 0 otherwise
- `n_gpu_layers`: Number of layers to offload to GPU (0 for CPU only)
- Returns: model_id >= 0 on success, -1 on failure

### free_model(model_id)

Frees a loaded model.

- `model_id`: ID of the model to free
- Returns: 0 on success, -1 on failure

### tokenize(model_id, text)

Tokenizes input text.

- `model_id`: ID of the loaded model
- `text`: Input text to tokenize
- Returns: Array of token IDs, nil on failure

### infer(model_id, prompt, max_tokens, temperature)

Performs inference with llama.cpp.

- `model_id`: ID of the loaded model
- `prompt`: Input prompt text
- `max_tokens`: Maximum number of tokens to generate
- `temperature`: Sampling temperature (0.0 = deterministic)
- Returns: Generated text string

### get_model_info(model_id)

Gets model information.

- `model_id`: ID of the loaded model
- Returns: JSON string with model information

## Distributed Usage

The Styx protocol allows the FFI to be accessed across Dis VM boundaries:

```limbo
# VM 1: Start file server
mount {llambo_styx} /n/llambo

# VM 2: Access remotely
mount -A tcp!server!9999 /n/llambo
echo "Hello from VM 2!|128|0.8" > /n/llambo/models/0/data
cat /n/llambo/models/0/data
```

## Performance Considerations

1. **Model Loading**: Use `use_mmap=1` for faster loading with memory mapping
2. **GPU Offloading**: Set `n_gpu_layers > 0` if CUDA is available
3. **Batch Size**: Larger contexts use more memory but can be faster
4. **Temperature**: Lower values (0.1-0.3) for focused output, higher (0.8-1.0) for creative

## Troubleshooting

### Module Not Found

- Ensure `llambo_c.so` is in `$INFERNO_ROOT/libinterp/` or `./lib/`
- Check `INFERNO_ROOT` environment variable

### Model Loading Fails

- Verify model path is correct
- Ensure model format is .gguf (llama.cpp compatible)
- Check available memory for model size

### Inference Errors

- Verify model is loaded (model_id >= 0)
- Check max_tokens is reasonable (< context size)
- Monitor memory usage for large contexts

## Building from Source

See BUILD-FFI.md for detailed build instructions.

EOF

    log_success "Documentation generated: FFI-USAGE.md"
}

# Main build workflow
main() {
    log_info "Starting Llambo FFI build process..."
    echo ""
    
    # Step 1: Check Inferno
    if ! check_inferno; then
        log_warning "Inferno not found, continuing with limited functionality"
    fi
    echo ""
    
    # Step 2: Build llama.cpp
    if ! build_llama_cpp; then
        log_error "llama.cpp build failed"
        exit 1
    fi
    echo ""
    
    # Step 3: Build C module
    if ! build_c_module; then
        log_error "C module build failed"
        exit 1
    fi
    echo ""
    
    # Step 4: Compile Limbo modules
    compile_limbo
    echo ""
    
    # Step 5: Install C module
    install_c_module
    echo ""
    
    # Step 6: Generate documentation
    generate_docs
    echo ""
    
    log_success "FFI build complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Read FFI-USAGE.md for usage instructions"
    echo "  2. Set INFERNO_ROOT if not already set"
    echo "  3. Start the Styx server: mount {llambo_styx} /n/llambo"
    echo "  4. Test with: echo 'load /models/test.gguf 1 0' > /n/llambo/ctl"
}

# Parse command line arguments
case "${1:-build}" in
    build)
        main
        ;;
    check)
        check_inferno && build_llama_cpp
        ;;
    c-module)
        build_c_module
        ;;
    limbo)
        compile_limbo
        ;;
    install)
        install_c_module
        ;;
    docs)
        generate_docs
        ;;
    clean)
        log_info "Cleaning build artifacts..."
        cd "$C_MODULE_DIR"
        make clean
        log_success "Clean complete"
        ;;
    help)
        echo "Llambo FFI Build Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  build      - Full build (default)"
        echo "  check      - Check dependencies only"
        echo "  c-module   - Build C module only"
        echo "  limbo      - Compile Limbo modules only"
        echo "  install    - Install C module"
        echo "  docs       - Generate documentation"
        echo "  clean      - Clean build artifacts"
        echo "  help       - Show this help"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
