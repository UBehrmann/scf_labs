# Userspace — cross-compile for DE1-SoC (ARM)
CC      ?= arm-linux-gnueabihf-gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE
LDFLAGS ?=

TARGET  := convol_test
SRCS    := convol_test.c
OBJS    := $(SRCS:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c axi.h common_constants.h
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET)
