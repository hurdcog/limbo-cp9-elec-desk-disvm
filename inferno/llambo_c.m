Llambo_c: module
{
	PATH: con "$Llambo_c";

	#
	# FFI C Module for llama.cpp integration
	# This module provides native bindings to the llama.cpp C library
	# for high-performance LLM inference in Inferno OS.
	#
	# Usage:
	#   include "llambo_c.m";
	#   llambo_c := load Llambo_c Llambo_c->PATH;
	#
	#   # Load model
	#   model_id := llambo_c->load_model("/models/llama-7b.gguf", 1, 0);
	#   
	#   # Run inference
	#   result := llambo_c->infer(model_id, "Hello, world!", 128, 0.8);
	#   
	#   # Free model
	#   llambo_c->free_model(model_id);
	#

	# FFI Function: Load a llama.cpp model from file
	# 
	# Parameters:
	#   path: Full path to the model file (.gguf format)
	#   use_mmap: 1 to use memory mapping, 0 otherwise
	#   n_gpu_layers: Number of layers to offload to GPU (0 for CPU only)
	#
	# Returns:
	#   model_id >= 0 on success, -1 on failure
	#
	# External C binding: llama_load_model()
	load_model: fn(path: string, use_mmap: int, n_gpu_layers: int): int;

	# FFI Function: Free a loaded model
	#
	# Parameters:
	#   model_id: ID of the model to free (from load_model)
	#
	# Returns:
	#   0 on success, -1 on failure
	#
	# External C binding: llama_free_model()
	free_model: fn(model_id: int): int;

	# FFI Function: Tokenize input text
	#
	# Parameters:
	#   model_id: ID of the loaded model
	#   text: Input text to tokenize
	#
	# Returns:
	#   Array of token IDs, nil on failure
	#
	# External C binding: llama_tokenize()
	tokenize: fn(model_id: int, text: string): array of int;

	# FFI Function: Perform inference with llama.cpp
	#
	# Parameters:
	#   model_id: ID of the loaded model
	#   prompt: Input prompt text
	#   max_tokens: Maximum number of tokens to generate
	#   temperature: Sampling temperature (0.0 = deterministic, higher = more random)
	#
	# Returns:
	#   Generated text string
	#
	# External C binding: llama_infer()
	infer: fn(model_id: int, prompt: string, max_tokens: int, temperature: real): string;

	# FFI Function: Get model information
	#
	# Parameters:
	#   model_id: ID of the loaded model
	#
	# Returns:
	#   JSON string with model information (vocab size, context size, etc.)
	#
	# External C binding: llama_get_model_info()
	get_model_info: fn(model_id: int): string;
};
