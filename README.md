# xCORE VocalFusion Raspberry Pi Setup

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use **xCORE VocalFusion** for audio.

**Note:** This repository is designed for use within the following **xCORE VocalFusion** repository:
- xCORE VocalFusion Kit for AVS: https://github.com/xmos/vocalfusion-avs-setup

This setup will perform the following operations:

- enable the I2S, I2C and SPI interfaces
- install the Raspberry Pi kernel headers
- install the required packages
- compile the I2S drivers
- update the asoundrc file to support I2S devices
- add a cron job to load the I2S drivers at boot up

For XVF3510-INT devices these actions will be done as well:

- configure MCLK at 12288kHz from pin 7 (BCM 4)
- configure I2S BCLK at 3072kHz from pin 12 (BCM 18)
- update the alias for Audacity
- update the asoundrc file to support I2S devices
- add a cron job to reset the device at boot up
- add a cron job to configure the DAC at boot up

For XVF361x-INT devices these actions will be done as well:

- configure MCLK at 12288kHz from pin 7 (BCM 4)
- configure I2S BCLK at 3072kHz from pin 12 (BCM 18)
- update the alias for Audacity
- update the asoundrc file to support I2S devices
- add a cron job to reset the device at boot up
- add a cron job to configure the DAC at boot up

For XVF3800(DEFAULT) devices these actions will be done as well:

- configure I2S BCLK at 3072kHz from pin 12 (BCM 18)
- update the alias for Audacity
- update the asoundrc file to support I2S devices
- add a cron job to reset the device at boot up
- add a cron job to configure the IO expander at boot up

For XVF3800-extmclk devices these actions will be done as well:
- configure MCLK at 12288kHz from pin 7 (BCM 4) and drive to XVF3800


For XVF3510-UA and XVF361x-UA devices these actions will be done as well:

- update the asoundrc file to support USB devices
- update udev rules so that root privileges are not needed to access USB control interface

## Setup

1. First, obtain the required version of the Raspberry Pi operating system, which is available here:

   https://downloads.raspberrypi.org/raspbian/images/raspbian-2020-02-14/2020-02-13-raspbian-buster.zip

   We cannot use the latest as updates to linux kernel v5 have broken the I2S sub-system.

   Then, install the Raspberry Pi Imager on a host computer. Raspberry Pi Imager is available here:

   https://www.raspberrypi.org/software/

   Run the Raspberry Pi Imager, and select the 'CHOOSE OS' button. Scroll to the bottom of the displayed list, and select "Use custom".
   Then select the file downloaded above (2020-02-13-raspbian-buster.zip) and select "Open". The archive file does not have to be unzipped, the imager software will do that.

   Select the CHOOSE SD CARD button to which to download the image, and then select the "WRITE" button.

   When prompted, remove the written SD card and insert it into the Raspberry Pi.

2. Connect up the keyboard, mouse, speakers and display to the Raspberry Pi and power up the system. Refer to the **Getting Started Guide** for you platform.

   **DO NOT** follow the prompt to update the software on the system. Set up the locale, and setup a network connect, but **DO NOT** update the software on the Raspberry Pi. This will update the kernel, and then the audio sub-system will not work.


3. On the Raspberry Pi, clone the Github repository https://github.com/xmos/vocalfusion-rpi-setup:

   ```git clone https://github.com/xmos/vocalfusion-rpi-setup```

4. For VocalFusion devices, run the installation script as follows:

   ```./setup.sh xvf3100```

   For VocalFusion Stereo devices, run the installation script as follows:

   ```./setup.sh xvf3500```

   For XVF3510 devices, run the installation script as follows:

   ```./setup.sh xvf3510```

   For XVF3600 I2S master devices, run the installation script as follows:

   ```./setup.sh xvf3600-master```

   For XVF3600 I2S slave devices, run the installation script as follows:

   ```./setup.sh xvf3600-slave```

   For XVF3610-UA devices, run the installation script as follows:

   ```./setup.sh xvf3610-ua```

   For XVF3610-INT devices, run the installation script as follows:

   ```./setup.sh xvf3610-int```

   For XVF3615-UA devices, run the installation script as follows:

   ```./setup.sh xvf3615-ua```

   For XVF3615-INT devices, run the installation script as follows:

   ```./setup.sh xvf3615-int```

   For XVF3800-INTDEV devices, run the installation script as follows:

   ```./setup.sh xvf3800-intdev```

   For XVF3800-INTHOST devices, run the installation script as follows:

   ```./setup.sh xvf3800-inthost```

  For XVF3800-INTDEV-EXTMCLK devices, run the installation script as follows:

   ```./setup.sh xvf3800-intdev-extmclk```

   Wait for the script to complete the installation. This can take several minutes.

5. Reboot the Raspberry Pi.

## Important note on clocks

The I2S/PCM driver that is provided with raspbian does not support an MCLK output. However the 
driver does have full ability to set the BCLK and LRCLK correctly for a given sample rate. As 
the driver does not know about the MCLK it is likely to choose dividers for the clocks generators
which are not phase locked to the MCLK. The script in this repo gets around this problem by 
configuring the i2s driver to a certain frequency and then overriding the clock registers to force
a phase locked frequency.

This will work until a different sample rate is chosen by an application, then the I2S driver will
write it's own value to the clocks and the MCLK will no longer be phase locked. To solve this problem
the following steps must be taken before connecting an XVF device with a different sample rate:

1. Take a short recording at the new sample rate: `arecord -c2 -fS32_LE -r{sample_rate} -s1 -Dhw:sndrpisimplecar`
2. For 48kHz `./resources/clk_dac_setup/setup_blk`, for 16kHz `./resources/clk_dac_setup/setup_blk 16000`

