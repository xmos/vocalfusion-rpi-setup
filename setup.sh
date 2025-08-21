#!/usr/bin/env bash

# Directory of this script
rpi_setup_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# Valid/supported device configurations
valid_xmos_devices=(xvf3800-intdev-extmclk xvf3800-intdev xvf3800-ua xvf3610-int xvf3610-ua)

# Comma and space separate the devices
printf -v devices_display_string '%s, ' "${valid_xmos_devices[@]}"

# Strip the last comma and space
devices_display_string="${devices_display_string%, }"

# Packages
max_install_attempts=3
packages=(python3-matplotlib python3-numpy libatlas-base-dev audacity libreadline-dev libncurses-dev)

# Additional packages for UA devices
packages_ua=(libusb-1.0-0-dev libevdev-dev libudev-dev)

# Configurable variables (either set according to device or specified by a flag)
i2s_mode=
usb_mode=
xmos_device=
rate=48000    # -r flag
no_update=    # -N flag
no_packages=  # -p flag
yes_reboot=   # -R flag
no_reboot=    # -n flag
ext_mclk=

# Utility functions for logging
hint() {
    echo -e "\033[0;95m[HINT]\033[0m $1" >&2
}

info() {
    echo -e "\033[0;34m[INFO]\033[0m $1" >&2
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

warn() {
    if (( debug > 0 )); then
        echo -e "\033[0;33m[WARN]\033[0m $1" >&2
    fi
}

debug() {
    if (( debug > 1 )); then
        echo -e "\033[0;36m[DEBUG]\033[0m $1" >&2
    fi
}

usage() {
    printf '%s\n' \
        'This script sets up the Raspberry Pi to use different XMOS devices.' \
        "Usage: $0 <device-type> [OPTIONS]" \
        "Valid device types: $devices_display_string" \
        "Options:" \
        "    -v|--verbose      Increase verbosity (multiple for more detail)." \
        "    -h|--help         Show this help message." \
        "    -r|--rate <rate>  Set the sample rate to use (Hz), must match the rate of the XMOS software (default: 48000). Does not affect UA devices." \
        "    -N|--no-update    Don't update the Raspberry Pi's packages." \
        "    -p|--no-packages  Don't install the required packages." \
        "    -R|--reboot       Say yes to rebooting after setup." \
        "    -n|--no-reboot    Say no to rebooting after setup." >&2
}

# Parse args
temp_err=$(mktemp)
if ! OPTS=$(getopt -o hvr:NRnp --long help,verbose,rate,no-update,reboot,no-reboot,no-packages -n "$0" -- "$@" 2>"$temp_err"); then
    # Make sure errors are printed nicely and give usage if there are errors
    while IFS=: read -r err_line; do
        error "$(sed 's/.*: //' <<< "$err_line")"
    done < "$temp_err"
    rm -f "$temp_err"
    echo
    usage
    exit 1
fi

# Clean up temp file if we succeeded
rm -f "$temp_err"

# Do stuff based on options
eval set -- "$OPTS"
while true; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            ((debug++))
            shift
            ;;
        -r|--rate)
            rate="${2,,}"
            shift 2
            ;;
        -N|--no-update)
            no_update=y
            shift
            ;;
        -p|--no-packages)
            no_packages=y
            shift
            ;;
        -R|--reboot)
            yes_reboot=y
            shift
            ;;
        -n|--no-reboot)
            no_reboot=y
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            error "Invalid option: $1"
            echo
            usage
            exit 1
            ;;
    esac
done

if [[ -n "$no_reboot" && -n "$yes_reboot" ]]; then
    error "Incompatible reboot flags."
    echo
    usage
    exit 1
fi

