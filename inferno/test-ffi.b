implement TestFFI;

#
# Test Suite for Llambo FFI
#
# This program tests the FFI bindings to llama.cpp from Limbo.
# It verifies module loading, model operations, and inference.
#

include "sys.m";
	sys: Sys;
	print: import sys;

include "draw.m";

include "llambo_c.m";
	llambo_c: Llambo_c;

TestFFI: module
{
	init: fn(nil: ref Draw->Context, args: list of string);
};

# Test result tracking
tests_run := 0;
tests_passed := 0;
tests_failed := 0;

test_name: string;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	
	print("==============================================\n");
	print("Llambo FFI Test Suite\n");
	print("==============================================\n\n");
	
	# Test 1: Module loading
	test_module_loading();
	
	# Test 2: Model operations (if FFI available)
	if (llambo_c != nil)
		test_model_operations();
	
	# Test 3: Error handling
	if (llambo_c != nil)
		test_error_handling();
	
	# Print summary
	print("\n==============================================\n");
	print("Test Summary\n");
	print("==============================================\n");
	print("Tests run:    %d\n", tests_run);
	print("Tests passed: %d\n", tests_passed);
	print("Tests failed: %d\n", tests_failed);
	
	if (tests_failed == 0) {
		print("\n✓ All tests passed!\n");
	} else {
		print("\n✗ Some tests failed\n");
	}
	
	print("==============================================\n");
}

#
# Test module loading
#
test_module_loading()
{
	begin_test("Module loading");
	
	llambo_c = load Llambo_c Llambo_c->PATH;
	
	if (llambo_c != nil) {
		pass("FFI module loaded successfully");
	} else {
		fail("Failed to load FFI module - this is expected if FFI not built");
		print("  Note: Run './build-ffi.sh build' to enable FFI\n");
	}
}

#
# Test model operations
#
test_model_operations()
{
	# Test with a dummy path (will fail, but tests the API)
	begin_test("Model load (invalid path)");
	
	model_id := llambo_c->load_model("/nonexistent/model.gguf", 1, 0);
	
	if (model_id < 0) {
		pass("Correctly returns error for invalid model path");
	} else {
		fail("Should return error for invalid model");
		# Cleanup if somehow loaded
		llambo_c->free_model(model_id);
	}
	
	# Test model info with invalid ID
	begin_test("Model info (invalid ID)");
	
	info := llambo_c->get_model_info(-1);
	
	if (info == nil || info == "") {
		pass("Correctly returns empty for invalid model ID");
	} else {
		fail("Should return empty for invalid ID");
	}
	
	# Test tokenization with invalid ID
	begin_test("Tokenization (invalid ID)");
	
	tokens := llambo_c->tokenize(-1, "Hello");
	
	if (tokens == nil) {
		pass("Correctly returns nil for invalid model ID");
	} else {
		fail("Should return nil for invalid ID");
	}
	
	# Test inference with invalid ID
	begin_test("Inference (invalid ID)");
	
	result := llambo_c->infer(-1, "Hello", 10, 0.8);
	
	if (result == nil || result == "") {
		pass("Correctly returns empty for invalid model ID");
	} else {
		fail("Should return empty for invalid ID");
	}
	
	# Test free with invalid ID
	begin_test("Free model (invalid ID)");
	
	ret := llambo_c->free_model(-1);
	
	if (ret < 0) {
		pass("Correctly returns error for invalid model ID");
	} else {
		fail("Should return error for invalid ID");
	}
}

#
# Test error handling
#
test_error_handling()
{
	# Test nil parameters
	begin_test("Nil parameter handling");
	
	# Load with nil path (will be handled in C)
	model_id := llambo_c->load_model("", 1, 0);
	if (model_id < 0) {
		pass("Handles empty path correctly");
	} else {
		fail("Should reject empty path");
		llambo_c->free_model(model_id);
	}
	
	# Tokenize with nil text
	tokens := llambo_c->tokenize(0, "");
	if (tokens == nil) {
		pass("Handles empty text correctly");
	} else {
		fail("Should return nil for empty text");
	}
	
	# Infer with nil prompt
	result := llambo_c->infer(0, "", 10, 0.8);
	if (result == nil || result == "") {
		pass("Handles empty prompt correctly");
	} else {
		fail("Should return empty for empty prompt");
	}
}

#
# Test helper functions
#

begin_test(name: string)
{
	test_name = name;
	tests_run++;
	print("Test %d: %s\n", tests_run, name);
}

pass(msg: string)
{
	tests_passed++;
	print("  ✓ PASS: %s\n", msg);
}

fail(msg: string)
{
	tests_failed++;
	print("  ✗ FAIL: %s\n", msg);
}
