default: bclk mclk

bclk: setup_mclk_bclk.c
	gcc -g -o setup_bclk setup_mclk_bclk.c

mclk: setup_mclk_bclk.c
	gcc -g -o -DMCLK setup_mclk setup_mclk_bclk.c

clean:
	rm -f setup_mclk
	rm -f setup_bclk
