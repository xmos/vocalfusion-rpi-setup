#!/usr/bin/env bash
pushd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null
RPI_SETUP_DIR="$( pwd )"

I2S_MODE=
XMOS_DEVICE=
INSTALL_ATTEMPT_NUM_MAX=10
# Valid values for XMOS device
VALID_XMOS_DEVICES="xvf3100 xvf3500 xvf3510-int xvf3510-ua xvf3600-slave xvf3600-master xvf3610-int xvf3610-ua xvf3615-int xvf3615-ua"

PACKAGES_TO_INSTALL="python3-matplotlib python3-numpy libatlas-base-dev audacity libreadline-dev libncurses-dev"
PACKAGES_TO_INSTALL_ONLY_FOR_UA="libusb-1.0-0-dev libevdev-dev libudev-dev"

usage() {
  local VALID_XMOS_DEVICES_DISPLAY_STRING=
  local NUMBER_OF_VALID_DEVICES=$(echo $VALID_XMOS_DEVICES | wc -w)
  local i=1
  local SEP=
  # Build a string of valid device options
  for d in $VALID_XMOS_DEVICES; do
    if [[ $i -eq $NUMBER_OF_VALID_DEVICES ]]; then
      SEP=" or "
    fi
    VALID_XMOS_DEVICES_DISPLAY_STRING=$VALID_XMOS_DEVICES_DISPLAY_STRING$SEP$d
    SEP=", "
    (( ++i ))
  done

  cat <<EOT
This script sets up the Raspberry Pi to use different XMOS devices
usage: setup.sh <DEVICE-TYPE>
The DEVICE-TYPE is the XMOS device to setup: $VALID_XMOS_DEVICES_DISPLAY_STRING
EOT
}

# validate XMOS_DEVICE value
validate_device() {
  local DEV=$1
  shift
  for d in $*; do
    if [[ "$DEV" = "$d" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ $# -eq 1 ]]; then
  XMOS_DEVICE=$1
  if ! validate_device $XMOS_DEVICE $VALID_XMOS_DEVICES; then
    echo "error: $XMOS_DEVICE is not a valid device type."
    echo
    usage
    exit 1
  fi
else
  usage
  exit 1
fi

# Configure device-specific settings
case $XMOS_DEVICE in 
  xvf3510-ua|xvf3610-ua|xvf3615-ua)
    UA_MODE=y
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf_xvf3510_ua
    ;;

  xvf3510-int|xvf3610-int|xvf3615-int)
    I2S_MODE=master
    DAC_SETUP=y
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf_xvf3510_int
    ;;
  xvf3500)
    I2S_MODE=slave
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf_stereo
    ;;
  xvf3[01]00)
    I2S_MODE=slave
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf
    ;;
  xvf3600-slave)
    I2S_MODE=master
    DAC_SETUP=y
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf
    ;;
  xvf3600-master)
    I2S_MODE=slave
    DAC_SETUP=y
    ASOUNDRC_TEMPLATE=$RPI_SETUP_DIR/resources/asoundrc_vf
    ;;
  *)
    echo Error: unknown XMOS device type $XMOS_DEVICE.
    exit 1
  ;;
esac

# Disable the built-in audio output so there is only one audio
# device in the system
sudo sed -i -e 's/^dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt

# Enable the i2s device tree
sudo sed -i -e 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt

# Enable the I2C device tree
sudo raspi-config nonint do_i2c 1
sudo raspi-config nonint do_i2c 0

# Set the I2C baudrate to 100k
sudo sed -i -e '/^dtparam=i2c_arm_baudrate/d' /boot/config.txt
sudo sed -i -e 's/dtparam=i2c_arm=on$/dtparam=i2c_arm=on\ndtparam=i2c_arm_baudrate=100000/' /boot/config.txt

# Enable the SPI support
sudo raspi-config nonint do_spi 1
sudo raspi-config nonint do_spi 0

# Install the kernel header package to allow building the I2S module.
# We only need to do this once, and we must not do it again if we have called
# 'apt-get update' as it may install a later kernel and headers which have not
# been tested and verified.
KERNEL_HEADERS_PACKAGE=raspberrypi-kernel-headers
if ! dpkg -s $KERNEL_HEADERS_PACKAGE &> /dev/null; then
  echo "Installing Raspberry Pi kernel headers"
  sudo apt-get install -y $KERNEL_HEADERS_PACKAGE
fi

echo  "Installing necessary packages for dev kit"
packages=$PACKAGES_TO_INSTALL
# Add packages for UA mode
if [[ -n "$UA_MODE" ]]; then
  packages="$packages $PACKAGES_TO_INSTALL_ONLY_FOR_UA"
fi
for package in $packages; do
  installed=0
  attempt_num=0
  while [ $installed -eq 0 ]; do
    attempt_num=$((attempt_num+1))
    sudo apt-get install -y $package && installed=1
    if [[ $attempt_num -gt $INSTALL_ATTEMPT_NUM_MAX ]]; then
      echo "Error: installation of package $package failed after $attempt_num attempts"
      echo "Please retry installation procedure."
      exit 1
    fi
  done
done
# Build I2S kernel module
PI_MODEL=$(cat /proc/device-tree/model | awk '{print $3}')
if [[ $PI_MODEL -eq 4 ]]; then
  I2S_MODULE_CFLAGS="-DRPI_4B"
fi

