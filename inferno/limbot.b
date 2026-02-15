implement Limbot;

# Limbot: AI Chat Assistant CLI for Llambo
# Interactive chat interface with conversation history and streaming

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

include "daytime.m";
	daytime: Daytime;

include "llambo.m";
	llambo: Llambo;
	Orchestrator, InferenceRequest, InferenceResponse: import llambo;

Limbot: module {
	init: fn(ctxt: ref Context, argv: list of string);
};

# Configuration
CONFIG_FILE: con "/usr/llambo/limbot.conf";
HISTORY_FILE: con "/usr/llambo/limbot-history.txt";
MAX_HISTORY: con 50;

# Chat session state
ConversationEntry: adt {
	role: string;      # "user" or "assistant"
	content: string;
	timestamp: int;
};

Session: adt {
	history: array of ref ConversationEntry;
	count: int;
	system_prompt: string;
	
	new: fn(): ref Session;
	add: fn(s: self ref Session, role: string, content: string);
	build_context: fn(s: self ref Session): string;
	save_history: fn(s: self ref Session);
	load_history: fn(s: self ref Session);
};

# Global state
orch: ref Orchestrator;
session: ref Session;
interactive_mode: int;
one_shot_mode: int;

init(ctxt: ref Context, argv: list of string)
{
	# Load required modules
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	daytime = load Daytime Daytime->PATH;
	llambo = load Llambo Llambo->PATH;
	
	if (llambo == nil) {
		print("Failed to load Llambo module\n");
		raise "fail:load";
	}
	
	llambo->init(ctxt, nil);
	
	# Parse command line arguments
	(mode, prompt) := parse_args(argv);
	
	if (mode == "help") {
		show_help();
		return;
	}
	
	# Initialize chat session
	session = Session.new();
	session.load_history();
	
	# Initialize cluster orchestrator
	print("Initializing Limbot...\n");
	initialize_cluster();
	
	if (mode == "interactive") {
		interactive_chat();
	} else if (mode == "oneshot") {
		oneshot_inference(prompt);
	}
	
	# Cleanup
	session.save_history();
	if (orch != nil)
		orch.shutdown_cluster();
}

# Parse command line arguments
parse_args(argv: list of string): (string, string)
{
	# Skip program name
	if (argv != nil)
		argv = tl argv;
	
	if (argv == nil)
		return ("interactive", "");
	
	arg := hd argv;
	
	if (arg == "-h" || arg == "--help" || arg == "help")
		return ("help", "");
	
	if (arg == "-i" || arg == "--interactive")
		return ("interactive", "");
	
	# If arguments provided, treat as one-shot prompt
	prompt := str->join(argv, " ");
	return ("oneshot", prompt);
}

# Initialize distributed cluster
initialize_cluster()
{
	# Create orchestrator with cluster
	max_nodes := 100;  # Limited cluster size for chat responsiveness
	strategy := 1;     # least-loaded
	
	print("Starting distributed cluster (%d nodes)...\n", max_nodes);
	orch = llambo->Orchestrator.new(max_nodes, strategy);
	
	node_count := orch.spawn_cluster(max_nodes, "/models/llama-7b.gguf");
	print("Cluster ready: %d nodes active\n\n", node_count);
}

# Interactive chat loop
interactive_chat()
{
	print("╔════════════════════════════════════════════════════════╗\n");
	print("║          Limbot - AI Chat Assistant CLI               ║\n");
	print("║        Powered by Distributed Llambo Cluster          ║\n");
	print("╚════════════════════════════════════════════════════════╝\n\n");
	
	print("Type your message and press Enter. Commands:\n");
	print("  /help    - Show help\n");
	print("  /history - Show conversation history\n");
	print("  /clear   - Clear conversation history\n");
	print("  /status  - Show cluster status\n");
	print("  /exit    - Exit limbot\n\n");
	
	stdin := bufio->fopen(sys->fildes(0), Bufio->OREAD);
	if (stdin == nil) {
		print("Failed to open stdin\n");
		return;
	}
	
	for (;;) {
		print("\n\033[1;36mYou:\033[0m ");
		
		line := stdin.gets('\n');
		if (line == nil)
			break;
		
		# Remove trailing newline
		if (len line > 0 && line[len line - 1] == '\n')
			line = line[0:len line - 1];
		
		if (len line == 0)
			continue;
		
		# Check for commands
		if (line[0] == '/') {
			if (!process_command(line))
				break;
			continue;
		}
		
		# Add user message to session
		session.add("user", line);
		
		# Get AI response
		get_ai_response(line);
	}
	
	print("\nGoodbye!\n");
}

# Process chat commands
process_command(cmd: string): int
{
	case cmd {
		"/help" =>
			print("\nLimbot Commands:\n");
			print("  /help    - Show this help\n");
			print("  /history - Show conversation history\n");
			print("  /clear   - Clear conversation history\n");
			print("  /status  - Show cluster status\n");
			print("  /exit    - Exit limbot\n");
		
		"/history" =>
			show_history();
		
		"/clear" =>
			session.count = 0;
			print("\nConversation history cleared.\n");
		
		"/status" =>
			if (orch != nil) {
				status := orch.status();
				print("\n%s\n", status);
			} else {
				print("\nCluster not initialized.\n");
			}
		
		"/exit" or "/quit" =>
			return 0;
		
		* =>
			print("\nUnknown command: %s\n", cmd);
			print("Type /help for available commands.\n");
	}
	
	return 1;
}

