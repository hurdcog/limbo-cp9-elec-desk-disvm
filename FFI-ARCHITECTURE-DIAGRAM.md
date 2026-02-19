# Inferno/Limbo FFI Architecture Diagram

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER APPLICATIONS                            │
│                                                                     │
│  ┌────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ limbot.b   │  │ dish-    │  │ ffi-     │  │ llambotest.b │   │
│  │ (chat CLI) │  │ integration│  │ example.b│  │ (tests)      │   │
│  └────────────┘  └──────────┘  └──────────┘  └──────────────┘   │
│         │              │              │              │             │
│         └──────────────┴──────────────┴──────────────┘             │
│                            │                                        │
└────────────────────────────┼────────────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────────────┐
│                    LIMBO CORE MODULE                                │
│                                                                     │
│  ┌──────────────────────────▼───────────────────────────────────┐ │
│  │              llambo.b (Main Module)                          │ │
│  │  ┌────────────────────────────────────────────────────────┐ │ │
│  │  │ infer_ffi()     ◄────── Automatic FFI Detection       │ │ │
│  │  │    ↓ try FFI                                           │ │ │
│  │  │    ↓ fallback to pure Limbo if unavailable            │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
│         ┌───────────────────┴────────────────────┐                │
│         │                                         │                │
│         ▼ FFI Path                                ▼ Pure Path      │
└─────────┼─────────────────────────────────────────┼────────────────┘
          │                                         │
┌─────────┼─────────────────────────────────────────┼────────────────┐
│  FFI LAYER (New Implementation)                   │ Limbo Fallback │
│                                                    │                │
│  ┌─────▼─────────────────────────────┐            │  ┌───────────┐ │
│  │   llambo_c.m                      │            │  │ Pure      │ │
│  │   (FFI Module Declaration)        │            │  │ Limbo     │ │
│  │                                   │            │  │ Stubs     │ │
│  │  - load_model()                   │            │  └───────────┘ │
│  │  - free_model()                   │            │                │
│  │  - infer()                        │            └────────────────┘
│  │  - tokenize()                     │                             │
│  │  - get_model_info()               │                             │
│  └───────────────┬───────────────────┘                             │
│                  │                                                  │
│  ┌───────────────▼─────────────────────────────────────────────┐  │
│  │         llambo_styx.b (Optional)                            │  │
│  │         Styx/9P File Server for Distributed Access          │  │
│  │                                                              │  │
│  │  File Hierarchy:                                            │  │
│  │    /n/llambo/ctl         ◄── Control commands              │  │
│  │    /n/llambo/clone       ◄── Get model ID                  │  │
│  │    /n/llambo/models/N/   ◄── Per-model files               │  │
│  │        data              ◄── Inference I/O                  │  │
│  │        info              ◄── Model metadata                 │  │
│  │        status            ◄── Model status                   │  │
│  │                                                              │  │
│  │  Enables: Cross-VM access, distributed clusters             │  │
│  └──────────────────────────┬───────────────────────────────────┘  │
│                             │                                      │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────────┐
│  C MODULE LAYER (Native Code)                                      │
│                             │                                      │
│  ┌──────────────────────────▼───────────────────────────────────┐ │
│  │             llambo_c.c / llambo_c.h                          │ │
│  │             (Inferno Builtin Module)                         │ │
│  │                                                              │ │
│  │  Functions:                                                  │ │
│  │    llama_load_model()    ──┐                                │ │
│  │    llama_free_model()      │                                │ │
│  │    llama_tokenize()        ├─► Inferno VM Integration       │ │
│  │    llama_infer()           │   (builtinmod, Word*, etc.)    │ │
│  │    llama_get_model_info()──┘                                │ │
│  │                                                              │ │
│  │  Memory Management:                                          │ │
│  │    - Model cache (32 slots)                                 │ │
│  │    - Reference counting                                      │ │
│  │    - Automatic cleanup                                       │ │
│  │                                                              │ │
│  │  Type Conversion:                                            │ │
│  │    Limbo String ◄──► C char*                                │ │
│  │    Limbo int    ◄──► C int                                  │ │
│  │    Limbo real   ◄──► C double                               │ │
│  │    Limbo array  ◄──► C array                                │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────────┐
│  LLAMA.CPP LIBRARY (C++)                                           │
│                             │                                      │
│  ┌──────────────────────────▼───────────────────────────────────┐ │
│  │                    libllama.a / libllama.so                  │ │
│  │                                                              │ │
│  │  Core Functions:                                             │ │
│  │    llama_load_model_from_file()                             │ │
│  │    llama_new_context_with_model()                           │ │
│  │    llama_tokenize()                                          │ │
│  │    llama_decode()                                            │ │
│  │    llama_get_logits_ith()                                    │ │
│  │    llama_token_to_piece()                                    │ │
│  │    llama_free() / llama_free_model()                        │ │
│  │                                                              │ │
│  │  Features:                                                   │ │
│  │    - Model loading (.gguf format)                           │ │
│  │    - Memory mapping                                          │ │
│  │    - GPU offloading (CUDA)                                  │ │
│  │    - Tokenization                                            │ │
│  │    - Inference engine                                        │ │
│  │    - Sampling strategies                                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Example: Inference Request

