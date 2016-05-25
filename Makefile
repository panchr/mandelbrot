# Makefile
# Author: Rushy Panchal

# Configuration
CC := gcc -Wall
RM := rm -rfv

LIBS := -lpng

BIN := bin
BUILD := build

### Patterns
$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) -c $< -o $@

### Build Tasks
all: $(BIN)/mandelbrot

$(BIN):
	mkdir -p $@
$(BUILD):
	mkdir -p $@

# Binary Executable(s)
$(BIN)/mandelbrot: $(BUILD)/mandelbrot.o $(BUILD)/image.o | $(BIN)
	$(CC) $(LIBS) $^ -o $@

### Other Tasks
clean:
	$(RM) $(BUILD)
	$(RM) $(BIN)