# Check for unexpected arguments
if (( $# < 1 )); then
    error 'Device type is required.'
    echo
    usage
    exit 1
fi

xmos_device="${1,,}"

if (( $# > 1 )); then
    error "Unexpected arguments, expected 1, got $#"
    echo
    usage
    exit 1
fi

# Check valid device
if [[ ! " ${valid_xmos_devices[@]} " =~ " $xmos_device " ]]; then
    error "Invalid device type: $xmos_device"
    hint "Valid device types: $devices_display_string"
    exit 1
fi

# Select device options
case $xmos_device in
    xvf3800-intdev-extmclk)
        i2s_mode=master
        io_exp_and_dac_setup=y
        asoundrc_template=$rpi_setup_dir/resources/asoundrc_vf
        ext_mclk=y
        ;;
    xvf3800-intdev)
        i2s_mode=master
        io_exp_and_dac_setup=y
        asoundrc_template=$rpi_setup_dir/resources/asoundrc_vf
        ;;
    xvf3610-int)
        i2s_mode=master
        io_exp_and_dac_setup=y
        asoundrc_template=$rpi_setup_dir/resources/asoundrc_vf_xvf3610
        ext_mclk=y
        ;;
    xvf3610-ua|xvf3800-ua)
        usb_mode=y
        i2s_mode=slave
        ;;
    *)
        # This shouldn't happen as we've already validated the input device
        error "Unknown XMOS device type $xmos_device." >&2
        echo
        usage
        exit 1
        ;;
esac

# Check rate is valid
rate="${rate,,}"
case $rate in
    48000|16000)
        ;;
    48khz|48k)
        rate=48000
        ;;
    32khz|32k)
        rate=32000
        ;;
    16khz|16k)
        rate=16000
        ;;
    *)
        error "Invalid clock rate: $rate"
        hint 'Only 16kHz, 32kHz, or 48kHz are supported.'
        exit 1
        ;;
esac

debug "usb_mode: $usb_mode, i2s_mode: $i2s_mode, io_exp_and_dac_setup: $io_exp_and_dac_setup, asoundrc_template: $asoundrc_template, rate: $rate"

# If an external MCLK is needed, we need to check if the Pi is compatible.
if [[ -n "$ext_mclk" ]]; then
    rpi_type=$(tr '\0' ',' < /proc/device-tree/compatible | cut -d, -f2)
    case $rpi_type in
        500|5-compute-module|5-model-b)
            # PiGPIO does not support the Raspberry Pi 5 likely due to the lack of documentation:
            # https://github.com/raspberrypi/documentation/issues/3285
            # https://github.com/joan2937/pigpio/issues/589
            error "The Raspberry Pi 5 is not supported for configurations requiring an external MCLK."
            exit 1
            ;;
        *)
            ;;
    esac
fi

# Begin setting up RasPi
rpi_config_root=
if [[ -f '/boot/firmware/config.txt' ]]; then
    info 'Config found at /boot/firmware/config.txt'
    rpi_config_root=/boot/firmware
elif [[ -f '/boot/config.txt' ]]; then
    info 'Config found at /boot/config.txt'
    rpi_config_root=/boot
else
    error "Couldn't find Raspberry Pi configuration file."
    hint 'Check if either /boot/config.txt or /boot/firmware/config.txt exist.'
    exit 1
fi
rpi_config="$rpi_config_root/config.txt"

# Disable built-in audio
sudo sed -i '/^dtparam=audio=on$/ s/^/#/' "$rpi_config"
info "Disabled built-in audio in $rpi_config."

# Enable I2S devicetree
sudo sed -i '/^#dtparam=i2s=on$/s/^#//' "$rpi_config"
info "Enabled I2S devicetree in $rpi_config."

# Enable I2C devicetree
sudo raspi-config nonint do_i2c 1
sudo raspi-config nonint do_i2c 0
info 'Enabled I2C devicetree.'

# Set I2C baudrate to 100k
if ! grep -q '^dtparam=i2c_arm_baudrate=100000$' "$rpi_config"; then
    echo 'dtparam=i2c_arm_baudrate=100000' | sudo tee -a "$rpi_config" >/dev/null
fi
info 'Set I2C baud to 100k.'

# Enable SPI
sudo raspi-config nonint do_spi 1
sudo raspi-config nonint do_spi 0
info 'Enabled SPI.'

# Update system
if [[ -z "$no_update" ]]; then
    info 'Updating packages...'
    for ((attempt=1; attempt <= max_install_attempts; attempt++)); do
        # Attempt to update system
        if sudo apt-get update -y; then
            if sudo apt-get upgrade -y; then
                break
            fi
        fi

        warn "Failed to upgrade required packages, attempt $attempt / $max_install_attempts"

        if (( attempt == $max_install_attempts )); then
            error 'Failed to update and upgrade packages.'
            hint 'Run \`sudo apt update\` and \`sudo apt upgrade\` manually, troubleshoot, then try again.'
            exit 1
        fi
    done
