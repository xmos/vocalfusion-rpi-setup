#!/usr/bin/env bash
SCRIPTS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/scripts


if [ -e /usr/share/alsa/pulse-alsa.conf ] ; then
    # Back up existing files
    sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
    sudo mv ~/.config/lxpanel/LXDE-pi/panels/panel ~/.config/lxpanel/LXDE-pi/panels/panel.bak
fi

$SCRIPTS_DIR/i2s_i2c_setup.sh

echo To enable the i2s device, this pi must now be rebooted
echo type 'sudo reboot' below to do this
