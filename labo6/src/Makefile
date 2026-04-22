# Cross-compile pour la DE1-SoC (ARM 32 bits). Sur la carte : ./axi4lite_io_linux
# Si besoin : make CC=arm-linux-gnueabihf-gcc
CC      := arm-linux-gnueabihf-gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE
LDFLAGS ?=

TARGET  := axi4lite_io_linux
SRCS    := axi4lite_io.c io_functions.c
OBJS    := $(SRCS:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c axi_lw.h io_functions.h hex_val.h
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET)
