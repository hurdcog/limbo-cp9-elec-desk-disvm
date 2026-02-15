/*
 * Llambo C Module - Header file
 * 
 * This header defines the interface for the Llambo C module that provides
 * FFI bindings to llama.cpp for Inferno OS.
 */

#ifndef LLAMBO_C_H
#define LLAMBO_C_H

/* Module initialization and cleanup */
void llambo_cmodinit(void);
void llambo_cmodcleanup(void);

/* Module function declarations (for reference) */
static Word* llama_load_model(Exec *e, Module *m, Word *args, uchar *ip);
static Word* llama_free_model(Exec *e, Module *m, Word *args, uchar *ip);
static Word* llama_tokenize(Exec *e, Module *m, Word *args, uchar *ip);
static Word* llama_infer(Exec *e, Module *m, Word *args, uchar *ip);
static Word* llama_get_model_info(Exec *e, Module *m, Word *args, uchar *ip);

#endif /* LLAMBO_C_H */
