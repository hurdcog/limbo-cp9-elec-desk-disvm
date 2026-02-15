# Llambo Distributed Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LLAMBO DISTRIBUTED COGNITION                         │
│                      Global Inference Network Architecture                   │
└─────────────────────────────────────────────────────────────────────────────┘

              ┌───────────────┐         ┌───────────────┐
              │   Limbot CLI  │         │  Dish Shell   │
              │  (AI Chat)    │         │ (Distributed) │
              └───────┬───────┘         └───────┬───────┘
                      │                         │
                      └──────────┬──────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────┐
                  │   Client Applications    │
                  │    (API Requests)        │
                  └──────────┬───────────────┘
                             │
                             ▼
              ┌──────────────────────────┐
              │    Orchestrator          │
              │  - Cluster Management    │
              │  - Auto-scaling          │
              │  - Node Spawning         │
              └──────────┬───────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │    Load Balancer         │
              │  - Strategy Selection    │
              │  - Health Monitoring     │
              │  - Request Distribution  │
              └──────────┬───────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ ClusterNode-0001│ │ ClusterNode-0002│ │ ClusterNode-NNNN│
│                 │ │                 │ │                 │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │ Dis VM      │ │ │ │ Dis VM      │ │ │ │ Dis VM      │ │
│ │ Instance    │ │ │ │ Instance    │ │ │ │ Instance    │ │
│ ├─────────────┤ │ │ ├─────────────┤ │ │ ├─────────────┤ │
│ │llambo.dis   │ │ │ │llambo.dis   │ │ │ │llambo.dis   │ │
│ │Model: 1B    │ │ │ │Model: 7B    │ │ │ │Model: 13B   │ │
│ │Mem: 128MB   │ │ │ │Mem: 1GB     │ │ │ │Mem: 8GB     │ │
│ │CPU: 0.1     │ │ │ │CPU: 1       │ │ │ │CPU: 4       │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
└─────────────────┘ └─────────────────┘ └─────────────────┘
        │                │                │
        └────────────────┴────────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │   Styx Protocol (9P)     │
              │  Inter-node Messaging    │
              └──────────────────────────┘
```

## Interactive Tools Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Interface Layer                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐         ┌──────────────────────────┐
│      Limbot CLI          │         │    Dish Integration      │
│  (AI Chat Assistant)     │         │  (Distributed Shell)     │
├──────────────────────────┤         ├──────────────────────────┤
│ • Interactive chat       │         │ • Shell prompt           │
│ • Conversation history   │         │ • Namespace access       │
│ • Streaming responses    │         │ • Direct cluster control │
│ • Context management     │         │ • Styx protocol hooks    │
│ • /commands support      │         │ • Real-time status       │
│                          │         │                          │
│ Session Storage:         │         │ Namespace Mounts:        │
│ /usr/llambo/             │         │ /n/dish/                 │
│   limbot-history.txt     │         │ /n/llambo/               │
│   limbot.conf            │         │   ctl, data, status      │
└────────┬─────────────────┘         └────────┬─────────────────┘
         │                                    │
         └────────────────┬───────────────────┘
                          │
                          ▼
              ┌──────────────────────────┐
              │  llamboctl Interface     │
              │  (Unified CLI Control)   │
              ├──────────────────────────┤
              │ llamboctl limbot         │
              │ llamboctl dish           │
              │ llamboctl status         │
              └──────────┬───────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │    Orchestrator API      │
              └──────────────────────────┘
```

## Node Types & Distribution

```
Tiny Nodes (750 instances)
├── Model: llama-1b-quantized.gguf
├── Memory: 128MB per instance
├── CPU: 0.1 core per instance
├── Throughput: ~10 tok/s per node
└── Total: 7,500 tok/s

Medium Nodes (200 instances)
├── Model: llama-7b-quantized.gguf
├── Memory: 1GB per instance
├── CPU: 1 core per instance
├── Throughput: ~10 tok/s per node
└── Total: 2,000 tok/s

Large Nodes (50 instances)
├── Model: llama-13b.gguf
├── Memory: 8GB per instance
├── CPU: 4 cores per instance
├── Throughput: ~15 tok/s per node
└── Total: 750 tok/s

────────────────────────────────────
Cluster Aggregate: ~10,250 tok/s
Total Nodes: 1,000
Total Capacity: 100,000 inference units
```

## Load Balancing Strategies

```
┌─────────────────────────────────────────────────────────┐
│                   Request Distribution                   │
└─────────────────────────────────────────────────────────┘

Strategy 1: Round-Robin
    Request 1 → Node 0
    Request 2 → Node 1
    Request 3 → Node 2
    Request 4 → Node 0 (cycle)

Strategy 2: Least-Loaded
    Request → Node with lowest current load
    ┌──────────────────────────────────┐
    │ Node 0: load=0  ← Selected      │
    │ Node 1: load=5                   │
    │ Node 2: load=3                   │
    └──────────────────────────────────┘

Strategy 3: Random
    Request → Random(Nodes[0..N])
    Provides load distribution + fault tolerance
```

## Data Flow

