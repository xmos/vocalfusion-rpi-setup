RPI_CONFIG_ROOT ?= /boot

.PHONY: all
all: xmos-device.dtbo

xmos-device.dtbo: xmos-device.dts
	dtc -@ -I dts -O dtb -o xmos-device.dtbo xmos-device.dts

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