# Show conversation history
show_history()
{
	print("\n--- Conversation History ---\n");
	
	if (session.count == 0) {
		print("(No conversation history)\n");
		return;
	}
	
	for (i := 0; i < session.count; i++) {
		entry := session.history[i];
		if (entry.role == "user") {
			print("\n\033[1;36mYou:\033[0m %s\n", entry.content);
		} else {
			print("\n\033[1;32mLimbot:\033[0m %s\n", entry.content);
		}
	}
	
	print("\n--- End of History ---\n");
}

# Get AI response with streaming display
get_ai_response(prompt: string)
{
	print("\n\033[1;32mLimbot:\033[0m ");
	
	# Build context from conversation history
	context := session.build_context();
	full_prompt := context + "\nUser: " + prompt + "\nAssistant:";
	
	# Get response from cluster
	response := orch.process(full_prompt, 256);
	
	if (response == nil) {
		print("\n[Error: Inference failed]\n");
		return;
	}
	
	# Display response with streaming effect (simulated)
	text := response.text;
	display_streaming(text);
	
	# Add to session history
	session.add("assistant", text);
	
	print("\n\033[0;90m[%d tokens, %d ms]\033[0m\n",
		response.token_count, response.completion_time);
}

# Display text with streaming effect
display_streaming(text: string)
{
	# Simple streaming simulation - print character by character
	for (i := 0; i < len text; i++) {
		sys->fprint(fildes(1), "%c", text[i]);
		
		# Small delay for streaming effect (every few chars)
		if (i % 5 == 0)
			sys->sleep(10);  # 10ms delay
	}
	
	sys->fprint(fildes(1), "\n");
}

# One-shot inference mode
oneshot_inference(prompt: string)
{
	if (prompt == "") {
		print("Error: No prompt provided\n");
		return;
	}
	
	print("Limbot: ");
	
	response := orch.process(prompt, 256);
	
	if (response == nil) {
		print("Error: Inference failed\n");
		return;
	}
	
	print("%s\n", response.text);
}

# Show help
show_help()
{
	print("\nLimbot - AI Chat Assistant CLI for Llambo\n\n");
	print("Usage:\n");
	print("  limbot                  Start interactive chat\n");
	print("  limbot -i               Start interactive chat (explicit)\n");
	print("  limbot <prompt>         One-shot inference\n");
	print("  limbot -h, --help       Show this help\n\n");
	print("Interactive Commands:\n");
	print("  /help                   Show help\n");
	print("  /history                Show conversation history\n");
	print("  /clear                  Clear history\n");
	print("  /status                 Show cluster status\n");
	print("  /exit                   Exit limbot\n\n");
	print("Examples:\n");
	print("  limbot\n");
	print("  limbot What is machine learning?\n");
	print("  limbot Explain neural networks\n\n");
}

# Session ADT implementation
Session.new(): ref Session
{
	s := ref Session;
	s.history = array[MAX_HISTORY] of ref ConversationEntry;
	s.count = 0;
	s.system_prompt = "You are Limbot, a helpful AI assistant running on a distributed Llambo cluster.";
	return s;
}

Session.add(s: self ref Session, role: string, content: string)
{
	if (s.count >= MAX_HISTORY) {
		# Shift history to make room
		for (i := 0; i < MAX_HISTORY - 1; i++)
			s.history[i] = s.history[i + 1];
		s.count = MAX_HISTORY - 1;
	}
	
	entry := ref ConversationEntry;
	entry.role = role;
	entry.content = content;
	entry.timestamp = daytime->now();
	
	s.history[s.count] = entry;
	s.count++;
}

Session.build_context(s: self ref Session): string
{
	context := s.system_prompt;
	
	# Include recent conversation history (last 10 exchanges)
	start := 0;
	if (s.count > 20)  # 10 user + 10 assistant
		start = s.count - 20;
	
	for (i := start; i < s.count; i++) {
		entry := s.history[i];
		if (entry.role == "user")
			context += "\nUser: " + entry.content;
		else
			context += "\nAssistant: " + entry.content;
	}
	
	return context;
}

Session.save_history(s: self ref Session)
{
	fd := sys->create(HISTORY_FILE, Sys->OWRITE, 8r644);
	if (fd == nil)
		return;
	
	for (i := 0; i < s.count; i++) {
		entry := s.history[i];
		fprint(fd, "%s|%d|%s\n", entry.role, entry.timestamp, entry.content);
	}
}

Session.load_history(s: self ref Session)
{
	fd := sys->open(HISTORY_FILE, Sys->OREAD);
	if (fd == nil)
		return;
	
	bio := bufio->fopen(fd, Bufio->OREAD);
	if (bio == nil)
		return;
	
	s.count = 0;
	
	for (;;) {
		line := bio.gets('\n');
		if (line == nil)
			break;
		
		# Parse: role|timestamp|content
		(n, parts) := sys->tokenize(line, "|");
		if (n < 3)
			continue;
		
		role := hd parts;
		parts = tl parts;
		timestamp_str := hd parts;
		parts = tl parts;
		content := str->join(parts, "|");
		
		# Remove trailing newline
		if (len content > 0 && content[len content - 1] == '\n')
			content = content[0:len content - 1];
		
		s.add(role, content);
		
		if (s.count >= MAX_HISTORY)
			break;
	}
}
