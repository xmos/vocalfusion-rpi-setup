# xCORE VocalFusion Raspberry Pi Setup

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use **xCORE VocalFusion** for audio.

**Note:** This repository is designed for use within the following **xCORE VocalFusion** repositories:
- xCORE VocalFusion Stereo 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-stereo-avs-setup
- xCORE VocalFusion 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-avs-setup


## Setup

1. Install **Raspbian Stretch** on the Raspberry Pi.

2. Open a terminal on the Raspberry Pi and clone this repository:  
`cd ~; git clone https://github.com/xmos/vocalfusion-rpi-setup`

3. For VocalFusion devices, run the installation script as follows: `source ~/vocalfusion-rpi-setup/setup.sh vocalfusion`.

   For VocalFusion Stereo devices, run the installation script as follows: `source ~/vocalfusion-rpi-setup/setup.sh`.

   Wait for the script to complete the installation. This can take several minutes.

4. Enter `sudo reboot` to reboot the Raspberry Pi and complete the setup.
