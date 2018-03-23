#!/usr/bin/env bash

# The working directory
RPI_SETUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# Disable the built-in audio output so there is only one audio
# device in the system
#
sudo sed -i -e 's/dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt

#
# Enable the i2s device tree
#
sudo sed -i -e 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt

# Add modules to enable the I2C Peripherals and Direct Memory Access
# Controller modules that the sound card driver depends on
sudo sh -c 'echo snd_soc_bcm2708     >> /etc/modules'
sudo sh -c 'echo snd_soc_bcm2708_i2s >> /etc/modules'
sudo sh -c 'echo bcm2708_dmaengine   >> /etc/modules'

# Download kernal source - this will take some time
cd $RPI_SETUP_DIR
sudo apt-get -y install bc
sudo apt-get -y install libncurses5-dev
if [ ! -d rpi-source ] ; then
    git clone git://github.com/notro/rpi-source.git
fi
pushd $RPI_SETUP_DIR/rpi-source > /dev/null
python rpi-source --skip-gcc
popd > /dev/null

#
# Build simple sound card driver
# Modify the driver source to have the correct BCLK ratio
#
pushd $RPI_SETUP_DIR/snd_driver > /dev/null
cp ~/linux/sound/soc/generic/simple-card.c ./asoc_simple_card.c
patch -p1 asoc_simple_card.c < bclk_patch.txt
make
popd > /dev/null

#
# Build loader and insert it into the kernel
#
pushd $RPI_SETUP_DIR/loader > /dev/null
make
popd > /dev/null

if [ -e ~/.asoundrc ] ; then
    cp ~/.asoundrc ~/.asoundrc.bak
    chmod a+w ~/.asoundrc
fi

# Move existing files to back up
if [ -e /usr/share/alsa/pulse-alsa.conf ] ; then
    sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
    sudo mv ~/.config/lxpanel/LXDE-pi/panels/panel ~/.config/lxpanel/LXDE-pi/panels/panel.bak
fi

cp $RPI_SETUP_DIR/resources/asoundrc ~/.asoundrc
cp $RPI_SETUP_DIR/resources/panel ~/.config/lxpanel/LXDE-pi/panels/panel

#
# Make the asoundrc file read-only otherwise lxpanel rewrites it
# as it doesn't support anything but a hardware type device
#
chmod a-w ~/.asoundrc

# Apply changes
sudo /etc/init.d/alsa-utils restart

#
# Create the script to run after each reboot and make the soundcard available
#
i2s_driver_script=$RPI_SETUP_DIR/resources/load_i2s_driver.sh
echo "cd $RPI_SETUP_DIR"                                > $i2s_driver_script
echo "sudo insmod loader/loader.ko"               >> $i2s_driver_script

#
# Configure the I2C - disable the default built-in driver
#
sudo sed -i -e 's/#\?dtparam=i2c_arm=on/dtparam=i2c_arm=off/' /boot/config.txt
sudo sh -c 'echo i2c-bcm2708 >> /etc/modules-load.d/modules.conf'
sudo sh -c 'echo "options i2c-bcm2708 combined=1" >> /etc/modprobe.d/i2c.conf'

#
# Build a new I2C driver
#
cd $RPI_SETUP_DIR
git clone git://github.com/kadamski/i2c-gpio-param.git
pushd $RPI_SETUP_DIR/i2c-gpio-param > /dev/null
make
popd > /dev/null

#
# Create script to insert module into the kernel
#
i2c_driver_script=$RPI_SETUP_DIR/resources/load_i2c_gpio_driver.sh

echo "cd $RPI_SETUP_DIR/i2c-gpio-param"                                                  > $i2c_driver_script
echo "# Load the i2c bit banged driver"                                            >> $i2c_driver_script
echo "sudo insmod i2c-gpio-param.ko"                                               >> $i2c_driver_script
echo "# Instantiate a driver at bus id=1 on same pins as hw i2c with 1sec timeout" >> $i2c_driver_script
echo "sudo sh -c 'echo "1 2 3 5 100 0 0 0" > /sys/class/i2c-gpio/add_bus'"         >> $i2c_driver_script
echo "# Remove the default i2c-gpio instance"                                      >> $i2c_driver_script
echo "sudo sh -c 'echo 7 > /sys/class/i2c-gpio/remove_bus'"                        >> $i2c_driver_script

echo "# Run Alsa at startup so that alsamixer configures"                          >> $i2c_driver_script
echo "arecord -d 1 > /dev/null 2>&1"                                               >> $i2c_driver_script
echo "aplay dummy > /dev/null 2>&1"                                                >> $i2c_driver_script

#
# Setup the crontab to restart I2S/I2C at reboot
#
echo "@reboot sh $i2s_driver_script"  > $RPI_SETUP_DIR/resources/crontab
echo "@reboot sh $i2c_driver_script" >> $RPI_SETUP_DIR/resources/crontab
crontab $RPI_SETUP_DIR/resources/crontab

echo To enable the i2s device, this pi must now be rebooted
echo type 'sudo reboot' below to do this
