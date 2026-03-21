RPI_CONFIG_ROOT ?= /boot

# OVERLAY_MODE: master (default, RPi provides clocks) or slave (XVF3800 provides clocks)
OVERLAY_MODE ?= master

# RPI_MODEL: 4 (default) or 5 — selects the appropriate slave DTS
RPI_MODEL ?= 4

ifeq ($(OVERLAY_MODE),slave)
  ifeq ($(RPI_MODEL),5)
    DTS_SOURCE = xmos-device-slave-rpi5.dts
  else
    DTS_SOURCE = xmos-device-slave.dts
  endif
else
  DTS_SOURCE = xmos-device.dts
endif

.PHONY: all
all: xmos-device.dtbo

xmos-device.dtbo: $(DTS_SOURCE)
	dtc -@ -I dts -O dtb -o xmos-device.dtbo $(DTS_SOURCE)

install: xmos-device.dtbo
	sudo cp xmos-device.dtbo ${RPI_CONFIG_ROOT}/overlays
	if ! grep -q '^dtoverlay=xmos-device$$' ${RPI_CONFIG_ROOT}/config.txt; then \
		echo 'dtoverlay=xmos-device' | sudo tee -a ${RPI_CONFIG_ROOT}/config.txt; \
	fi

uninstall:
	sudo sed -i '/dtoverlay=xmos-device/d' ${RPI_CONFIG_ROOT}/config.txt
	-sudo rm ${RPI_CONFIG_ROOT}/overlays/xmos-device.dtbo

clean:
	rm *.dtbo
