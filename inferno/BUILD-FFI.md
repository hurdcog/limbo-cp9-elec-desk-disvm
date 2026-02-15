# Building Inferno/Limbo FFI for llama.cpp

This document describes how to build and integrate the FFI (Foreign Function Interface) that allows Limbo programs to call llama.cpp C functions directly.

## Architecture Overview

The FFI implementation consists of several layers:

```
┌─────────────────────────────────────────────────────────┐
│ Limbo Application (llambo.b, limbot.b, etc.)          │
├─────────────────────────────────────────────────────────┤
│ Limbo Module Declaration (llambo_c.m)                  │
│ - Function signatures                                   │
│ - Type declarations                                     │
├─────────────────────────────────────────────────────────┤
│ Styx File Server (llambo_styx.b) - OPTIONAL           │
│ - Cross-VM access via 9P protocol                      │
│ - Distributed C library access                         │
├─────────────────────────────────────────────────────────┤
│ C Module (llambo_c.c)                                  │
│ - Inferno builtin module interface                     │
│ - Conversion between Limbo and C types                 │
├─────────────────────────────────────────────────────────┤
│ llama.cpp C++ Library                                  │
│ - Core LLM inference engine                            │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Inferno OS Development Environment**
   - Inferno OS installed (or emulator)
   - Inferno headers and libraries
   - Limbo compiler (limbo)

2. **C/C++ Build Tools**
   - GCC or Clang compiler
   - CMake (version 3.14+)
   - Make
   - Standard C++ development libraries

3. **llama.cpp Library**
   - Built llama.cpp library (libllama.a or libllama.so)
   - llama.cpp headers

## Build Process

### 1. Build llama.cpp

First, build the llama.cpp library:

```bash
cd /path/to/limbo-cp9-elec-desk-disvm
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
mkdir build
cd build
cmake ..
cmake --build . --config Release
```

This creates `build/src/libllama.a` (or `.so` on Linux).

### 2. Build FFI C Module

Navigate to the FFI build directory and compile:

```bash
cd /path/to/limbo-cp9-elec-desk-disvm/inferno/c-module

# Option 1: Use Makefile
make all

# Option 2: Manual compilation
gcc -O2 -Wall -fPIC \
    -I$INFERNO_ROOT/include \
    -I../../llama.cpp \
    -c llambo_c.c -o llambo_c.o

gcc -shared \
    -o llambo_c.so \
    llambo_c.o \
    -L../../llama.cpp/build/src \
    -lllama -lm -lstdc++ -lpthread
```

This creates `llambo_c.so`, the shared library containing the FFI bindings.

### 3. Install C Module

Install the compiled module to Inferno:

```bash
# Option 1: Use Makefile
make install

# Option 2: Manual installation
cp llambo_c.so $INFERNO_ROOT/libinterp/

# Option 3: Local installation (for testing)
mkdir -p ../lib
cp llambo_c.so ../lib/
```

### 4. Compile Limbo Modules

Compile the Limbo files that use the FFI:

```bash
cd /path/to/limbo-cp9-elec-desk-disvm/inferno

# Compile Styx server (optional, for distributed access)
limbo -o llambo_styx.dis llambo_styx.b

# The main llambo.b module will automatically use FFI when available
limbo -o llambo.dis llambo.b
```

### 5. Automated Build

Use the provided build script for automated setup:

```bash
cd /path/to/limbo-cp9-elec-desk-disvm/inferno

# Full build
./build-ffi.sh build

# Just check dependencies
./build-ffi.sh check

# Build only C module
./build-ffi.sh c-module

# Build only Limbo modules
./build-ffi.sh limbo
```

## Integration Approaches

There are two ways to integrate the C module with Inferno:

### Approach 1: Builtin Module (Recommended for Production)

Compile the C module directly into the Inferno kernel/VM. This requires:

1. **Copy module source to Inferno tree:**
   ```bash
   cp inferno/c-module/llambo_c.c $INFERNO_ROOT/libinterp/
   cp inferno/c-module/llambo_c.h $INFERNO_ROOT/libinterp/
   ```

2. **Update `$INFERNO_ROOT/libinterp/mkfile`:**
   Add `llambo_c.$O` to the OFILES list.

3. **Update `$INFERNO_ROOT/module/runt.m`:**
   Add the module declaration.

4. **Register module initialization:**
   In `$INFERNO_ROOT/libinterp/runt.c`, call `llambo_cmodinit()` during startup.

5. **Rebuild Inferno:**
   ```bash
   cd $INFERNO_ROOT
   mk clean
   mk install
   ```

This approach integrates the FFI as a first-class module in Inferno.

### Approach 2: Dynamic Loading (Development/Testing)

Load the module as a shared library at runtime. This is simpler but less portable:

1. **Place shared library in module path:**
   ```bash
   cp llambo_c.so /lib/
   # or
   export LD_LIBRARY_PATH=/path/to/inferno/lib:$LD_LIBRARY_PATH
   ```

2. **Load dynamically from Limbo:**
   ```limbo
   llambo_c := load Llambo_c "$Llambo_c";
   ```

The module loader will find and load `llambo_c.so`.

## Styx Protocol Wrapper

For distributed access across Dis VM boundaries:

### Setup

1. **Start the Styx file server:**
   ```bash
   mount {llambo_styx} /n/llambo
   ```

2. **Access from any Dis VM:**
   ```bash
   # Local access
   echo "load /models/llama-7b.gguf 1 0" > /n/llambo/ctl
   
   # Remote access (from another machine/VM)
   mount -A tcp!server!9999 /n/llambo
   ```

### File Interface

The Styx server exposes:

- `/n/llambo/ctl` - Control file (load/free models)
- `/n/llambo/clone` - Clone file (get new model ID)
- `/n/llambo/models/N/data` - Inference data (write prompt, read result)
- `/n/llambo/models/N/info` - Model information (JSON)
- `/n/llambo/models/N/status` - Model status

## Testing the FFI

### Test C Module

```bash
cd inferno/c-module
make test-compile
```

### Test from Limbo

Create a test file `test_ffi.b`:

```limbo
implement TestFFI;

