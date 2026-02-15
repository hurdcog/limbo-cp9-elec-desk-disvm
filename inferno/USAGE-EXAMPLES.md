# Dish and Limbot Usage Examples

This document provides practical examples of using the Inferno Dish distributed shell and Limbot AI chat assistant.

## Prerequisites

- Inferno OS installed (or emulator)
- Llambo cluster compiled and deployed
- Cluster initialized with nodes

## Limbot Examples

### Interactive Chat Mode

```bash
# Start interactive chat
llamboctl limbot

# Or use direct wrapper
cd inferno
./limbot-cli
```

**Example Session:**
```
$ llamboctl limbot
Initializing Limbot...
Starting distributed cluster (100 nodes)...
Cluster ready: 100 nodes active

╔════════════════════════════════════════════════════════╗
║          Limbot - AI Chat Assistant CLI               ║
║        Powered by Distributed Llambo Cluster          ║
╚════════════════════════════════════════════════════════╝

Type your message and press Enter. Commands:
  /help    - Show help
  /history - Show conversation history
  /clear   - Clear conversation history
  /status  - Show cluster status
  /exit    - Exit limbot

You: What is distributed cognition?

Limbot: Distributed cognition is an approach to understanding 
intelligence that emphasizes how cognitive processes are distributed 
across multiple agents, artifacts, and environmental structures...
[128 tokens, 45 ms]

You: Can you explain it with an example?

Limbot: A classic example is an airplane cockpit. The cognitive work 
of flying isn't just in the pilot's head - it's distributed across:
1. The pilot and co-pilot
2. Instruments and displays
3. Checklists and procedures
4. Air traffic control communication
Together they form a cognitive system...
[142 tokens, 48 ms]

You: /status

Cluster Information:
  Max Nodes: 100
  Active Nodes: 100
  Strategy: least-loaded
  Utilization: 45%

You: /exit
Goodbye!
```

### One-Shot Inference Mode

```bash
# Single question with immediate answer
llamboctl limbot "What is machine learning?"

# Multiple prompts
llamboctl limbot "Explain neural networks in simple terms"
llamboctl limbot "What are the key challenges in distributed systems?"

# Using direct wrapper
./limbot-cli "Define artificial intelligence"
```

**Example Output:**
```
$ llamboctl limbot "What is Inferno OS?"
Initializing Limbot...
Starting distributed cluster (100 nodes)...
Cluster ready: 100 nodes active

Limbot: Inferno is a distributed operating system originally 
developed by Bell Labs. It was designed for networked environments 
and uses the Limbo programming language. Key features include:
- Plan 9 heritage
- Distributed computing via Styx protocol
- Dis virtual machine
- Namespace-based resource access
```

### Interactive Commands

While in interactive mode:

```
/help       - Display all available commands
/history    - Show conversation history
/clear      - Clear conversation context
/status     - Show cluster status and metrics
/exit       - Exit the chat session
```

## Dish Shell Examples

### Interactive Shell Mode

```bash
# Launch distributed shell
llamboctl dish

# Or run directly
cd inferno
emu sh -c "run /dis/dish-integration.dis"
```

