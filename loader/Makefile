obj-m := loader.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD)/i2s_slave modules

i2s_master:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD)/i2s_master modules
