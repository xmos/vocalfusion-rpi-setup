# xCORE VocalFusion Raspberry Pi Setup

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use **xCORE VocalFusion** for audio.

**Note:** This repository is designed for use within the following **xCORE VocalFusion** repositories:
- xCORE VocalFusion Stereo 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-stereo-avs-setup
- xCORE VocalFusion 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-avs-setup


## Setup

1. Install **Raspbian Stretch** on the Raspberry Pi.

2. Ensure running kernel version matches headers kernel headers package. A typical system requires the following `--reinstall` command:

   ```sudo apt-get install --reinstall raspberrypi-bootloader raspberrypi-kernel```

   followed by a reboot.

3. Clone the Github repository https://github.com/xmos/vocalfusion-rpi-setup:

   ```git clone https://github.com/xmos/vocalfusion-rpi-setup```

4. For VocalFusion devices, run the installation script as follows:

   ```./setup.sh vocalfusion```

   For VocalFusion Stereo devices, run the installation script as follows:

   ```./setup.sh```

   For XVF3510 devices, run the installation script as follows:

   ```./setup.sh xvf3510```

   Wait for the script to complete the installation. This can take several minutes.

5. Reboot the Raspberry Pi.
