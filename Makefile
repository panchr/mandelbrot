# Makefile
# Author: Rushy Panchal

# Configuration
CC := gcc -Wall
RM := rm -fv

LIBS := -lpng

### Patterns
%.o: %c
	$(CC) -c $<

### Build Tasks
all: mandelbrot

# Binary Executable(s)
mandelbrot: mandelbrot.o image.o
	$(CC) $(LIBS) $^ -o $@

# Object Files
mandelbrot.o: mandelbrot.c
image.o: image.c

### Other Tasks
clean:
	$(RM) *.o
	$(RM) mandelbrot
