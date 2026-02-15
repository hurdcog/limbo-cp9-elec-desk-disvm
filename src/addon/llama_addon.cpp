#include <napi.h>
#include <string>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <vector>
#include <memory>
#include <fstream>
#include <sstream>
#include <chrono>
#include <ctime>
#include <random>
#include <algorithm>

// Include llama.cpp headers
#include "llama.h"

// Function to get timestamp for logging
std::string getTimestamp() {
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    char buffer[80];
    std::strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", std::localtime(&time));
    return std::string(buffer);
}

// Logger class to write to a file
class Logger {
public:
    Logger() {
        logFile.open("worker_log.txt", std::ios::app);
        logFile << "\n\n" << getTimestamp() << " - ==== New Session Started ====\n" << std::endl;
    }
    
    ~Logger() {
        if (logFile.is_open()) {
            logFile.close();
        }
    }
    
    void log(const std::string& message) {
        if (logFile.is_open()) {
            logFile << getTimestamp() << " - " << message << std::endl;
            logFile.flush();
        }
    }
    
private:
    std::ofstream logFile;
};

// Global logger instance
Logger logger;

class LlamaWorker : public Napi::AsyncWorker {
public:
    LlamaWorker(Napi::Function& callback, std::string modelPath, std::string prompt)
        : Napi::AsyncWorker(callback), modelPath(modelPath), prompt(prompt), result("") {
        logger.log("LlamaWorker constructor called with model: " + modelPath);
    }

    ~LlamaWorker() {
        logger.log("LlamaWorker destructor called");
        
        // Clean up llama resources
        if (ctx != nullptr) {
            llama_free(ctx);
            ctx = nullptr;
        }
        
        if (model != nullptr) {
            llama_model_free(model);
            model = nullptr;
        }
    }

protected:
    void Execute() override {
        logger.log("Worker thread started execution");
        logger.log("Model path: " + modelPath);
        logger.log("Prompt length: " + std::to_string(prompt.length()) + " characters");
        logger.log("Prompt content: " + prompt);

        try {
            // Initialize llama backend
            logger.log("Initializing llama.cpp backend");
            llama_backend_init();
            
            // Step 1: Set up model parameters
            logger.log("Step 1: Setting up model parameters");
            struct llama_model_params model_params = llama_model_default_params();
            model_params.use_mmap = true;
            model_params.use_mlock = true;
            
            // Step 2: Load the model
            logger.log("Step 2: Loading model from " + modelPath);
            model = llama_load_model_from_file(modelPath.c_str(), model_params);
            
            if (model == nullptr) {
                logger.log("ERROR: Failed to load model from " + modelPath);
                result = "Failed to load model";
                return;
            }
            
            // Log model details
            logger.log("Model loaded successfully:");
            logger.log("  - Parameters: " + std::to_string(llama_model_n_params(model)));
            logger.log("  - Context size: " + std::to_string(llama_model_n_ctx_train(model)));
            logger.log("  - Embedding size: " + std::to_string(llama_model_n_embd(model)));
            
            // Step 3: Set up context parameters
            logger.log("Step 3: Creating inference context");
            struct llama_context_params ctx_params = llama_context_default_params();
            ctx_params.n_ctx = 2048; // Context size
            ctx_params.n_threads = 4; // Number of threads to use for inference
            ctx_params.n_batch = 512; // Batch size for prompt evaluation
            
            // Step 4: Create context
            ctx = llama_new_context_with_model(model, ctx_params);
            
            if (ctx == nullptr) {
                logger.log("ERROR: Failed to create context");
                result = "Failed to create context";
                return;
            }
            
            logger.log("Context created with " + std::to_string(ctx_params.n_threads) + " threads for computation");
            
            // Step 5: Tokenize the prompt
            logger.log("Step 5: Tokenizing prompt");
            
            const auto vocab = llama_model_get_vocab(model);
            std::vector<llama_token> tokens(256);
            int n_tokens = llama_tokenize(vocab, prompt.c_str(), prompt.length(), tokens.data(), tokens.size(), true, false);
            
            if (n_tokens < 0) {
                n_tokens = 0;
                logger.log("ERROR: Failed to tokenize prompt or prompt is too long");
            } else {
                logger.log("Tokenized prompt into " + std::to_string(n_tokens) + " tokens");
                tokens.resize(n_tokens);
            }
            
            if (n_tokens == 0) {
                logger.log("ERROR: Empty prompt");
                result = "Empty prompt after tokenization";
                return;
            }
            
            // Step 6: Processing prompt tokens
            logger.log("Step 6: Processing prompt tokens");
            
            // Initialize batch for the entire prompt
            struct llama_batch batch = llama_batch_init(n_tokens, 0, 1);
            
            for (int i = 0; i < n_tokens; i++) {
                batch.token[i] = tokens[i];
                batch.pos[i] = i;
                batch.n_seq_id[i] = 1;
                batch.seq_id[i][0] = 0;
                batch.logits[i] = (i == n_tokens - 1) ? 1 : 0; // Only compute logits for the last token
            }
            
            batch.n_tokens = n_tokens; // Ensure n_tokens is set correctly
            
            if (llama_decode(ctx, batch) != 0) {
                logger.log("ERROR: Failed to decode prompt");
                llama_batch_free(batch);
                result = "Failed to process prompt";
                return;
            }
            
            logger.log("Prompt processing complete - generating response");
            
            // Step 7: Generate response tokens
            logger.log("Step 7: Generating response tokens");
            
            std::stringstream generated_text;
            generated_text << prompt;
            
            // Get EOS token
            const llama_token token_eos = llama_vocab_eos(vocab);
            
            // Number of tokens to generate
            const int max_new_tokens = 128;
            
            // Generation loop
            llama_token new_token = 0;
            int prev_token_pos = n_tokens - 1;
            
            for (int i = 0; i < max_new_tokens; i++) {
                // Initialize a new batch for one token
                struct llama_batch next_batch = llama_batch_init(1, 0, 1);
                
                if (i == 0) {
                    // First iteration, use the last token from the prompt
                    next_batch.token[0] = tokens.back();
                } else {
                    // Use the previously generated token
                    next_batch.token[0] = new_token;
                }
                
                next_batch.pos[0] = n_tokens + i;
                next_batch.n_seq_id[0] = 1;
                next_batch.seq_id[0][0] = 0;
                next_batch.logits[0] = 1;
                next_batch.n_tokens = 1; // Ensure n_tokens is set correctly
                
                // Process the token
                if (llama_decode(ctx, next_batch) != 0) {
                    logger.log("ERROR: Failed to decode token " + std::to_string(i));
                    llama_batch_free(next_batch);
                    break;
                }
                
                // Get the logits for the last token
                const float* logits = llama_get_logits(ctx);
                
                // Simple greedy sampling (just take the highest probability token)
                int vocab_size = llama_vocab_n_tokens(vocab);
                int best_token_id = 0;
                float best_score = -INFINITY;
                
                for (int token_id = 0; token_id < vocab_size; token_id++) {
                    if (logits[token_id] > best_score) {
                        best_score = logits[token_id];
                        best_token_id = token_id;
                    }
                }
                
                new_token = best_token_id;
                
                // Check for EOS token
                if (new_token == token_eos) {
                    logger.log("Generated EOS token, stopping generation");
                    llama_batch_free(next_batch);
                    break;
                }
                
                // Convert token to text
                char buffer[8];
                int token_len = llama_token_to_piece(vocab, new_token, buffer, sizeof(buffer), 0, true);
                if (token_len > 0) {
                    std::string token_text(buffer, token_len);
                    generated_text << token_text;
                    
                    // Log every few tokens
                    if (i % 5 == 0 || i == max_new_tokens - 1) {
                        logger.log("Generated token " + std::to_string(i+1) + "/" + 
                                std::to_string(max_new_tokens) + ": '" + token_text + "'");
                    }
                }
                
                // Free the batch
                llama_batch_free(next_batch);
            }
            
            // Free the original batch
            llama_batch_free(batch);
            
            // Step 8: Finalize response and clean up
            logger.log("Step 8: Response generation complete, cleaning up resources");
            
            result = generated_text.str();
            logger.log("Final response length: " + std::to_string(result.length()) + " characters");
            
            logger.log("Worker processing completed successfully");
        }
        catch (const std::exception& e) {
            logger.log("ERROR: Exception during processing: " + std::string(e.what()));
            result = "Error processing prompt: " + std::string(e.what());
        }
        
        logger.log("Worker execution completed");
    }

