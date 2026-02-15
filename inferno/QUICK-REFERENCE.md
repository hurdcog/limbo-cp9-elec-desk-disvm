# Llambo Quick Reference Guide

Quick reference for developers working with the Llambo distributed llama.cpp implementation.

## Module API Reference

### Model

```limbo
# Load a model
model := Llambo->Model.load("/models/llama-7b.gguf", params);

# Free model resources
model.free();
```

### Context

```limbo
# Create inference context
ctx := Llambo->Context.new(model, 2048, 512, 4);
#                                 n_ctx, n_batch, n_threads

# Free context
ctx.free();
```

### Inference

```limbo
# Create request
req := ref InferenceRequest;
req.prompt = "Your prompt here";
req.max_tokens = 128;
req.temperature = 0.7;
req.top_p = 0.9;
req.ctx = ctx;

# Run inference
response := Llambo->infer(req);

# Access results
text := response.text;
token_count := response.token_count;
time_ms := response.completion_time;
```

### ClusterNode

```limbo
# Spawn a cluster node
node := Llambo->ClusterNode.spawn("tcp!localhost!9000", 100);

# Submit inference request to node
response := node.submit(req);

# Shutdown node
node.shutdown();
```

### LoadBalancer

```limbo
# Create load balancer
lb := Llambo->LoadBalancer.new(1);  # 1 = least-loaded strategy

# Register nodes
lb.register(node1);
lb.register(node2);

# Balance request
response := lb.balance(req);

# Get statistics
stats := lb.getstats();
print(stats);

# Unregister node
lb.unregister("node-id");
```

### Orchestrator

```limbo
# Create orchestrator
orch := Llambo->Orchestrator.new(10000, 1);
#                                max_nodes, strategy

# Spawn cluster
count := orch.spawn_cluster(1000, "/models/llama-7b.gguf");

# Process request (automatically load-balanced)
response := orch.process("Your prompt", 128);

# Get cluster status
status := orch.status();

# Shutdown cluster
orch.shutdown_cluster();
```

## Load Balancing Strategies

```limbo
0  # Round-robin: Distribute evenly
1  # Least-loaded: Route to node with lowest load
2  # Random: Random distribution
```

## Command Line Tools

### llamboctl

```bash
# Initialize cluster
llamboctl init

# Spawn nodes
llamboctl spawn --count 1000 --type tiny
llamboctl spawn --count 100 --type medium

# Check status
llamboctl status

# List nodes
llamboctl nodes list

# Load balancer statistics
llamboctl balancer stats

# Change balancing strategy
llamboctl balancer --strategy least-loaded

# Export metrics
llamboctl metrics --export prometheus
llamboctl metrics --export json

# Configuration
llamboctl config --show
llamboctl config --validate
llamboctl config --edit

# Health check
llamboctl health

# Shutdown cluster
llamboctl shutdown

# Launch Limbot AI chat assistant
llamboctl limbot                    # Interactive mode
llamboctl limbot "Your prompt"      # One-shot mode
llamboctl limbot -h                 # Help

# Launch Dish integration
llamboctl dish
```

### limbot-cli

```bash
# Interactive AI chat
./limbot-cli
./limbot-cli -i

# One-shot inference
./limbot-cli "What is machine learning?"
./limbot-cli "Explain neural networks"

# Help
./limbot-cli -h
```

**Interactive Commands:**
```
/help       - Show available commands
/history    - Show conversation history
/clear      - Clear conversation history
/status     - Show cluster status
/exit       - Exit limbot
```

### Dish Integration

```bash
# Launch distributed shell
llamboctl dish

# Or run dish-integration directly (if compiled)
emu sh -c "run /dis/dish-integration.dis"
```

**Dish Shell Commands:**
```
llambo> help         - Show available commands
llambo> status       - Show cluster status
llambo> nodes        - List cluster nodes
llambo> infer <text> - Run inference
llambo> ask <text>   - Same as infer
llambo> cluster info - Cluster information
llambo> exit         - Exit shell
```

**Example Usage:**
```
llambo> status
llambo> infer What is distributed computing?
llambo> ask Explain Inferno OS
llambo> exit
```

