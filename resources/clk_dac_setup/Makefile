default: bclk mclk setup_arbitrary_i2s_rate

bclk: setup_mclk_bclk.c
	gcc -g -o setup_bclk setup_mclk_bclk.c

mclk: setup_mclk_bclk.c
	gcc -g -DMCLK -o setup_mclk setup_mclk_bclk.c

setup_arbitrary_i2s_rate: setup_mclk_bclk.c
	gcc -g -DARBITRARY_LRCLK -o setup_arbitrary_i2s_rate setup_mclk_bclk.c

clean:
	rm -f setup_mclk
	rm -f setup_bclk