else
    info 'Skipping update as --no-update used.'
fi

# Add USB audio packages if required
if [[ -n "$usb_mode" ]]; then
    debug "Appending USB audio packages to package list."
    packages=(${packages[@]} ${packages_ua[@]})
fi

# Install required packages
if [[ -z "$no_packages" ]]; then
    info "Attempting to install required packages: ${packages[*]}"
    for ((attempt=1; attempt <= max_install_attempts; attempt++)); do
        # Attempt to install all packages
        if sudo apt-get install -y ${packages[*]}; then
            break
        fi
        
        warn "Failed to install required packages, attempt $attempt / $max_install_attempts"

        # Increasingly sleep between attempts
        if (( attempt != max_install_attempts )); then
            debug "Sleeping for $((attempt * 2)) seconds..."
            sleep $((attempt * 2))
        fi
    done
else
    info 'Skipping package install as --no-packages used.'
fi

info 'Checking required packages are installed.'

# Check for failed package installations
for package in ${packages[@]}; do
    debug "Checking $package..."
    if ! dpkg -s $package &>/dev/null; then
        failed_packages+=($package)
        warn "Package $package failed to install."
    fi
done

# Output failed packages
if (( ${#failed_packages[@]} > 0 )); then
    error "Failed to install the following packages after $max_install_attempts attempts:"
    printf '         - %s\n' "${failed_packages[@]}"
    hint 'Please check network connection and package names, then try again.'
    exit 1
fi

# Install XMOS devicetree overlay
if [[ -z "$usb_mode" ]]; then
    info 'Making and installing XMOS DTO.'
    RPI_CONFIG_ROOT=$rpi_config_root make -C $rpi_setup_dir/overlays install

    # Enable XMOS devicetree overlay
    info 'Enabling DTO now.'
    sudo dtoverlay dummy-xmos-device
else
    debug 'UA device, skipping overlay installation.'
fi

# Copy the udev rules files if device is UA
if [[ -n "$usb_mode" ]]; then
    info 'Adding UDEV rules for XMOS devices.'
    sudo cp $rpi_setup_dir/resources/99-xmos.rules /etc/udev/rules.d/
fi

# Move existing files to back up
if [[ -n "$asoundrc_template" ]]; then
    if [[ -e ~/.asoundrc ]]; then
        info 'Moving ~/.asoundrc to ~/.asoundrc.bak'
        chmod u+w ~/.asoundrc
        cp ~/.asoundrc ~/.asoundrc.bak
    fi

    if [[ -e /usr/share/alsa/pulse-alsa.conf ]]; then
        info 'Moving /usr/share/alsa/pulse-alsa.conf to /usr/share/alsa/pulse-alsa.conf.bak'
        sudo mv /usr/share/alsa/pulse-alsa.conf /usr/share/alsa/pulse-alsa.conf.bak
    fi

    # Create new asoundrc with specified rate
    info "Generating asoundrc with specified rate at ${asoundrc_template}"
    sed "s/{{rate}}/$rate/g" "$asoundrc_template.template" > "${asoundrc_template}"

    # Copy asoundrc config to correct location
    info "Copying asoundrc: $asoundrc_template to ~/.asoundrc"
    cp $asoundrc_template ~/.asoundrc

    # Apply changes
    info 'Applying .asoundrc changes.'
    sudo /etc/init.d/alsa-utils restart
fi

if [[ -n "$i2s_mode" ]]; then
    # Create the script to run after each reboot and make the soundcard available
    i2s_setup_script=$rpi_setup_dir/resources/setup_i2s_${i2s_mode}.sh
    info 'Removing old I2S setup script.'
    rm -f $i2s_setup_script

    info "Creating I2S setup script: $i2s_setup_script."

    # Sometimes with Buster on RPi3 the SYNC bit in the I2S_CS_A_REG register is not set before the drivers are loaded
    # According to section 8.8 of https://cs140e.sergio.bz/docs/BCM2837-ARM-Peripherals.pdf
    # this bit is set after 2 PCM clocks have occurred.
    # To avoid this issue we add a 1-second delay before the drivers are loaded
    echo "sleep 1"  >> $i2s_setup_script

    echo "# Run Alsa at startup so that alsamixer configures" >> $i2s_setup_script	
    echo "arecord -d 1 > /dev/null 2>&1"                      >> $i2s_setup_script	
    echo "aplay dummy > /dev/null 2>&1"                       >> $i2s_setup_script

    if [[ "$i2s_mode" = "master" ]]; then
        info "I2S mode is $i2s_mode, adding clock preconfiguration to setup script..."

        echo "# Preconfigure i2s clocks to 48kHz"               >> $i2s_setup_script
        # wait a bit as it doesn't work otherwise, this is probably caused
        # by the same process that is deleting .asoundrc
        echo "sleep 15"                                         >> $i2s_setup_script
        echo "arecord -Dhw:XMOSDevice,0 -c2 -fS32_LE -r$rate -s1 /dev/null" >> $i2s_setup_script
    fi
fi

if [[ -n "$io_exp_and_dac_setup" ]]; then
  # Build setup binaries
  info 'Building MCLK and BCLK setup binaries...'
  make -C $rpi_setup_dir/resources/clk_dac_setup/

  # Create DAC and CLK setup script
  dac_and_clks_script=$rpi_setup_dir/resources/init_dac_and_clks.sh
  info 'Removing old DAC and CLK setup script.'
  rm -f $dac_and_clks_script

  info "Creating DAC and CLK setup script: $dac_and_clks_script."
  # Configure the clocks only if RaspberryPi is configured as I2S master
  if [[ -n "$ext_mclk" ]]; then
    debug "Adding MCLK configuration to script."
    echo "sudo $rpi_setup_dir/resources/clk_dac_setup/setup_mclk"   >> $dac_and_clks_script
  fi

  echo "python $rpi_setup_dir/resources/clk_dac_setup/setup_io_exp_and_dac.py $xmos_device" >> $dac_and_clks_script

  info 'Running DAC and CLK script now.'
  sh $dac_and_clks_script
fi

# Regenerate crontab file with new commands
crontab_file=$rpi_setup_dir/resources/crontab
if [[ -n "$usb_mode" ]]; then
    crontab_file="${crontab_file}_usb"
elif [[ -n "$i2s_mode" ]]; then
    crontab_file="${crontab_file}_i2s_${i2s_mode}"
fi

info "Removing crontab file $crontab_file"
rm -f $crontab_file
touch $crontab_file

# Setup the crontab to restart I2S at reboot
if [[ -n "$i2s_mode" ]]; then
    echo "@reboot sh $i2s_setup_script" >> $crontab_file
fi

if [[ -n "$io_exp_and_dac_setup" ]]; then
    echo "@reboot sh $dac_and_clks_script" >> $crontab_file
fi

# Setup the crontab to copy the .asoundrc file at reboot
# Delay the action to allow the host to boot up
# This is needed to address the known issue in Raspian Buster:
# https://forums.raspberrypi.com/viewtopic.php?t=295008
if [[ -n "$asoundrc_template" ]]; then
    echo "@reboot cp $asoundrc_template ~/.asoundrc && sleep 20 && cp $asoundrc_template ~/.asoundrc" >> $crontab_file
fi

debug "New crontab file:\n$(<$crontab_file)"

# Update crontab
info 'Updating crontab with new file.'
crontab $crontab_file

# Need to reboot
if [[ -n "$yes_reboot" ]]; then
    info 'Rebooting now...'
    sudo reboot
elif [[ -n "$no_reboot" ]]; then
    info 'Skipped reboot.'
    exit 0
else
    info 'To apply changes, this Raspberry Pi must be rebooted.'
    read -rp 'Reboot now to apply changes? [Y/n] ' answer
    case "${answer,,}" in
        y|yes|"")
            info 'Rebooting now...'
            sudo reboot
            ;;
        *)
            info 'Reboot postponed. Changes will take effect after next reboot.'
            exit 0
            ;;
    esac
fi
