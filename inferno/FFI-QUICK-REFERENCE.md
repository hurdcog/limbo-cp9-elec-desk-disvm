# Llambo FFI Quick Reference

## Overview

The Llambo FFI provides native C bindings to llama.cpp for high-performance LLM inference in Inferno OS.

## Building

```bash
# Full FFI build
./build-ffi.sh build

# Check dependencies only
./build-ffi.sh check

# Clean build artifacts
./build-ffi.sh clean
```

## Using FFI from Limbo

### Basic Usage

```limbo
include "llambo_c.m";
    llambo_c: Llambo_c;

# Load module
llambo_c = load Llambo_c Llambo_c->PATH;

# Load model
model_id := llambo_c->load_model("/models/llama-7b.gguf", 1, 0);

# Run inference
result := llambo_c->infer(model_id, "Hello!", 128, 0.8);

# Cleanup
llambo_c->free_model(model_id);
```

### Function Reference

#### load_model(path, use_mmap, n_gpu_layers)
- `path`: Model file path (.gguf format)
- `use_mmap`: 1 for memory mapping, 0 otherwise
- `n_gpu_layers`: GPU layers (0 for CPU only)
- Returns: model_id >= 0 on success, -1 on failure

#### infer(model_id, prompt, max_tokens, temperature)
- `model_id`: Model ID from load_model
- `prompt`: Input text
- `max_tokens`: Max tokens to generate
- `temperature`: 0.0 (deterministic) to 1.0 (creative)
- Returns: Generated text string

#### tokenize(model_id, text)
- `model_id`: Model ID
- `text`: Text to tokenize
- Returns: Array of token IDs

#### get_model_info(model_id)
- `model_id`: Model ID
- Returns: JSON string with model info

#### free_model(model_id)
- `model_id`: Model ID to free
- Returns: 0 on success, -1 on failure

## Using Styx File Server

### Start Server

```bash
mount {llambo_styx} /n/llambo
```

### File Interface

```
/n/llambo/
    ctl         # Control file (load/free models)
    clone       # Get new model ID
    models/
        0/
            data    # Inference (write prompt, read result)
            info    # Model info (read-only)
            status  # Model status (read-only)
```

### Examples

```bash
# Load model
echo "load /models/llama-7b.gguf 1 0" > /n/llambo/ctl

# Run inference
echo "Hello, world!|128|0.8" > /n/llambo/models/0/data
cat /n/llambo/models/0/data

# Get model info
cat /n/llambo/models/0/info

# Free model
echo "free 0" > /n/llambo/ctl
```

## Integration with Llambo

The main `llambo.b` module automatically uses FFI when available:

```limbo
include "llambo.m";
    llambo: Llambo;

# Uses FFI automatically if llambo_c.so is loaded
response := llambo->infer(req);
```

Fallback to pure Limbo if FFI unavailable.

## Testing

```bash
# Run FFI tests
./deploy.sh test-ffi

# Or directly
/dis/test-ffi.dis
```

## Examples

### Simple Example

```bash
# Compile
limbo -o ffi-example.dis ffi-example.b

# Run
/dis/ffi-example.dis /models/llama-7b.gguf "What is AI?"
```

### Distributed Example

```bash
# Terminal 1: Start Styx server
mount {llambo_styx} /n/llambo
echo "load /models/llama-7b.gguf 1 0" > /n/llambo/ctl

# Terminal 2: Use remotely
mount -A tcp!server!9999 /n/llambo
echo "Hello|128|0.8" > /n/llambo/models/0/data
cat /n/llambo/models/0/data
```

## Troubleshooting

### Module Not Found

**Problem:** `load Llambo_c` returns nil

**Solution:**
- Check FFI is built: `./build-ffi.sh build`
- Verify location: `ls inferno/lib/llambo_c.so`
- Install: `cd inferno/c-module && make install`

### Model Load Fails

**Problem:** `load_model()` returns -1

**Solution:**
- Check model path exists
- Verify .gguf format (not older formats)
- Ensure sufficient memory
- Check file permissions

### Inference Returns Empty

**Problem:** `infer()` returns ""

**Solution:**
- Verify model loaded (model_id >= 0)
- Check max_tokens > 0
- Monitor memory usage
- Try lower temperature (0.1-0.5)

## Performance Tips

1. **Use Memory Mapping**: Set `use_mmap=1` for faster model loading
2. **GPU Offloading**: Set `n_gpu_layers > 0` if CUDA available
3. **Adjust Context**: Modify `n_ctx` in C code for different memory/speed tradeoffs
4. **Temperature**: Lower (0.1-0.3) for focused, higher (0.8-1.0) for creative

## Architecture

```
┌─────────────────────────────────────┐
│ Limbo Application                   │
├─────────────────────────────────────┤
│ llambo_c.m (FFI Declaration)        │
├─────────────────────────────────────┤
│ llambo_styx.b (Optional)            │
│ - Styx/9P File Server               │
│ - Distributed Access                │
├─────────────────────────────────────┤
│ llambo_c.so (C Module)              │
│ - Inferno VM Integration            │
│ - Type Conversion                   │
├─────────────────────────────────────┤
│ libllama.a (llama.cpp)              │
│ - LLM Inference Engine              │
└─────────────────────────────────────┘
```

## Files

- `llambo_c.m` - FFI module declaration
- `llambo_c.c` - C implementation
- `llambo_c.h` - C header
- `llambo_styx.b` - Styx file server
- `build-ffi.sh` - Build script
- `c-module/Makefile` - C build system
- `ffi-example.b` - Example usage
- `test-ffi.b` - Test suite

## Documentation

- **BUILD-FFI.md** - Complete build guide
- **c-module/README.md** - C module details
- **FFI-USAGE.md** - Usage guide (auto-generated)

## See Also

- [Inferno OS](https://inferno-os.org/)
- [Limbo Language](https://inferno-os.org/inferno/papers/limbo.html)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [Styx Protocol](http://doc.cat-v.org/inferno/4th_edition/styx)
