/*
 * Llambo C Module - FFI bindings for llama.cpp in Inferno OS
 * 
 * This module provides native C bindings to llama.cpp for the Limbo language.
 * It implements the core inference functionality as a builtin Inferno module.
 */

#include <lib9.h>
#include <isa.h>
#include <interp.h>
#include "runt.h"
#include "llambo_c.h"

/* Include llama.cpp headers */
#include "llama.h"

/*
 * Global state for llama.cpp models
 */
typedef struct LlamaModel {
	llama_model *model;
	llama_context *ctx;
	char *path;
	int ref_count;
} LlamaModel;

static LlamaModel *models[32];  /* Max 32 concurrent models */
static int nmodels = 0;

/*
 * Helper function to create Limbo strings
 */
static String*
mkstring(char *s)
{
	String *str;
	if (s == nil)
		s = "";
	str = newstring(strlen(s));
	if (str != nil)
		memmove(str->data, s, str->len);
	return str;
}

/*
 * llama_load_model: Load a llama.cpp model
 * Limbo signature: load_model(path: string, use_mmap: int, n_gpu_layers: int): int
 * Returns: model_id (>= 0) on success, -1 on failure
 */
static Word*
llama_load_model(Exec *e, Module *m, Word *args, uchar *ip)
{
	String *path;
	int use_mmap, n_gpu_layers;
	llama_model_params model_params;
	llama_context_params ctx_params;
	LlamaModel *lm;
	int model_id;

	path = args[0].t.s;
	use_mmap = args[1].t.i;
	n_gpu_layers = args[2].t.i;

	if (path == nil || nmodels >= 32)
		return (Word*)(vlong)-1;

	/* Initialize llama.cpp backend */
	llama_backend_init();

	/* Set model parameters */
	model_params = llama_model_default_params();
	model_params.use_mmap = use_mmap;
	model_params.n_gpu_layers = n_gpu_layers;

	/* Load model */
	lm = malloc(sizeof(LlamaModel));
	if (lm == nil)
		return (Word*)(vlong)-1;

	lm->path = strdup(string2c(path));
	lm->model = llama_load_model_from_file(lm->path, model_params);
	if (lm->model == nil) {
		free(lm->path);
		free(lm);
		return (Word*)(vlong)-1;
	}

	/* Create context */
	ctx_params = llama_context_default_params();
	ctx_params.n_ctx = 2048;
	ctx_params.n_batch = 512;
	ctx_params.n_threads = 4;

	lm->ctx = llama_new_context_with_model(lm->model, ctx_params);
	if (lm->ctx == nil) {
		llama_free_model(lm->model);
		free(lm->path);
		free(lm);
		return (Word*)(vlong)-1;
	}

	lm->ref_count = 1;
	model_id = nmodels;
	models[nmodels++] = lm;

	return (Word*)(vlong)model_id;
}

/*
 * llama_free_model: Free a loaded model
 * Limbo signature: free_model(model_id: int): int
 * Returns: 0 on success, -1 on failure
 */
static Word*
llama_free_model(Exec *e, Module *m, Word *args, uchar *ip)
{
	int model_id;
	LlamaModel *lm;

	model_id = args[0].t.i;
	if (model_id < 0 || model_id >= nmodels)
		return (Word*)(vlong)-1;

	lm = models[model_id];
	if (lm == nil)
		return (Word*)(vlong)-1;

	lm->ref_count--;
	if (lm->ref_count <= 0) {
		if (lm->ctx != nil)
			llama_free(lm->ctx);
		if (lm->model != nil)
			llama_free_model(lm->model);
		if (lm->path != nil)
			free(lm->path);
		free(lm);
		models[model_id] = nil;
	}

	return (Word*)(vlong)0;
}

/*
 * llama_tokenize: Tokenize input text
 * Limbo signature: tokenize(model_id: int, text: string): array of int
 * Returns: array of token IDs
 */
static Word*
llama_tokenize(Exec *e, Module *m, Word *args, uchar *ip)
{
	int model_id;
	String *text;
	LlamaModel *lm;
	int *tokens;
	int n_tokens;
	Array *result;

	model_id = args[0].t.i;
	text = args[1].t.s;

	if (model_id < 0 || model_id >= nmodels || text == nil)
		return H;

	lm = models[model_id];
	if (lm == nil || lm->ctx == nil)
		return H;

	/* Allocate token buffer */
	tokens = malloc(sizeof(int) * 4096);
	if (tokens == nil)
		return H;

	/* Tokenize */
	n_tokens = llama_tokenize(lm->model, string2c(text), strlen(string2c(text)), 
	                          tokens, 4096, 1, 0);

	if (n_tokens < 0) {
		free(tokens);
		return H;
	}

	/* Create Limbo array */
	result = mem2array(tokens, n_tokens * sizeof(int));
	free(tokens);

	return (Word*)result;
}

/*
 * llama_infer: Perform inference on input tokens
 * Limbo signature: infer(model_id: int, prompt: string, max_tokens: int, temperature: real): string
 * Returns: generated text
 */
