obj-m := loader.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

i2s_slave: $(PWD)/loader.c 
	$(MAKE) -C $(KDIR) M=$(PWD) modules
