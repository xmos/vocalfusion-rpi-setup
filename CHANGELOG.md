# VocalFusion Raspberry Pi Setup Change Log

## 2.0.0

  * Use default I2C hardware
  * Add installation of Py3 packages

## 1.3.2

  * Added audacity installation and setup for XVF3510

## 1.3.1

  * Added reset for XVF3510

## 1.3.0

  * Added support for XVF3510
  * Modified I2S loader to be either master or slave

## 1.2.1

  * Remove BCM2708 modules that no longer exist in Stretch (#4)
  * Stop on kernel module build error
  * Require reinstall of kernel and firmware so kernel headers match running kernel version and we can build kernel modules (#6)

## 1.2.0

  * New ALSA configurations for both VocalFusion and VocalFusion Stereo devices.
  * Optional setup.sh argument to specify VocalFusion ALSA configuration.

## 1.1.0

  * Updated I2C driver to be compatible with Linux Kernel v4.10.

## 1.0.0

  * Moved to vocalfusion-rpi-setup repo.
  * Removed the need to download Linux Raspberry Pi source code.
  * Removed snd_driver/bclk_patch.
