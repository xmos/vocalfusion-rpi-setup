# xCORE VocalFusion Raspberry Pi Setup

This repository provides a simple-to-use automated script to configure a Raspberry Pi to use **xCORE VocalFusion** for audio.

The setup script will:
- Disable built-in audio
- Enable I2S, I2C (100k baud), and SPI interfaces
- Update the Raspberry Pi and install required packages

For INT devices, it will also:
- Install a devicetree overlay
- Generate and install an ALSA configuration specific to the XMOS device
- Create scripts to set up the XMOS device on boot (set up I2S, IO Expander, DAC, and MCLK if necessary)
- Generate and replace the user's crontab with one that runs those scripts at boot

For UA devices, it will instead:
- Add udev rules allowing non-privileged access to the USB interface

Finally, the setup will prompt you to restart your Raspberry Pi, this is required to ensure all interfaces are enabled.

## Compatibility

|                        | Raspberry Pi 4 | Raspberry Pi 5 |
|------------------------|----------------|----------------|
| XVF3610-INT            | Yes            | No [^1]        |
| XVF3610-UA             | Yes            | Yes            |
| XVF3800-INTDEV-EXTMCLK | Yes            | No [^1]        |
| XVF3800-INTDEV         | Yes            | Yes            |
| XVF3800-UA             | Yes            | Yes            |

[^1]: These configurations are not supported due to missing Raspberry Pi documentation, see [here](https://github.com/raspberrypi/documentation/issues/3285).

> [!NOTE]
> For cards not listed here, use [v5.8.0](https://github.com/xmos/vocalfusion-rpi-setup/tree/release/v5.8.0).

## Setup

1. First, install the Raspberry Pi imager on a host computer. This is available [here](https://www.raspberrypi.org/software) or through your package manager.
   
   Windows:
   ```powershell
   winget install --id=RaspberryPiFoundation.RaspberryPiImager -e
   ```

   Ubuntu:
   ```bash
   sudo apt install rpi-imager
   ```

   Run the imager (may require `root` privileges), select the Raspberry Pi you are using, Bookworm and Bullseye are both supported.

   Then, choose your SD card and write to it. When prompted, remove the SD card and insert it into the Raspberry Pi.

2. Connect peripherals (keyboard, mouse, speakers/headphones, and display recommended) and connect your XMOS device as a Pi hat. For UA devices, connect the Pi to the XMOS device via USB.

   Refer to the [Getting Started Guide](https://www.raspberrypi.com/documentation/computers/getting-started.html) for your Raspberry Pi.

3. On the Raspberry Pi, clone this GitHub repository:

   ```bash
   git clone https://github.com/xmos/vocalfusion-rpi-setup
   ```

4. Simply run the setup script for your device. Run `./setup.sh -h` for full usage.

   For example, an XVF3800 in intdev configuration with a 48kHz sample rate (the default sample rate):
   ```bash
   ./setup.sh xvf3800-intdev
   ```

   or, for an XVF3800 in EXTMCLK configuration with 16kHz sample rate:
   ```bash
   ./setup.sh xvf3800-intdev-extmclk -r16k
   ```

   For more options, run:
   ```bash
   ./setup.sh --help
   ```

   You will be prompted to restart your Raspberry Pi, this will apply options modified in the Raspberry Pi `config.txt` and any ALSA configuration.