### deploy.sh

```bash
# Check Inferno installation
./deploy.sh check

# Compile Limbo modules
./deploy.sh compile

# Deploy locally
./deploy.sh deploy-local

# Deploy to cluster
./deploy.sh deploy-cluster

# Start orchestrator
./deploy.sh start

# Run tests
./deploy.sh test

# Check status
./deploy.sh status

# Complete deployment
./deploy.sh all
```

## Configuration (cluster-config.yaml)

### Node Types

```yaml
cluster:
  nodes:
    tiny:
      count: 1000
      resources:
        cpu: "0.1 core"
        memory: "128MB"
        model: "llama-1b-quantized.gguf"
        context_size: 512
        threads: 1
```

### Load Balancing

```yaml
cluster:
  load_balancer:
    strategy: "least-loaded"  # or "round-robin", "random"
    health_check_interval: 1000
    max_retries: 3
    timeout: 30000
```

### Auto-scaling

```yaml
cluster:
  orchestrator:
    auto_scale: true
    min_nodes: 100
    max_nodes: 10000
    scale_up_threshold: 0.8
    scale_down_threshold: 0.2
```

## Example Programs

### Simple Inference

```limbo
implement Example;

include "sys.m";
include "draw.m";
include "llambo.m";

init(ctxt: ref Draw->Context, args: list of string)
{
    sys := load Sys Sys->PATH;
    llambo := load Llambo Llambo->PATH;
    llambo->init(ctxt, nil);
    
    # Load model
    model := llambo->Model.load("/models/llama-7b.gguf", nil);
    ctx := llambo->Context.new(model, 2048, 512, 4);
    
    # Create request
    req := ref InferenceRequest;
    req.prompt = "What is AI?";
    req.max_tokens = 128;
    req.ctx = ctx;
    
    # Infer
    response := llambo->infer(req);
    sys->print("Response: %s\n", response.text);
    
    # Cleanup
    ctx.free();
    model.free();
}
```

### Distributed Cluster

```limbo
implement ClusterExample;

include "sys.m";
include "draw.m";
include "llambo.m";

init(ctxt: ref Draw->Context, args: list of string)
{
    sys := load Sys Sys->PATH;
    llambo := load Llambo Llambo->PATH;
    llambo->init(ctxt, nil);
    
    # Create orchestrator with 1000 nodes
    orch := llambo->Orchestrator.new(1000, 1);
    
    # Spawn cluster
    count := orch.spawn_cluster(1000, "/models/llama-7b.gguf");
    sys->print("Spawned %d nodes\n", count);
    
    # Process multiple requests
    prompts := array[] of {
        "Explain machine learning",
        "What is deep learning?",
        "Describe neural networks"
    };
    
    for (i := 0; i < len prompts; i++) {
        response := orch.process(prompts[i], 64);
        sys->print("Response %d: %s\n", i+1, response.text);
    }
    
    # Show status
    sys->print("%s\n", orch.status());
    
    # Shutdown
    orch.shutdown_cluster();
}
```

### Custom Load Balancer

```limbo
# Extend LoadBalancer with custom strategy
LoadBalancer.balance(lb: self ref LoadBalancer, req: ref InferenceRequest)
{
    # Custom cognitive-affinity strategy
    # Route based on prompt characteristics
    
    if (len req.prompt > 1000) {
        # Long prompts go to large nodes
        node := find_large_node(lb.nodes);
    } else {
        # Short prompts to tiny nodes
        node := find_tiny_node(lb.nodes);
    }
    
    return node.submit(req);
}
```

## Performance Tuning

### Node Configuration

```limbo
# For high throughput (more nodes, less memory each)
count := 1000;
memory := 128MB;

# For high quality (fewer nodes, more memory each)
count := 100;
memory := 8GB;
```

### Batch Size

```limbo
# Smaller batch = lower latency
ctx := Llambo->Context.new(model, 2048, 256, 4);

# Larger batch = higher throughput
ctx := Llambo->Context.new(model, 2048, 1024, 4);
```

### Thread Count

