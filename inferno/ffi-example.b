implement FFIExample;

#
# Example: Using Llambo FFI for High-Performance Inference
#
# This example demonstrates:
# 1. Loading the FFI module
# 2. Loading a model
# 3. Running inference
# 4. Proper cleanup
#
# Usage:
#   limbo -o ffi-example.dis ffi-example.b
#   /dis/ffi-example.dis /path/to/model.gguf "Your prompt here"
#

include "sys.m";
	sys: Sys;
	print: import sys;

include "draw.m";

include "llambo_c.m";
	llambo_c: Llambo_c;

FFIExample: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	
	# Parse arguments
	args = tl args;  # Skip program name
	
	if (args == nil || tl args == nil) {
		print("Usage: ffi-example <model_path> <prompt>\n");
		print("\n");
		print("Example:\n");
		print("  ffi-example /models/llama-7b.gguf \"What is AI?\"\n");
		return;
	}
	
	model_path := hd args;
	prompt := hd tl args;
	
	print("Llambo FFI Example\n");
	print("==================\n\n");
	
	# Step 1: Load FFI module
	print("1. Loading FFI module...\n");
	llambo_c = load Llambo_c Llambo_c->PATH;
	
	if (llambo_c == nil) {
		print("ERROR: Failed to load FFI module\n");
		print("\nThe FFI module is not available. This could mean:\n");
		print("  - FFI module not built (run './build-ffi.sh build')\n");
		print("  - Module not installed in $INFERNO_ROOT/libinterp/\n");
		print("  - Inferno not configured correctly\n");
		return;
	}
	
	print("   ✓ FFI module loaded\n\n");
	
	# Step 2: Load model
	print("2. Loading model: %s\n", model_path);
	
	# Parameters:
	#   use_mmap = 1 (use memory mapping for faster loading)
	#   n_gpu_layers = 0 (CPU only; set > 0 for GPU offloading)
	model_id := llambo_c->load_model(model_path, 1, 0);
	
	if (model_id < 0) {
		print("ERROR: Failed to load model\n");
		print("\nPossible causes:\n");
		print("  - Model file not found or not readable\n");
		print("  - Model format incompatible (use .gguf format)\n");
		print("  - Insufficient memory for model\n");
		print("  - Too many models loaded (max 32)\n");
		return;
	}
	
	print("   ✓ Model loaded (ID: %d)\n\n", model_id);
	
	# Step 3: Get model information
	print("3. Model information:\n");
	info := llambo_c->get_model_info(model_id);
	print("   %s\n\n", info);
	
	# Step 4: Run inference
	print("4. Running inference...\n");
	print("   Prompt: \"%s\"\n", prompt);
	
	# Parameters:
	#   max_tokens = 128 (generate up to 128 tokens)
	#   temperature = 0.8 (balance between deterministic and creative)
	max_tokens := 128;
	temperature := 0.8;
	
	start_time := sys->millisec();
	result := llambo_c->infer(model_id, prompt, max_tokens, temperature);
	elapsed := sys->millisec() - start_time;
	
	if (result == nil || result == "") {
		print("ERROR: Inference failed\n");
	} else {
		print("\n   Generated text:\n");
		print("   ===============\n");
		print("   %s\n", result);
		print("   ===============\n\n");
		
		# Calculate stats
		tokens_generated := len result / 4;  # Rough estimate
		tokens_per_sec := 0.0;
		if (elapsed > 0)
			tokens_per_sec = real tokens_generated * 1000.0 / real elapsed;
		
		print("   Stats:\n");
		print("     Time: %d ms\n", elapsed);
		print("     Est. tokens: ~%d\n", tokens_generated);
		print("     Speed: ~%.1f tok/s\n", tokens_per_sec);
	}
	
	# Step 5: Cleanup
	print("\n5. Cleaning up...\n");
	ret := llambo_c->free_model(model_id);
	
	if (ret < 0) {
		print("WARNING: Failed to free model\n");
	} else {
		print("   ✓ Model freed\n");
	}
	
	print("\nDone!\n");
}