```
1. User Application (limbot.b)
   ↓
   prompt = "What is AI?"
   ↓

2. Limbo Core (llambo.b)
   ↓
   req = InferenceRequest{prompt, max_tokens: 128, temperature: 0.8}
   ↓
   infer_ffi(req)  ──┐
                     │
                     ├─► Try load Llambo_c
                     │   ↓
                     │   Success? → Continue FFI path
                     │   Fail?    → Pure Limbo fallback
                     │
                     ↓

3a. FFI Path (llambo_c.m → llambo_c.c)
    ↓
    llambo_c->load_model("/models/llama-7b.gguf", 1, 0)
    ↓
    model_id = 0
    ↓
    llambo_c->infer(0, "What is AI?", 128, 0.8)
    ↓

4. C Module (llambo_c.c)
   ↓
   Convert: Limbo String → C char*
   ↓
   llama_tokenize(model, text, ...)
   ↓
   tokens[] = [1, 2643, 338, ...]
   ↓
   llama_decode(ctx, batch)
   ↓
   Loop: generate tokens
      ↓
      logits = llama_get_logits_ith(ctx, -1)
      ↓
      sample token (greedy or temperature)
      ↓
      token_str = llama_token_to_piece(ctx, token)
      ↓
      append to result
   ↓
   Convert: C char* → Limbo String
   ↓
   return result

5. Back to Limbo
   ↓
   response.text = "AI is artificial intelligence..."
   ↓
   return response

6. Display to User
   ↓
   print(response.text)


3b. Pure Limbo Path (fallback)
    ↓
    Simple tokenization (whitespace)
    ↓
    Echo response with marker
    ↓
    return "[pure Limbo mode]"
```

## Distributed Access via Styx

```
┌───────────────────┐         ┌───────────────────┐
│   Dis VM 1        │         │   Dis VM 2        │
│   (Server)        │         │   (Client)        │
│                   │         │                   │
│  llambo_styx.b    │◄────────┤  mount tcp!...    │
│       │           │  Styx   │       │           │
│       ↓           │  (9P)   │       ↓           │
│  /n/llambo/       │         │  /n/llambo/       │
│    ctl            │         │    ctl            │
│    models/0/data  │         │    models/0/data  │
│       │           │         │       │           │
│       ↓           │         │       ↓           │
│  llambo_c.so      │         │   (remote)        │
│       │           │         │                   │
│       ↓           │         │                   │
│  llama.cpp        │         │                   │
└───────────────────┘         └───────────────────┘

Cross-VM inference:
1. Server: load model via Styx
2. Client: write prompt to data file
3. Server: FFI inference via C module
4. Client: read result from data file
```

## Build System Flow

```
./build-ffi.sh build
    │
    ├──► Check Inferno     ──► Find $INFERNO_ROOT
    │                          Verify headers
    │
    ├──► Build llama.cpp   ──► cmake .. && make
    │                          libllama.a created
    │
    ├──► Build C module    ──► gcc -c llambo_c.c
    │                          gcc -shared → llambo_c.so
    │
    ├──► Compile Limbo     ──► limbo llambo_styx.b
    │                          limbo test-ffi.b
    │                          limbo ffi-example.b
    │
    ├──► Install           ──► cp llambo_c.so → $INFERNO_ROOT/libinterp/
    │                          (or local lib/ dir)
    │
    └──► Generate docs     ──► FFI-USAGE.md
```

## Integration Points

1. **Automatic FFI Detection** (llambo.b)
   - Tries to load Llambo_c module
   - Uses FFI if available
   - Falls back to pure Limbo if not

2. **Styx Wrapper** (llambo_styx.b)
   - Optional distributed access
   - Wraps FFI with file interface
   - Enables cross-VM usage

3. **Build Integration** (deploy.sh)
   - Compiles FFI modules
   - Includes in deployment
   - test-ffi command

4. **Module Loading** (Inferno VM)
   - Builtin module: compiled into VM
   - Dynamic loading: .so file loaded at runtime
   - $Llambo_c path constant

## Key Design Decisions

1. **Builtin Module Pattern**: Use Inferno's native module system
2. **Reference Counting**: Prevent premature model cleanup
3. **Styx for Distribution**: Leverage 9P for cross-VM access
4. **Automatic Fallback**: Pure Limbo when FFI unavailable
5. **File-based Interface**: Standard Unix/Plan 9 pattern
6. **Static Model Array**: Simple, predictable management
7. **Type Conversion**: Explicit Limbo ↔ C conversion
8. **Error Handling**: Return -1/nil on errors, no exceptions

## Performance Characteristics

```
Operation          FFI (C)       Pure Limbo    Styx Overhead
─────────────────  ────────────  ────────────  ─────────────
Model Loading      1-5 sec       N/A           +10-50ms
Inference          10-100 tok/s  N/A           +5-10ms/req
Tokenization       <1ms          ~5-10ms       +1-2ms
Memory per Model   100MB-8GB     ~1MB          +5-10MB
Function Call      <0.1ms        0.1ms         +1-2ms (IPC)
```

## Security Model

```
User Space
    │
    ├──► Limbo Code         ─── Type-safe, VM-protected
    │                           No direct memory access
    ↓
C Module (llambo_c.so)      ─── Runs in Inferno VM context
    │                           Access to VM internals
    │                           Must follow VM conventions
    ↓
llama.cpp                   ─── Native C++ code
                                Direct memory access
                                OS-level permissions
```

- Limbo provides type safety
- C module runs in VM context
- FFI boundary carefully managed
- Styx provides namespace isolation
- Reference counting prevents leaks
- Cleanup on VM shutdown

---

This architecture provides:
- ✅ Maximum performance (native C)
- ✅ Type safety (Limbo layer)
- ✅ Distribution (Styx protocol)
- ✅ Portability (automatic fallback)
- ✅ Maintainability (clean separation)
