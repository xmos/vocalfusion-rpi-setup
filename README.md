# xCORE VocalFusion Stereo Dev Kit on a Raspberry Pi

The XMOS **xCORE VocalFusion Stereo Dev Kit** provides far-field voice capture using the XMOS XVF3500 voice processor.

Combined with a Raspberry Pi, this kit allows you to quickly prototype and evaluate VocalFusion Stereo.

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use the **xCORE VocalFusion Stereo Dev Kit** for audio.

## Prerequisites
You will need:

- **xCORE VocalFusion Stereo Dev Kit**: XK-VF3500-L33
- Raspberry Pi 3
- Micro-USB power supply (min. 2A)
- MicroSD card (min. 16GB)
- Powered stereo speakers with audio 3.5mm analogue plug
- Monitor with HDMI input
- HDMI cable
- Fast-Ethernet connection with internet connectivity


## Hardware and Raspberry Pi audio setup
Setup your hardware by following the **Hardware Setup** at: https://xmos.com/vocalfusion-stereo

Full instructions on configuring the Raspberry Pi to use the **xCORE VocalFusion Stereo Dev Kit** are detailed in the **Getting Started Guide** available from: https://xmos.com/vocalfusion-stereo.

Brief instructions and additional notes are below:

1. Install Raspbian (Stretch) on the Raspberry Pi.

2. Open a terminal on the Raspberry Pi and clone this respository:  
`cd ~; git clone https://github.com/xmos/vocalfusion-stereo-setup`

3. Run the installation script: `source ~/vocalfusion-stereo-setup/auto_install.sh`
Wait for the script to complete the installation. This can take several minutes.

4. Enter `sudo reboot` to reboot the Raspberry Pi and complete the audio setup.

You are now ready to start evaluating the VocalFusion Stereo Kit.
