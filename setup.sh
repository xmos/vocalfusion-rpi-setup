#!/usr/bin/env bash
pushd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null
RPI_SETUP_DIR="$( pwd )"

# Disable the built-in audio output so there is only one audio
# device in the system
sudo sed -i -e 's/dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt

# Enable the i2s device tree
sudo sed -i -e 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt

# Add modules to enable the I2C Peripherals and Direct Memory Access
# Controller modules that the sound card driver depends on
if ! grep -q "snd_soc_bcm2708" /etc/modules; then
  sudo sh -c 'echo snd_soc_bcm2708     >> /etc/modules'
fi
if ! grep -q "snd_soc_bcm2708_i2s" /etc/modules; then
  sudo sh -c 'echo snd_soc_bcm2708_i2s >> /etc/modules'
fi
if ! grep -q "bcm2708_dmaengine" /etc/modules; then
  sudo sh -c 'echo bcm2708_dmaengine     >> /etc/modules'
fi

echo "Installing Raspberry Pi kernel headers"
sudo apt-get install raspberrypi-kernel-headers


# Build loader and insert it into the kernel
pushd $RPI_SETUP_DIR/loader > /dev/null
make
popd > /dev/null

if [ -e ~/.asoundrc ] ; then
    chmod a+w ~/.asoundrc
    cp ~/.asoundrc ~/.asoundrc.bak
fi

# Move existing files to back up
if [ -e /usr/share/alsa/pulse-alsa.conf ] ; then
    sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
    sudo mv ~/.config/lxpanel/LXDE-pi/panels/panel ~/.config/lxpanel/LXDE-pi/panels/panel.bak
fi

# Check args for asoundrc selection. Default to VF Stereo.
if [ $# -eq 1 ] && [ $1 = "vocalfusion" ] ; then
    cp $RPI_SETUP_DIR/resources/asoundrc_vf ~/.asoundrc
else
    cp $RPI_SETUP_DIR/resources/asoundrc_vf_stereo ~/.asoundrc
fi

cp $RPI_SETUP_DIR/resources/panel ~/.config/lxpanel/LXDE-pi/panels/panel

# Make the asoundrc file read-only otherwise lxpanel rewrites it
# as it doesn't support anything but a hardware type device
chmod a-w ~/.asoundrc


# Apply changes
sudo /etc/init.d/alsa-utils restart


# Create the script to run after each reboot and make the soundcard available
i2s_driver_script=$RPI_SETUP_DIR/resources/load_i2s_driver.sh
rm -f i2s_driver_script
echo "cd $RPI_SETUP_DIR"                          >> $i2s_driver_script
echo "sudo insmod loader/loader.ko"               >> $i2s_driver_script


# Configure the I2C - disable the default built-in driver
sudo sed -i -e 's/#\?dtparam=i2c_arm=on/dtparam=i2c_arm=off/' /boot/config.txt
if ! grep -q "i2c-bcm2708" /etc/modules-load.d/modules.conf; then
  sudo sh -c 'echo i2c-bcm2708 >> /etc/modules-load.d/modules.conf'
fi
if ! grep -q "options i2c-bcm2708 combined=1" /etc/modprobe.d/i2c.conf; then
  sudo sh -c 'echo "options i2c-bcm2708 combined=1" >> /etc/modprobe.d/i2c.conf'
fi


# Build a new I2C driver
pushd $RPI_SETUP_DIR/i2c-gpio-param > /dev/null
make || exit $?
popd > /dev/null


# Create script to insert module into the kernel
i2c_driver_script=$RPI_SETUP_DIR/resources/load_i2c_gpio_driver.sh
rm -f $i2c_driver_script
echo "cd $RPI_SETUP_DIR/i2c-gpio-param"                                            >> $i2c_driver_script
echo "# Load the i2c bit banged driver"                                            >> $i2c_driver_script
echo "sudo insmod i2c-gpio-param.ko"                                               >> $i2c_driver_script
echo "# Instantiate a driver at bus id=1 on same pins as hw i2c with 1sec timeout" >> $i2c_driver_script
echo "sudo sh -c 'echo "1 2 3 5 100 0 0 0" > /sys/class/i2c-gpio/add_bus'"         >> $i2c_driver_script
echo "# Remove the default i2c-gpio instance"                                      >> $i2c_driver_script
echo "sudo sh -c 'echo 7 > /sys/class/i2c-gpio/remove_bus'"                        >> $i2c_driver_script

echo "# Run Alsa at startup so that alsamixer configures"                          >> $i2c_driver_script
echo "arecord -d 1 > /dev/null 2>&1"                                               >> $i2c_driver_script
echo "aplay dummy > /dev/null 2>&1"                                                >> $i2c_driver_script


# Setup the crontab to restart I2S/I2C at reboot
rm -f $RPI_SETUP_DIR/resources/crontab
echo "@reboot sh $i2s_driver_script" >> $RPI_SETUP_DIR/resources/crontab
echo "@reboot sh $i2c_driver_script" >> $RPI_SETUP_DIR/resources/crontab
crontab $RPI_SETUP_DIR/resources/crontab

echo "To enable I2S, this Raspberry Pi must be rebooted."

popd > /dev/null
