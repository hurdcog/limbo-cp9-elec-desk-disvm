#
# Makefile for Llambo C FFI Module
#
# This builds the C module that provides FFI bindings to llama.cpp
# for Inferno OS. The module must be compiled and linked into the
# Inferno kernel or loaded as a shared library.
#

# Inferno paths (adjust for your installation)
INFERNO_ROOT ?= /usr/inferno
INFERNO_INCLUDE = $(INFERNO_ROOT)/include
INFERNO_LIBINTERP = $(INFERNO_ROOT)/libinterp

# llama.cpp paths
LLAMA_CPP_ROOT = ../../llama.cpp
LLAMA_CPP_BUILD = $(LLAMA_CPP_ROOT)/build
LLAMA_CPP_INCLUDE = $(LLAMA_CPP_ROOT)
LLAMA_CPP_LIB = $(LLAMA_CPP_BUILD)/src/libllama.a

# Compiler settings
CC = gcc
CFLAGS = -O2 -Wall -I$(INFERNO_INCLUDE) -I$(LLAMA_CPP_INCLUDE)
CFLAGS += -fPIC -D_REENTRANT

# Linker settings
LDFLAGS = -L$(LLAMA_CPP_BUILD)/src -lllama -lm -lstdc++ -lpthread

# Source files
SOURCES = llambo_c.c
OBJECTS = $(SOURCES:.c=.o)
TARGET = llambo_c.so

# Module header generation
MODULE_HEADER = llambo_cmod.h

.PHONY: all clean install check-deps

all: check-deps $(TARGET)

check-deps:
	@echo "Checking dependencies..."
	@if [ ! -d "$(INFERNO_ROOT)" ]; then \
		echo "Error: INFERNO_ROOT not found at $(INFERNO_ROOT)"; \
		echo "Set INFERNO_ROOT environment variable to your Inferno installation"; \
		exit 1; \
	fi
	@if [ ! -f "$(LLAMA_CPP_LIB)" ]; then \
		echo "Error: llama.cpp library not found at $(LLAMA_CPP_LIB)"; \
		echo "Build llama.cpp first:"; \
		echo "  cd $(LLAMA_CPP_ROOT) && mkdir -p build && cd build"; \
		echo "  cmake .. && cmake --build . --config Release"; \
		exit 1; \
	fi
	@echo "Dependencies OK"

$(TARGET): $(OBJECTS)
	@echo "Linking $@..."
	$(CC) -shared -o $@ $(OBJECTS) $(LDFLAGS)
	@echo "Built $@ successfully"

%.o: %.c llambo_c.h
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Generate module header (for Inferno builtin integration)
$(MODULE_HEADER): llambo_c.c
	@echo "Generating module header..."
	@echo "/* Auto-generated module header for Llambo_c */" > $@
	@echo "#ifndef LLAMBO_CMOD_H" >> $@
	@echo "#define LLAMBO_CMOD_H" >> $@
	@echo "" >> $@
	@echo "void llambo_cmodinit(void);" >> $@
	@echo "void llambo_cmodcleanup(void);" >> $@
	@echo "" >> $@
	@echo "#endif /* LLAMBO_CMOD_H */" >> $@

clean:
	rm -f $(OBJECTS) $(TARGET) $(MODULE_HEADER)
	@echo "Cleaned build artifacts"

install: $(TARGET)
	@echo "Installing $(TARGET) to $(INFERNO_LIBINTERP)..."
	@if [ ! -d "$(INFERNO_LIBINTERP)" ]; then \
		echo "Warning: $(INFERNO_LIBINTERP) not found"; \
		echo "Creating local lib directory..."; \
		mkdir -p ../lib; \
		cp $(TARGET) ../lib/; \
	else \
		cp $(TARGET) $(INFERNO_LIBINTERP)/; \
	fi
	@echo "Installation complete"

# Test compilation only (doesn't link)
test-compile: $(OBJECTS)
	@echo "Compilation test successful"

# Print build configuration
config:
	@echo "Build Configuration:"
	@echo "  INFERNO_ROOT:    $(INFERNO_ROOT)"
	@echo "  LLAMA_CPP_ROOT:  $(LLAMA_CPP_ROOT)"
	@echo "  CC:              $(CC)"
	@echo "  CFLAGS:          $(CFLAGS)"
	@echo "  LDFLAGS:         $(LDFLAGS)"
	@echo "  TARGET:          $(TARGET)"

help:
	@echo "Llambo C FFI Module Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build the C module (default)"
	@echo "  clean        - Remove build artifacts"
	@echo "  install      - Install module to Inferno"
	@echo "  check-deps   - Verify dependencies"
	@echo "  test-compile - Test compilation only"
	@echo "  config       - Show build configuration"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Environment Variables:"
	@echo "  INFERNO_ROOT     - Path to Inferno installation (default: /usr/inferno)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Inferno OS installed with development headers"
	@echo "  2. llama.cpp built in ../../llama.cpp/build/"
	@echo "  3. GCC or compatible C compiler"