```limbo
# Match to available CPU cores
n_threads := 4;  # For 4-core system
n_threads := 8;  # For 8-core system
```

## Monitoring

### Prometheus Metrics

```bash
# Export metrics
llamboctl metrics --export prometheus > /tmp/metrics.txt

# Metrics available:
# - llambo_inference_latency_ms
# - llambo_token_throughput
# - llambo_node_utilization_percent
# - llambo_active_nodes
# - llambo_total_requests
# - llambo_failed_requests
```

### Health Checks

```bash
# Check cluster health
llamboctl health

# Output:
# ✓ Orchestrator:    HEALTHY
# ✓ Load Balancer:   HEALTHY
# ✓ Node Health:     987/1000 HEALTHY
# ⚠ Node Health:     13/1000 DEGRADED
```

## Troubleshooting

### Compilation Errors

```bash
# Set Inferno environment
export INFERNO_ROOT=/usr/inferno
source $INFERNO_ROOT/env.sh

# Recompile
./deploy.sh compile
```

### Node Spawn Failures

```bash
# Check resource limits
ulimit -n 10000  # Increase file descriptor limit

# Verify ports
netstat -an | grep 9000-11000

# Validate config
llamboctl config --validate
```

### Performance Issues

```limbo
# Reduce node count
orch.spawn_cluster(100, path);  # Instead of 1000

# Increase resources per node
# Edit cluster-config.yaml:
tiny:
  resources:
    memory: "256MB"  # Instead of 128MB
```

## Common Patterns

### Parallel Processing

```limbo
# Process multiple prompts in parallel
results := array[n] of ref InferenceResponse;

for (i := 0; i < n; i++) {
    spawn process_async(prompts[i], results, i);
}

# Wait for all to complete
for (i := 0; i < n; i++) {
    <-done_chan;
}
```

### Cognitive Fusion

```limbo
# Get multiple perspectives on same query
responses := array[3] of ref InferenceResponse;

for (i := 0; i < 3; i++) {
    responses[i] = orch.process(prompt, 128);
}

# Combine results
fused := combine_responses(responses);
```

### Error Handling

```limbo
response := orch.process(prompt, 128);

if (response == nil) {
    # Handle error
    sys->print("Inference failed\n");
} else {
    # Process response
    sys->print("Success: %s\n", response.text);
}
```

## Best Practices

1. **Always free resources**: Call `.free()` on models and contexts
2. **Use orchestrator for clusters**: Don't manually manage nodes
3. **Match strategy to workload**: Use least-loaded for varied requests
4. **Monitor health**: Regular health checks prevent cascading failures
5. **Auto-scale carefully**: Set appropriate thresholds to avoid thrashing
6. **Test with small clusters first**: Validate with 10-100 nodes before scaling
7. **Use appropriate node types**: Match model size to available memory

## Environment Variables

```bash
INFERNO_ROOT      # Path to Inferno OS installation
LLAMBO_ROOT       # Path to Llambo source
CLUSTER_CONFIG    # Path to cluster configuration
LLAMBO_MODE       # worker | orchestrator
LLAMBO_CLUSTER_ID # Cluster identifier
```

## File Locations

```
/dis/llambo.dis           # Compiled module
/n/llambo/                # Namespace root
/n/llambo/worker-XXXX/    # Worker namespaces
/n/models/                # Model files
/tmp/llambo-cluster.state # Cluster state
```

## Quick Deployment Checklist

- [ ] Inferno OS installed
- [ ] Limbo compiler available
- [ ] Models downloaded to `/models`
- [ ] Configuration edited (`cluster-config.yaml`)
- [ ] Modules compiled (`./deploy.sh compile`)
- [ ] Cluster initialized (`llamboctl init`)
- [ ] Nodes spawned (`llamboctl spawn`)
- [ ] Health check passed (`llamboctl health`)
- [ ] Test inference works (`./deploy.sh test`)

## Support

For issues or questions:
- See: `inferno/README.md` for detailed documentation
- Check: `inferno/ARCHITECTURE-DIAGRAM.md` for visual architecture
- Review: `ARCHITECTURE.md` for design decisions
