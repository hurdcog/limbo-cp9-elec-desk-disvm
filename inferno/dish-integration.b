implement DishIntegration;

# Inferno Dish (Distributed Shell) Integration for Llambo
# Provides interactive shell access to distributed llama.cpp cluster

include "sys.m";
	sys: Sys;
	print, fprint, sprint, fildes: import sys;

include "draw.m";
	draw: Draw;
	Context: import draw;

include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;

include "string.m";
	str: String;

include "llambo.m";
	llambo: Llambo;
	Orchestrator, InferenceRequest, InferenceResponse: import llambo;

DishIntegration: module {
	init: fn(ctxt: ref Context, argv: list of string);
};

# Dish namespace paths
DISH_NS: con "/n/dish";
LLAMBO_NS: con "/n/llambo";
CTL_FILE: con "/n/llambo/ctl";
DATA_FILE: con "/n/llambo/data";
STATUS_FILE: con "/n/llambo/status";

# Global orchestrator instance
orch: ref Orchestrator;
max_nodes_global: int;

init(ctxt: ref Context, argv: list of string)
{
	# Load required modules
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	llambo = load Llambo Llambo->PATH;
	
	if (llambo == nil) {
		print("Failed to load Llambo module\n");
		raise "fail:load";
	}
	
	llambo->init(ctxt, nil);
	
	print("=== Llambo Dish Integration ===\n");
	print("Distributed Shell for Llama.cpp Cluster\n\n");
	
	# Setup namespaces for distributed shell
	setup_namespaces();
	
	# Initialize orchestrator with distributed cluster
	max_nodes := 1000;
	max_nodes_global = max_nodes;
	strategy := 1; # least-loaded
	orch = llambo->Orchestrator.new(max_nodes, strategy);
	
	print("Spawning distributed cluster (this may take a moment)...\n");
	node_count := orch.spawn_cluster(100, "/models/llama-7b.gguf");
	print("Cluster ready: %d nodes active\n", node_count);
	
	# Mount cluster control interface to dish namespace
	mount_cluster_interface();
	
	# Start interactive shell loop
	interactive_shell();
	
	# Cleanup on exit
	print("\nShutting down cluster...\n");
	orch.shutdown_cluster();
}

# Setup Inferno namespaces for distributed shell access
setup_namespaces()
{
	print("Setting up distributed shell namespaces...\n");
	
	# Create namespace directories
	sys->create(DISH_NS, Sys->OREAD, 8r755 | Sys->DMDIR);
	sys->create(LLAMBO_NS, Sys->OREAD, 8r755 | Sys->DMDIR);
	
	print("  %s -> mounted\n", DISH_NS);
	print("  %s -> mounted\n", LLAMBO_NS);
}

# Mount cluster control interface to namespace
mount_cluster_interface()
{
	print("Mounting cluster control files...\n");
	
	# Create control files for Styx protocol access
	fd := sys->create(CTL_FILE, Sys->OWRITE, 8r644);
	if (fd != nil) {
		fprint(fd, "cluster:ready\n");
		print("  %s -> ready\n", CTL_FILE);
	}
	
	fd = sys->create(STATUS_FILE, Sys->OWRITE, 8r644);
	if (fd != nil) {
		status := orch.status();
		fprint(fd, "%s\n", status);
		print("  %s -> ready\n", STATUS_FILE);
	}
	
	fd = sys->create(DATA_FILE, Sys->OWRITE, 8r644);
	if (fd != nil) {
		print("  %s -> ready\n", DATA_FILE);
	}
}

# Interactive shell loop
interactive_shell()
{
	stdin := bufio->fopen(sys->fildes(0), Bufio->OREAD);
	if (stdin == nil) {
		print("Failed to open stdin\n");
		return;
	}
	
	print("\nDistributed Shell Ready. Type 'help' for commands.\n");
	print("llambo> ");
	
	for (;;) {
		line := stdin.gets('\n');
		if (line == nil)
			break;
		
		# Remove trailing newline
		if (len line > 0 && line[len line - 1] == '\n')
			line = line[0:len line - 1];
		
		if (len line == 0) {
			print("llambo> ");
			continue;
		}
		
		# Process command
		process_command(line);
		
		print("llambo> ");
	}
}

# Process shell commands
process_command(cmd: string)
{
	# Parse command
	(n, args) := sys->tokenize(cmd, " \t");
	if (n == 0)
		return;
	
	command := hd args;
	args = tl args;
	
	case command {
		"help" or "?" =>
			show_help();
		
		"status" =>
			show_status();
		
		"nodes" =>
			show_nodes();
		
		"infer" or "ask" =>
			if (args == nil) {
				print("Usage: infer <prompt>\n");
			} else {
				prompt := str->join(args, " ");
				do_inference(prompt);
			}
		
		"cluster" =>
			cluster_commands(args);
		
		"exit" or "quit" =>
			raise "break";
		
		* =>
			# Treat unknown command as inference prompt
			prompt := str->join(command :: args, " ");
			do_inference(prompt);
	}
}

# Show help message
show_help()
{
	print("\nLlambo Distributed Shell Commands:\n");
	print("  help, ?              Show this help\n");
	print("  status               Show cluster status\n");
	print("  nodes                List cluster nodes\n");
	print("  infer <prompt>       Run inference on prompt\n");
	print("  ask <prompt>         Alias for infer\n");
	print("  cluster <cmd>        Cluster management commands\n");
	print("  exit, quit           Exit shell\n");
	print("\nOr just type your prompt directly!\n\n");
}

# Show cluster status
show_status()
{
	status := orch.status();
	print("\n%s\n\n", status);
}

# Show cluster nodes
show_nodes()
{
	print("\nCluster nodes: (distributed across Dis VM instances)\n");
	print("Note: Use 'llamboctl nodes list' for detailed node information\n\n");
}

# Perform inference using cluster
do_inference(prompt: string)
{
	if (orch == nil) {
		print("Error: Cluster not initialized\n");
		return;
	}
	
	print("\n[Distributing inference across cluster...]\n");
	
	# Process through orchestrator (automatically load-balanced)
	response := orch.process(prompt, 128);
	
	if (response == nil) {
		print("Error: Inference failed\n");
		return;
	}
	
	print("\n%s\n\n", response.text);
	print("[Inference completed in %d ms, %d tokens]\n\n",
		response.completion_time, response.token_count);
}

# Cluster management commands
cluster_commands(args: list of string)
{
	if (args == nil) {
		print("Cluster commands: info, spawn, shutdown\n");
		return;
	}
	
	cmd := hd args;
	args = tl args;
	
	case cmd {
		"info" =>
			print("\nCluster Information:\n");
			print("  Max Nodes: %d\n", max_nodes_global);
			print("  Strategy: least-loaded\n");
			print("  Type: Distributed Dis VM instances\n\n");
		
		"spawn" =>
			print("Use 'llamboctl spawn' for node management\n");
		
		"shutdown" =>
			print("Use 'exit' to shutdown cluster and exit shell\n");
		
		* =>
			print("Unknown cluster command: %s\n", cmd);
	}
}