```
┌──────────┐
│  Client  │
└────┬─────┘
     │ 1. Submit prompt "What is AI?"
     ▼
┌──────────────────┐
│  Orchestrator    │
└────┬─────────────┘
     │ 2. Create InferenceRequest
     ▼
┌──────────────────┐
│  Load Balancer   │
└────┬─────────────┘
     │ 3. Select optimal node (least-loaded)
     ▼
┌──────────────────┐
│  ClusterNode-42  │ ◄── Selected (load=0, status=idle)
└────┬─────────────┘
     │ 4. Process inference
     │    - Tokenize prompt
     │    - Run llama.cpp
     │    - Generate response
     ▼
┌──────────────────┐
│  Response        │
└────┬─────────────┘
     │ 5. Return to client
     ▼
┌──────────┐
│  Client  │ "AI is artificial intelligence..."
└──────────┘
```

## Interactive Tool Usage Flows

### Limbot Chat Flow

```
┌──────────────┐
│  User Input  │ "What is AI?"
└──────┬───────┘
       │
       ▼
┌────────────────────┐
│  Limbot Session    │
│  - Load history    │
│  - Build context   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  Orchestrator      │
│  - Queue request   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  Cluster Inference │
│  - Distributed     │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│  Stream Response   │
│  - Display tokens  │
│  - Save to history │
└────────┬───────────┘
         │
         ▼
┌──────────────┐
│  User sees:  │ "AI is artificial intelligence..."
│  Next prompt │ "You: "
└──────────────┘
```

### Dish Shell Flow

```
┌──────────────┐
│ Dish Prompt  │ "llambo> status"
└──────┬───────┘
       │
       ▼
┌────────────────────┐
│ Command Parser     │
│ - Parse: status    │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Namespace Access   │
│ - Read /n/llambo/  │
│   status file      │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Orchestrator.      │
│ status() → string  │
└────────┬───────────┘
         │
         ▼
┌──────────────┐
│ Display      │ Cluster: 1000 nodes, 67% util
│ llambo>      │ Next command
└──────────────┘
```

## Namespace Isolation

```
Inferno Namespace per Worker Node:

/n/llambo/worker-0001/
├── ctl              # Control file
├── data             # Data exchange
├── status           # Node status
├── models/
│   └── llama-1b.gguf
├── dis/
│   └── llambo.dis
└── namespace        # Isolated namespace

/n/llambo/worker-0002/
├── ctl
├── data
├── status
├── models/
│   └── llama-7b.gguf
├── dis/
│   └── llambo.dis
└── namespace
```

## Cognitive Fusion

```
For complex queries requiring consensus:

                    ┌─────────────┐
                    │   Query     │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌────────┐        ┌────────┐        ┌────────┐
    │ Node 1 │        │ Node 2 │        │ Node 3 │
    │ Result │        │ Result │        │ Result │
    └───┬────┘        └───┬────┘        └───┬────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │   Fusion    │
                   │  Algorithm  │
                   └──────┬──────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  Consensus  │
                   │   Result    │
                   └─────────────┘
```

## Deployment Topology

```
Physical Deployment:

┌────────────────────────────────────────────────────┐
│                 Data Center / Cloud                 │
├────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │  Server 1    │  │  Server 2    │  │  Server N│ │
│  ├──────────────┤  ├──────────────┤  ├──────────┤ │
│  │ Inferno OS   │  │ Inferno OS   │  │ Inferno  │ │
│  │              │  │              │  │   OS     │ │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────┐ │ │
│  │ │Worker 1-N│ │  │ │Worker N+1│ │  │ │Worker│ │ │
│  │ │Dis VMs   │ │  │ │Dis VMs   │ │  │ │...   │ │ │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────┘ │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│         │                  │                │      │
│         └──────────────────┴────────────────┘      │
│                           │                        │
└───────────────────────────┼────────────────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │  Load Balancer  │
                   │  Orchestrator   │
                   └─────────────────┘
```

## Scaling Example

```
Initial Deployment (100 nodes):
├── Throughput: ~1,000 tok/s
├── Latency: 50ms
└── Utilization: 30%

Scale Up Event (utilization > 80%):
├── Spawn: +500 nodes
├── New throughput: ~6,000 tok/s
├── New latency: 45ms
└── New utilization: 50%

Scale Down Event (utilization < 20%):
├── Shutdown: -200 nodes
├── New throughput: ~4,000 tok/s
├── New latency: 47ms
└── New utilization: 40%
```

## Monitoring Dashboard (Conceptual)

```
┌─────────────────────────────────────────────────────────────┐
│              LLAMBO CLUSTER MONITORING                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Active Nodes: 1000/10000        Status: ✓ HEALTHY         │
│  Throughput: 10,234 tok/s        Latency: 45ms             │
│  Utilization: 67%                Uptime: 99.98%            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Node Distribution:                                  │    │
│  │ ████████████████████ Tiny (750)     75%            │    │
│  │ █████ Medium (200)                   20%            │    │
│  │ ██ Large (50)                        5%             │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Recent Activity:                                           │
│  • 12:34:56 - Spawned 50 new tiny nodes                    │
│  • 12:30:15 - Load spike detected, scaling up              │
│  • 12:25:03 - All health checks passed                     │
│  • 12:20:45 - Node worker-0742 recovered from error        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```