include "sys.m";
    sys: Sys;

include "llambo_c.m";
    llambo_c: Llambo_c;

TestFFI: module
{
    init: fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
    sys = load Sys Sys->PATH;
    llambo_c = load Llambo_c Llambo_c->PATH;
    
    if (llambo_c == nil) {
        sys->print("Failed to load FFI module\n");
        return;
    }
    
    sys->print("FFI module loaded successfully\n");
    
    # Test model loading
    model_id := llambo_c->load_model("/models/test.gguf", 1, 0);
    if (model_id >= 0) {
        sys->print("Model loaded: id=%d\n", model_id);
        
        # Test inference
        result := llambo_c->infer(model_id, "Hello", 10, 0.8);
        sys->print("Result: %s\n", result);
        
        # Cleanup
        llambo_c->free_model(model_id);
    } else {
        sys->print("Model load failed\n");
    }
}
```

Compile and run:

```bash
limbo -o test_ffi.dis test_ffi.b
/dis/test_ffi.dis
```

## Configuration

### Environment Variables

- `INFERNO_ROOT` - Path to Inferno installation (e.g., `/usr/inferno`)
- `LD_LIBRARY_PATH` - Include path to `llambo_c.so` for dynamic loading

### Model Paths

Models should be in `.gguf` format (llama.cpp compatible):

- `/models/` - Default model directory
- Can be any accessible path on the file system

### Performance Tuning

In `llambo_c.c`, adjust:

```c
ctx_params.n_ctx = 2048;    // Context size
ctx_params.n_batch = 512;   // Batch size
ctx_params.n_threads = 4;   // CPU threads
```

## Troubleshooting

### "Module not found" Error

**Problem:** `load Llambo_c` returns nil.

**Solutions:**
1. Verify `llambo_c.so` is in `$INFERNO_ROOT/libinterp/` or module path
2. Check file permissions (should be readable/executable)
3. Verify shared library dependencies: `ldd llambo_c.so`

### "Undefined symbol" Errors

**Problem:** Loading fails with symbol errors.

**Solutions:**
1. Ensure llama.cpp is built correctly
2. Link with all required libraries: `-lllama -lm -lstdc++ -lpthread`
3. Check ABI compatibility between C compiler and Inferno

### Model Loading Fails

**Problem:** `load_model()` returns -1.

**Solutions:**
1. Verify model file path is correct
2. Ensure model format is `.gguf` (not older formats)
3. Check available memory (models can be GB in size)
4. Verify llama.cpp version compatibility

### Inference Produces No Output

**Problem:** `infer()` returns empty string.

**Solutions:**
1. Check model is loaded successfully (model_id >= 0)
2. Verify max_tokens is reasonable (> 0, < context size)
3. Check temperature value (typically 0.1 - 1.0)
4. Monitor memory usage

### Styx Server Won't Start

**Problem:** `mount {llambo_styx}` fails.

**Solutions:**
1. Ensure Limbo module is compiled: `llambo_styx.dis` exists
2. Check FFI module is loaded: `llambo_c.so` available
3. Verify mount point doesn't already exist
4. Check Inferno namespace permissions

## Advanced Topics

### Custom Sampling

Modify the sampling logic in `llambo_c.c`:

```c
// Replace greedy sampling with temperature-based sampling
// (requires implementing softmax and random sampling)
```

### Streaming Responses

For token-by-token streaming:

1. Modify `llama_infer()` to use a callback mechanism
2. Pass callback to Limbo via channel or file
3. Update Styx interface to support streaming reads

### Multi-Model Support

The implementation supports up to 32 concurrent models.
Adjust `MAXMODELS` in `llambo_styx.b` if needed.

### GPU Acceleration

Enable GPU offloading:

```limbo
model_id := llambo_c->load_model(path, 1, 32);  # 32 layers on GPU
```

Requires llama.cpp built with CUDA support.

## References

- [Inferno OS Documentation](https://inferno-os.org/)
- [Limbo Programming Language](https://inferno-os.org/inferno/papers/limbo.html)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [Styx Protocol Specification](http://doc.cat-v.org/inferno/4th_edition/styx)

## Support

For issues specific to this FFI implementation, see:
- `FFI-USAGE.md` - Usage guide
- `llambo_c.c` - Source code with comments
- `inferno/README.md` - General Inferno documentation