static Word*
llama_infer(Exec *e, Module *m, Word *args, uchar *ip)
{
	int model_id, max_tokens;
	String *prompt;
	double temperature;
	LlamaModel *lm;
	int *tokens;
	int n_tokens, n_past, n_gen;
	char *result_str;
	int result_len;
	String *result;

	model_id = args[0].t.i;
	prompt = args[1].t.s;
	max_tokens = args[2].t.i;
	temperature = args[3].t.r;

	if (model_id < 0 || model_id >= nmodels || prompt == nil)
		return (Word*)mkstring("");

	lm = models[model_id];
	if (lm == nil || lm->ctx == nil)
		return (Word*)mkstring("");

	/* Tokenize input */
	tokens = malloc(sizeof(int) * (4096 + max_tokens));
	if (tokens == nil)
		return (Word*)mkstring("");

	n_tokens = llama_tokenize(lm->model, string2c(prompt), strlen(string2c(prompt)),
	                          tokens, 4096, 1, 0);

	if (n_tokens < 0) {
		free(tokens);
		return (Word*)mkstring("");
	}

	/* Inference loop */
	n_past = 0;
	n_gen = 0;
	result_str = malloc(8192);
	result_len = 0;

	if (result_str == nil) {
		free(tokens);
		return (Word*)mkstring("");
	}

	/* Evaluate prompt tokens */
	if (llama_decode(lm->ctx, llama_batch_get_one(tokens, n_tokens, n_past, 0))) {
		free(tokens);
		free(result_str);
		return (Word*)mkstring("");
	}

	n_past += n_tokens;

	/* Generate tokens */
	while (n_gen < max_tokens) {
		llama_token new_token;
		float *logits;
		const char *token_str;
		int token_len;

		/* Get logits and sample */
		logits = llama_get_logits_ith(lm->ctx, -1);
		if (logits == nil)
			break;

		/* Simple greedy sampling (can be enhanced with temperature) */
		new_token = 0;
		float max_logit = logits[0];
		for (int i = 1; i < llama_n_vocab(lm->model); i++) {
			if (logits[i] > max_logit) {
				max_logit = logits[i];
				new_token = i;
			}
		}

		/* Check for EOS */
		if (llama_token_is_eog(lm->model, new_token))
			break;

		/* Convert token to text */
		token_str = llama_token_to_piece(lm->ctx, new_token, &token_len);
		if (token_str != nil && result_len + token_len < 8192) {
			memcpy(result_str + result_len, token_str, token_len);
			result_len += token_len;
		}

		/* Prepare next iteration */
		tokens[0] = new_token;
		if (llama_decode(lm->ctx, llama_batch_get_one(tokens, 1, n_past, 0)))
			break;

		n_past++;
		n_gen++;
	}

	result_str[result_len] = '\0';
	result = mkstring(result_str);

	free(tokens);
	free(result_str);

	return (Word*)result;
}

/*
 * llama_get_model_info: Get information about a loaded model
 * Limbo signature: get_model_info(model_id: int): string
 * Returns: JSON string with model information
 */
static Word*
llama_get_model_info(Exec *e, Module *m, Word *args, uchar *ip)
{
	int model_id;
	LlamaModel *lm;
	char info[512];
	int n_vocab, n_ctx;

	model_id = args[0].t.i;

	if (model_id < 0 || model_id >= nmodels)
		return (Word*)mkstring("");

	lm = models[model_id];
	if (lm == nil || lm->model == nil)
		return (Word*)mkstring("");

	n_vocab = llama_n_vocab(lm->model);
	n_ctx = llama_n_ctx(lm->ctx);

	snprintf(info, sizeof(info),
	         "{\"model_id\": %d, \"path\": \"%s\", \"n_vocab\": %d, \"n_ctx\": %d, \"ref_count\": %d}",
	         model_id, lm->path, n_vocab, n_ctx, lm->ref_count);

	return (Word*)mkstring(info);
}

/*
 * Module function table
 */
static Moduledata Llambo_cmodtab[] = {
	{ "load_model", llama_load_model },
	{ "free_model", llama_free_model },
	{ "tokenize", llama_tokenize },
	{ "infer", llama_infer },
	{ "get_model_info", llama_get_model_info },
};

/*
 * Module initialization
 */
void
llambo_cmodinit(void)
{
	int i;

	/* Initialize model array */
	for (i = 0; i < 32; i++)
		models[i] = nil;
	nmodels = 0;

	/* Register module with Inferno VM */
	builtinmod("$Llambo_c", Llambo_cmodtab, nelem(Llambo_cmodtab));
}

/*
 * Module cleanup (called on shutdown)
 */
void
llambo_cmodcleanup(void)
{
	int i;
	LlamaModel *lm;

	/* Free all loaded models */
	for (i = 0; i < nmodels; i++) {
		lm = models[i];
		if (lm != nil) {
			if (lm->ctx != nil)
				llama_free(lm->ctx);
			if (lm->model != nil)
				llama_free_model(lm->model);
			if (lm->path != nil)
				free(lm->path);
			free(lm);
			models[i] = nil;
		}
	}

	nmodels = 0;
	llama_backend_free();
}