**Example Session:**
```
$ llamboctl dish
=== Llambo Dish Integration ===
Distributed Shell for Llama.cpp Cluster

Setting up distributed shell namespaces...
  /n/dish -> mounted
  /n/llambo -> mounted
Spawning distributed cluster (this may take a moment)...
Cluster ready: 100 nodes active
Mounting cluster control files...
  /n/llambo/ctl -> ready
  /n/llambo/status -> ready
  /n/llambo/data -> ready

Distributed Shell Ready. Type 'help' for commands.
llambo> help

Llambo Distributed Shell Commands:
  help, ?              Show this help
  status               Show cluster status
  nodes                List cluster nodes
  infer <prompt>       Run inference on prompt
  ask <prompt>         Alias for infer
  cluster <cmd>        Cluster management commands
  exit, quit           Exit shell

Or just type your prompt directly!

llambo> status

Cluster Status:
  Active Nodes: 100
  Max Nodes: 1000
  Strategy: least-loaded
  Utilization: 35%
  Throughput: 1,234 tokens/sec

llambo> infer What is the Styx protocol?

[Distributing inference across cluster...]

The Styx protocol, also known as 9P, is a network protocol for 
distributed file systems. It was developed for Plan 9 and inherited 
by Inferno OS. It enables:
- Remote resource access via file operations
- Namespace sharing across networks
- Clean abstraction for distributed services

[Inference completed in 52 ms, 95 tokens]

llambo> nodes

Cluster nodes: (distributed across Dis VM instances)
Note: Use 'llamboctl nodes list' for detailed node information

llambo> cluster info

Cluster Information:
  Max Nodes: 1000
  Strategy: least-loaded
  Type: Distributed Dis VM instances

llambo> exit
Shutting down cluster...
```

### Direct Prompts

You can type prompts directly without the `infer` command:

```
llambo> Tell me about distributed computing

[Distributing inference across cluster...]

Distributed computing is a field of computer science that studies 
distributed systems - systems whose components are located on 
different networked computers, which communicate and coordinate 
their actions by passing messages...

[Inference completed in 48 ms, 118 tokens]
```

## Advanced Usage

### Using with llamboctl

All tools integrate with `llamboctl` for unified management:

```bash
# Initialize cluster first
llamboctl init
llamboctl spawn --count 100 --type tiny

# Check cluster health
llamboctl health

# Use Limbot
llamboctl limbot                    # Interactive
llamboctl limbot "Your question"    # One-shot

# Use Dish
llamboctl dish                      # Interactive shell
```

### Conversation History

Limbot automatically saves conversation history:

```bash
# History stored in: /usr/llambo/limbot-history.txt

# View history in interactive mode
You: /history

--- Conversation History ---

You: What is AI?

Limbot: AI stands for Artificial Intelligence...

You: How does it work?

Limbot: AI systems use various approaches...

--- End of History ---
```

### Cluster Status Monitoring

Both tools provide cluster status:

```bash
# In Limbot
You: /status

# In Dish
llambo> status

# Via llamboctl
llamboctl status
```

## Integration with Cluster

Both Dish and Limbot integrate seamlessly with the Llambo cluster:

1. **Automatic Load Balancing**: Requests distributed across available nodes
2. **Fault Tolerance**: Failures handled by load balancer
3. **Auto-scaling**: Cluster scales based on demand
4. **Real-time Metrics**: Monitor performance and utilization

## Tips

1. **Start small**: Begin with 10-100 nodes for testing
2. **Monitor resources**: Use `/status` to check utilization
3. **Clear history**: Use `/clear` in Limbot to start fresh conversations
4. **One-shot for scripts**: Use one-shot mode in automation/scripts
5. **Interactive for exploration**: Use interactive mode for conversations

## Troubleshooting

### Limbot won't start

```bash
# Check Inferno installation
echo $INFERNO_ROOT
ls -la $INFERNO_ROOT

# Check compilation
cd inferno
./deploy.sh compile

# Check cluster
llamboctl status
```

### Dish shell errors

```bash
# Verify namespace mounts
ls -la /n/dish
ls -la /n/llambo

# Check emulator
which emu
emu sh -c "echo test"
```

### No response from cluster

```bash
# Check cluster status
llamboctl health

# Verify nodes are running
llamboctl nodes list

# Check load balancer
llamboctl balancer stats
```

## See Also

- [README.md](README.md) - Complete Llambo documentation
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick command reference
- [ARCHITECTURE-DIAGRAM.md](ARCHITECTURE-DIAGRAM.md) - Architecture details
- [cluster-config.yaml](cluster-config.yaml) - Cluster configuration
