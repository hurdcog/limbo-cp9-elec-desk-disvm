implement Llambotest;

include "sys.m";
	sys: Sys;
	print: import sys;

include "draw.m";

include "llambo.m";
	llambo: Llambo;
	Model, Context, InferenceRequest, Orchestrator: import llambo;

Llambotest: module
{
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

init(ctxt: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	llambo = load Llambo Llambo->PATH;
	
	if (llambo == nil) {
		print("llambotest: cannot load Llambo module\n");
		return;
	}
	
	# Initialize llambo
	llambo->init(ctxt, nil);
	
	print("\n=== Llambo Distributed Cognition Test ===\n\n");
	
	# Test 1: Single inference
	print("Test 1: Single Inference\n");
	print("-------------------------\n");
	test_single_inference();
	print("\n");
	
	# Test 2: Distributed cluster
	print("Test 2: Distributed Cluster with Load Balancing\n");
	print("------------------------------------------------\n");
	test_distributed_cluster();
	print("\n");
	
	# Test 3: Massive parallel processing
	print("Test 3: Massive Parallel Processing (1000 nodes)\n");
	print("------------------------------------------------\n");
	test_massive_parallel();
	print("\n");
	
	print("=== All Tests Complete ===\n");
}

test_single_inference()
{
	# Load model
	model := llambo->Model.load("/models/llama-7b.gguf", nil);
	if (model == nil) {
		print("ERROR: Failed to load model\n");
		return;
	}
	
	# Create context
	ctx := llambo->Context.new(model, 2048, 512, 4);
	if (ctx == nil) {
		print("ERROR: Failed to create context\n");
		return;
	}
	
	# Create inference request
	req := ref InferenceRequest;
	req.prompt = "What is the meaning of distributed cognition?";
	req.max_tokens = 128;
	req.temperature = 0.7;
	req.top_p = 0.9;
	req.ctx = ctx;
	
	# Process
	print("Processing prompt: \"" + req.prompt + "\"\n");
	response := llambo->infer(req);
	
	if (response != nil) {
		print("Response: " + response.text + "\n");
		print("Tokens: " + string response.token_count + "\n");
		print("Time: " + string response.completion_time + "ms\n");
	} else {
		print("ERROR: No response\n");
	}
	
	# Cleanup
	ctx.free();
	model.free();
}

test_distributed_cluster()
{
	# Create orchestrator with 10 nodes, least-loaded strategy
	orch := llambo->Orchestrator.new(10, 1);
	if (orch == nil) {
		print("ERROR: Failed to create orchestrator\n");
		return;
	}
	
	# Spawn cluster
	spawned := orch.spawn_cluster(10, "/models/llama-7b.gguf");
	print("Spawned " + string spawned + " cluster nodes\n\n");
	
	# Process multiple requests through the cluster
	prompts := array[] of {
		"Explain quantum computing",
		"What is machine learning?",
		"Describe neural networks",
		"What is deep learning?",
		"Explain transformers"
	};
	
	for (i := 0; i < len prompts; i++) {
		print("Request " + string (i+1) + ": " + prompts[i] + "\n");
		response := orch.process(prompts[i], 64);
		
		if (response != nil) {
			print("  Response time: " + string response.completion_time + "ms\n");
			print("  Tokens: " + string response.token_count + "\n");
		}
	}
	
	# Show status
	print("\n" + orch.status() + "\n");
	
	# Shutdown
	orch.shutdown_cluster();
	print("Cluster shutdown complete\n");
}

test_massive_parallel()
{
	# Create orchestrator for 1000 nodes
	orch := llambo->Orchestrator.new(1000, 2);  # random strategy
	if (orch == nil) {
		print("ERROR: Failed to create orchestrator\n");
		return;
	}
	
	# Spawn massive cluster
	spawned := orch.spawn_cluster(1000, "/models/llama-7b.gguf");
	print("Spawned " + string spawned + " tiny inference engines\n");
	print("Total cluster capacity: " + string (spawned * 100) + " inference units\n\n");
	
	# Simulate distributed cognition with parallel requests
	total_requests := 100;
	total_time := 0;
	
	print("Processing " + string total_requests + " parallel requests...\n");
	
	for (i := 0; i < total_requests; i++) {
		prompt := "Process cognitive unit " + string i;
		response := orch.process(prompt, 32);
		
		if (response != nil) {
			total_time += response.completion_time;
			
			if (i % 20 == 0)
				print("  Processed " + string i + "/" + string total_requests + "\n");
		}
	}
	
	avg_time := total_time / total_requests;
	print("\nProcessing complete!\n");
	print("  Total requests: " + string total_requests + "\n");
	print("  Average time: " + string avg_time + "ms\n");
	print("  Total cluster time: " + string total_time + "ms\n");
	
	# Show final status
	print("\nFinal " + orch.status() + "\n");
	
	# Shutdown
	orch.shutdown_cluster();
	print("Massive cluster shutdown complete\n");
}