if [[ -n "$I2S_MODE" ]]; then
  case $I2S_MODE in
    master)
      if [[ -z "$I2S_MODULE_CFLAGS" ]]; then
        I2S_MODULE_CFLAGS=-DI2S_MASTER
      else
        I2S_MODULE_CFLAGS="$I2S_MODULE_CFLAGS -DI2S_MASTER"
       fi
      ;;
    slave)
      # no flags needed for I2S slave compilation
      ;;
    *)
      echo Error: I2S mode not known for XMOS device $XMOS_DEVICE.
      exit 1
    ;;
  esac
  I2S_BUILD_DIR=$RPI_SETUP_DIR/loader/i2s_$I2S_MODE
  pushd $I2S_BUILD_DIR > /dev/null
  if [[ -n "$I2S_MODULE_CFLAGS" ]]; then
    CMD="make CFLAGS_MODULE='$I2S_MODULE_CFLAGS'"
  else
    CMD=make
  fi
  echo $CMD
  eval $CMD
  if [[ $? -ne 0 ]]; then
    echo "Error: I2S kernel module build failed"
    exit 1
  fi
fi

popd > /dev/null

# Copy the udev rules files if device is UA
if [[ -n "$UA_MODE" ]]; then
  echo "Add UDEV rules for XMOS devices"
  sudo cp $RPI_SETUP_DIR/resources/99-xmos.rules /etc/udev/rules.d/
fi

# Move existing files to back up
if [[ -e ~/.asoundrc ]]; then
  chmod a+w ~/.asoundrc
  cp ~/.asoundrc ~/.asoundrc.bak
fi
if [[ -e /usr/share/alsa/pulse-alsa.conf ]]; then
  sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
fi

# Check XMOS device for asoundrc selection.
if [[ -z "$ASOUNDRC_TEMPLATE" ]]; then
  echo Error: sound card config not known for XMOS device $XMOS_DEVICE.
  exit 1
fi

# Apply changes
sudo /etc/init.d/alsa-utils restart

if [[ -n "$I2S_MODE" ]]; then
  # Create the script to run after each reboot and make the soundcard available
  i2s_driver_script=$RPI_SETUP_DIR/resources/load_i2s_driver.sh
  rm -f $i2s_driver_script

  # Sometimes with Buster on RPi3 the SYNC bit in the I2S_CS_A_REG register is not set before the drivers are loaded
  # According to section 8.8 of https://cs140e.sergio.bz/docs/BCM2837-ARM-Peripherals.pdf
  # this bit is set after 2 PCM clocks have occurred.
  # To avoid this issue we add a 1-second delay before the drivers are loaded
  echo "sleep 1"  >> $i2s_driver_script

  I2S_NAME=i2s_$I2S_MODE
  I2S_MODULE=$RPI_SETUP_DIR/loader/$I2S_NAME/${I2S_NAME}_loader.ko
  echo "sudo insmod $I2S_MODULE"                            >> $i2s_driver_script

  echo "# Run Alsa at startup so that alsamixer configures" >> $i2s_driver_script	
  echo "arecord -d 1 > /dev/null 2>&1"                      >> $i2s_driver_script	
  echo "aplay dummy > /dev/null 2>&1"                       >> $i2s_driver_script
fi

if [[ -n "$DAC_SETUP" ]]; then
  pushd $RPI_SETUP_DIR/resources/clk_dac_setup/ > /dev/null
  make
  popd > /dev/null
  dac_and_clks_script=$RPI_SETUP_DIR/resources/init_dac_and_clks.sh
  rm -f $dac_and_clks_script
  # Configure the clocks only if RaspberryPi is configured as I2S master
  if [[ "$I2S_MODE" = "master" ]]; then
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_mclk"                  >> $dac_and_clks_script
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_bclk"                  >> $dac_and_clks_script
  fi
  # Note that only the substring xvfXXXX from $XMOS_DEVICE is used in the lines below
  echo "python $RPI_SETUP_DIR/resources/clk_dac_setup/setup_dac.py $(echo $XMOS_DEVICE | cut -c1-7)" >> $dac_and_clks_script
  echo "python $RPI_SETUP_DIR/resources/clk_dac_setup/reset_xvf.py $(echo $XMOS_DEVICE | cut -c1-7)" >> $dac_and_clks_script
fi

if [[ -n "$DAC_SETUP" ]]; then
  audacity_script=$RPI_SETUP_DIR/resources/run_audacity.sh
  rm -f $audacity_script
  echo "#!/usr/bin/env bash" >> $audacity_script
  echo "/usr/bin/audacity &" >> $audacity_script
  echo "sleep 5" >> $audacity_script
  if [[ "$I2S_MODE" = "master" ]]; then
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_bclk >> /dev/null" >> $audacity_script
  fi
  sudo chmod +x $audacity_script
  sudo mv $audacity_script /usr/local/bin/audacity
fi

# Regenerate crontab file with new commands
rm -f $RPI_SETUP_DIR/resources/crontab

# Setup the crontab to restart I2S at reboot
if [ -n "$I2S_MODE" ] || [ -n "$DAC_SETUP" ]; then
  if [[ -n "$I2S_MODE" ]]; then
    echo "@reboot sh $i2s_driver_script" >> $RPI_SETUP_DIR/resources/crontab
  fi

  if [[ -n "$DAC_SETUP" ]]; then
    echo "@reboot sh $dac_and_clks_script" >> $RPI_SETUP_DIR/resources/crontab
  fi
popd > /dev/null
fi
# Setup the crontab to copy the .asoundrc file at reboot
# Delay the action by 10 seconds to allow the host to boot up
# This is needed to address the known issue in Raspian Buster:
# https://forums.raspberrypi.com/viewtopic.php?t=295008
echo "@reboot sleep 15 && cp $ASOUNDRC_TEMPLATE ~/.asoundrc" >> $RPI_SETUP_DIR/resources/crontab

# Update crontab
crontab $RPI_SETUP_DIR/resources/crontab

echo "To enable all interfaces, this Raspberry Pi must be rebooted."

