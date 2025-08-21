CC = gcc
CFLAGS ?= -Wall -Wextra -Werror -pedantic -pthread -O2
COMMON = rpi_clk_common.c

.PHONY: all
all: setup_mclk setup_arbitrary_i2s_rate

setup_mclk: setup_mclk.c $(COMMON)
	$(CC) $(CFLAGS) -o $@ $^

setup_arbitrary_i2s_rate: setup_arbitrary_i2s_rate.c $(COMMON)
	$(CC) $(CFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -f setup_mclk setup_arbitrary_i2s_rate
