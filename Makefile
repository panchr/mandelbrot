# Makefile
# Author: Rushy Panchal

# Configuration
CC := gcc -Wall
RM := rm -rfv

LIBS := -lpng
SRC_LIBS = $(BUILD)/image.o

SRC := src
BIN := bin
BUILD := build

NUM_ITER := 250
SIZE := 2500

# Other configuration
vpath % src
vpath %.asm src/mach-x86
vpath %.o build

### Patterns
# Object files (from C)
$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
# Object files (from x86)
$(BUILD)/%.o: %.asm | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

### Build Tasks
all: $(BIN)/mandelbrot $(BIN)/mandelbrot-x86

$(BIN):
	@mkdir -p $@
$(BUILD):
	@mkdir -p $@

# Binary Executable(s)
$(BIN)/mandelbrot: $(BUILD)/mandelbrot.o $(SRC_LIBS) \
	$(BUILD)/generate_mandelbrot_set.o | $(BIN)
	$(CC) $(CFLAGS) $(LIBS) $^ -o $@
$(BIN)/mandelbrot-x86: $(BUILD)/mandelbrot.o $(SRC_LIBS) \
	$(BUILD)/generate_mandelbrot_set-x86.o | $(BIN)
	$(CC) $(CFLAGS) $(LIBS) $^ -o $@

# Object File(s)
$(BUILD)/image.o: image.c image.h

### Other Tasks
test: CFLAGS=-O3
test: all
	time $(BIN)/mandelbrot mandelbrot.png $(SIZE) $(SIZE) $(NUM_ITER)
	time $(BIN)/mandelbrot-x86 mandelbrot-x86.png $(SIZE) $(SIZE) $(NUM_ITER)

	diff mandelbrot.png mandelbrot-x86.png

clean:
	$(RM) $(BUILD)
	$(RM) $(BIN)
