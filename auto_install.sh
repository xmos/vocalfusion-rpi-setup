#!/usr/bin/env bash
SCRIPTS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/scripts

$SCRIPTS_DIR/i2s_i2c_setup-main.sh


if [ -e /usr/share/alsa/pulse-alsa.conf ] ; then
    # Rename existing file
    sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
    sudo mv ~/.config/lxpanel/LXDE-pi/panels/panel ~/.config/lxpanel/LXDE-pi/panels/panel.bak
fi


echo To enable the i2s device, this pi must now be rebooted
echo type 'sudo reboot' below to do this
