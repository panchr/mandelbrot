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
vpath %.c src
vpath %.h src
vpath %.o build

### Patterns
# Object files
$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) -c $< -o $@

### Build Tasks
all: $(BIN)/mandelbrot

$(BIN):
	mkdir -p $@
$(BUILD):
	mkdir -p $@

# Binary Executable(s)
$(BIN)/mandelbrot: $(BUILD)/mandelbrot.o $(SRC_LIBS) | $(BIN)
	$(CC) $(LIBS) $^ -o $@

### Other Tasks
clean:
	$(RM) $(BUILD)
	$(RM) $(BIN)
