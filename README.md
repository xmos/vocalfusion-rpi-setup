# xCORE VocalFusion Raspberry Pi Setup

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use **xCORE VocalFusion** for audio.

**Note:** This repository is designed for use within the following **xCORE VocalFusion** repositorie:
- xCORE VocalFusion Kit for AVS: https://github.com/xmos/vocalfusion-avs-setup

This setup will perform the following operations:

- enable the I2S, I2C and SPI interfaces
- install the Raspberry Pi kernel headers
- install the required packages
- compile the I2S drivers
- add a cron job to load the I2S drivers at boot up

For XVF3510 devices these actions will be done as well:

- configure MCLK at 24576kHz from pin 7 (BCM 4)
- configure I2S BCLK at 3072kHz from pin 12 (BCM18)
- update the alias for Audacity
- add a cron job to reset the device at boot up
- add a cron job to configure the DAC at boot up

## Setup

1. Install **Raspbian Buster** on the Raspberry Pi.

2. Ensure running kernel version matches headers kernel headers package. A typical system requires the following `--reinstall` command:

   ```sudo apt-get update```
   ```sudo apt-get install --reinstall raspberrypi-bootloader raspberrypi-kernel```

   followed by a reboot.

3. Clone the Github repository https://github.com/xmos/vocalfusion-rpi-setup:

   ```git clone https://github.com/xmos/vocalfusion-rpi-setup```

4. For VocalFusion devices, run the installation script as follows:

   ```./setup.sh xvf3100```

   For VocalFusion Stereo devices, run the installation script as follows:

   ```./setup.sh xvf3500```

   For XVF3510 devices, run the installation script as follows:

   ```./setup.sh xvf3510```

   Wait for the script to complete the installation. This can take several minutes.

5. Reboot the Raspberry Pi.