    void OnOK() override {
        Napi::HandleScope scope(Env());
        logger.log("OnOK called - returning result to JavaScript");
        Callback().Call({Env().Null(), Napi::String::New(Env(), result)});
    }

    void OnError(const Napi::Error& e) override {
        Napi::HandleScope scope(Env());
        logger.log("OnError called with error: " + std::string(e.Message()));
        Callback().Call({Napi::String::New(Env(), e.Message()), Env().Null()});
    }

private:
    std::string modelPath;
    std::string prompt;
    std::string result;
    
    // llama.cpp model and context
    struct llama_model* model = nullptr;
    struct llama_context* ctx = nullptr;
};

Napi::Value ProcessPrompt(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    logger.log("ProcessPrompt function called");

    // Check arguments
    if (info.Length() < 3 || !info[0].IsString() || !info[1].IsString() || !info[2].IsFunction()) {
        logger.log("Invalid arguments provided to ProcessPrompt");
        Napi::TypeError::New(env, "Expected arguments: modelPath (string), prompt (string), callback (function)").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string modelPath = info[0].As<Napi::String>().Utf8Value();
    std::string prompt = info[1].As<Napi::String>().Utf8Value();
    Napi::Function callback = info[2].As<Napi::Function>();
    
    logger.log("Creating LlamaWorker with model: " + modelPath);

    // Create and queue the async worker
    LlamaWorker* worker = new LlamaWorker(callback, modelPath, prompt);
    worker->Queue();
    logger.log("LlamaWorker queued for execution");

    return env.Undefined();
}

Napi::Value GetWorkerLog(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    logger.log("GetWorkerLog function called");
    
    std::ifstream logFile("worker_log.txt");
    std::string content;
    std::string line;
    
    if (logFile.is_open()) {
        while (std::getline(logFile, line)) {
            content += line + "\n";
        }
        logFile.close();
    } else {
        content = "Unable to open log file";
    }
    
    return Napi::String::New(env, content);
}

Napi::Object InitModule(Napi::Env env, Napi::Object exports) {
    logger.log("Initializing llama_addon module");
    exports.Set("processPrompt", Napi::Function::New(env, ProcessPrompt));
    exports.Set("getWorkerLog", Napi::Function::New(env, GetWorkerLog));
    return exports;
}

NODE_API_MODULE(llama_addon, InitModule) 