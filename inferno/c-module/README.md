# Llambo FFI C Module

This directory contains the C implementation of the Llambo FFI (Foreign Function Interface) that provides native bindings to llama.cpp for Inferno OS.

## Files

- `llambo_c.c` - Main C implementation with Inferno VM integration
- `llambo_c.h` - Header file with function declarations
- `Makefile` - Build system for compiling and installing the module
- `README.md` - This file

## Purpose

The FFI module allows Limbo programs to call llama.cpp functions directly from C,
enabling high-performance LLM inference without the overhead of inter-process
communication or reimplementation in pure Limbo.

## Features

- **Model Loading**: Load llama.cpp models (.gguf format)
- **Tokenization**: Convert text to/from token IDs
- **Inference**: Run LLM inference with temperature control
- **Model Management**: Support for multiple concurrent models (up to 32)
- **Memory Management**: Automatic cleanup and reference counting
- **Error Handling**: Graceful fallback on errors

## Building

### Quick Build

```bash
make all
```

### Prerequisites Check

```bash
make check-deps
```

### Installation

```bash
make install
```

This copies `llambo_c.so` to `$INFERNO_ROOT/libinterp/` (or `../lib/` if Inferno not found).

### Clean

```bash
make clean
```

## Usage from Limbo

### Loading the Module

```limbo
include "llambo_c.m";
    llambo_c: Llambo_c;

llambo_c = load Llambo_c Llambo_c->PATH;
if (llambo_c == nil) {
    sys->print("Failed to load FFI module\n");
    return;
}
```

### Loading a Model

```limbo
model_id := llambo_c->load_model("/models/llama-7b.gguf", 1, 0);
if (model_id < 0) {
    sys->print("Model load failed\n");
    return;
}
```

Parameters:
- `path`: Full path to model file
- `use_mmap`: 1 for memory mapping (faster), 0 for regular loading
- `n_gpu_layers`: Number of layers to offload to GPU (0 for CPU only)

### Running Inference

```limbo
result := llambo_c->infer(model_id, "Hello, world!", 128, 0.8);
sys->print("Generated: %s\n", result);
```

Parameters:
- `model_id`: ID from `load_model()`
- `prompt`: Input text
- `max_tokens`: Maximum tokens to generate
- `temperature`: Sampling temperature (0.0 = deterministic, 1.0 = creative)

### Tokenization

```limbo
tokens := llambo_c->tokenize(model_id, "Hello, world!");
if (tokens != nil) {
    sys->print("Tokens: %d\n", len tokens);
}
```

### Model Information

```limbo
info := llambo_c->get_model_info(model_id);
sys->print("Model info: %s\n", info);
```

Returns a JSON string with:
- `model_id`: Model identifier
- `path`: Model file path
- `n_vocab`: Vocabulary size
- `n_ctx`: Context size
- `ref_count`: Reference count

### Cleanup

```limbo
result := llambo_c->free_model(model_id);
if (result < 0) {
    sys->print("Free failed\n");
}
```

## Integration with Inferno

### As a Builtin Module (Production)

For production use, integrate as a builtin Inferno module:

1. Copy sources to Inferno tree:
   ```bash
   cp llambo_c.c $INFERNO_ROOT/libinterp/
   cp llambo_c.h $INFERNO_ROOT/libinterp/
   ```

2. Update `$INFERNO_ROOT/libinterp/mkfile`:
   ```makefile
   OFILES=\
       ...existing files...\
       llambo_c.$O\
   ```

3. Register module in `$INFERNO_ROOT/libinterp/runt.c`:
   ```c
   extern void llambo_cmodinit(void);
   
   void
   modinit(void)
   {
       ...existing inits...
       llambo_cmodinit();
   }
   ```

4. Rebuild Inferno:
   ```bash
   cd $INFERNO_ROOT
   mk clean && mk install
   ```

### As a Shared Library (Development)

For development and testing, use dynamic loading:

1. Build shared library: `make all`
2. Install to module path: `make install`
3. Load from Limbo: `load Llambo_c "$Llambo_c"`

## Implementation Details

### Memory Management

- Models are tracked in a static array (max 32 concurrent)
- Reference counting prevents premature cleanup
- Automatic cleanup on module unload via `llambo_cmodcleanup()`

### Thread Safety

- Each model has independent context
- llama.cpp backend handles thread safety internally
- Caller should serialize access to same model_id

### Error Handling

- Returns -1 or nil on errors
- Logs errors to stderr
- Graceful degradation (won't crash VM)

### Performance

- Memory mapping (`use_mmap=1`) recommended for large models
- GPU offloading (`n_gpu_layers > 0`) if CUDA available
- Context size affects memory usage: 2048 tokens ≈ several hundred MB

## Limitations

- Maximum 32 concurrent models
- No streaming (full response generated before return)
- Simple greedy sampling (no top-k, top-p, etc.)
- Single-threaded inference per model

## Extending

To add new functions:

1. Add function to `Llambo_cmodtab[]`:
   ```c
   static Moduledata Llambo_cmodtab[] = {
       ...existing functions...,
       { "new_function", llama_new_function },
   };
   ```

2. Implement function with signature:
   ```c
   static Word*
   llama_new_function(Exec *e, Module *m, Word *args, uchar *ip)
   {
       // Implementation
   }
   ```

3. Update `llambo_c.m` with Limbo declaration:
   ```limbo
   new_function: fn(...): ...;
   ```

## Dependencies

### Build-time

- GCC or Clang
- Make
- llama.cpp library (libllama.a/so)
- Inferno headers (lib9.h, isa.h, interp.h, runt.h)

### Run-time

- llama.cpp library
- Standard C library
- C++ standard library
- pthreads
- Math library

## Troubleshooting

### "Cannot find llama.h"

**Solution:** Set `LLAMA_CPP_ROOT` in Makefile or environment:
```bash
export LLAMA_CPP_ROOT=/path/to/llama.cpp
make all
```

### "Undefined reference to llama_*"

**Solution:** Ensure llama.cpp is built:
```bash
cd /path/to/llama.cpp
mkdir build && cd build
cmake .. && cmake --build . --config Release
```

### "Module load fails in Limbo"

**Solution:** Check module path and permissions:
```bash
# Verify file exists
ls -l $INFERNO_ROOT/libinterp/llambo_c.so

# Check dependencies
ldd $INFERNO_ROOT/libinterp/llambo_c.so

# Verify readable/executable
chmod 755 $INFERNO_ROOT/libinterp/llambo_c.so
```

### Inference returns empty string

**Solution:** Check model and parameters:
- Verify model loaded successfully (model_id >= 0)
- Ensure model file is valid .gguf format
- Check max_tokens > 0
- Monitor available memory

## Development

### Code Style

- Follow Plan 9 C style
- Use tabs for indentation
- Keep functions short and focused
- Comment complex logic

### Testing

1. Build module: `make all`
2. Install locally: `make install`
3. Run Limbo test: `limbo test_ffi.b && /dis/test_ffi.dis`

### Debugging

Enable verbose output:

```c
#define DEBUG 1

#ifdef DEBUG
#define DPRINT(fmt, ...) fprintf(stderr, "DEBUG: " fmt "\n", ##__VA_ARGS__)
#else
#define DPRINT(fmt, ...)
#endif
```

## See Also

- `../llambo_c.m` - Limbo module declaration
- `../llambo_styx.b` - Styx file server wrapper
- `../BUILD-FFI.md` - Build documentation
- `../FFI-USAGE.md` - Usage guide (generated by build-ffi.sh)

## License

Same as parent project (ISC License).
