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

# Other configuration
vpath % src
vpath %.o build

### Patterns
# Object files (from C)
$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
# Object files (from x86)
$(BUILD)/%.o: %.s | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

### Build Tasks
all: $(BIN)/mandelbrot

$(BIN):
	mkdir -p $@
$(BUILD):
	mkdir -p $@

# Binary Executable(s)
$(BIN)/mandelbrot: $(BUILD)/mandelbrot.o $(SRC_LIBS) | $(BIN)
	$(CC) $(CFLAGS) $(LIBS) $^ -o $@

### Other Tasks
clean:
	$(RM) $(BUILD)
	$(RM) $(BIN)
