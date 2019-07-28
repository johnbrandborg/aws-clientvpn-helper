#!/bin/bash

echo -e "---------------------------- AWS Client VPN Helper ----------------------------\n"

# Load variables from Configuration file
. variables.cfg

# Check that all variables are available
REQUIRED_ARGUMENTS=("WORKDIR" "OVPNCFGFILE")

for REQUIRED in ${REQUIRED_ARGUMENTS[@]}; do
    if [ -z $(eval echo \$$REQUIRED) ]; then
        echo -e " ERROR: Configuration is missing the argument $REQUIRED.\n \
Required variables are ${REQUIRED_ARGUMENTS[@]}."; exit 1
    fi
done

# Make sure the working directory is present and has the setup script
if [ -f "$WORKDIR/`basename "$0"`" ]; then
    cd $WORKDIR
else
    echo " ERROR: The working directory doesn't look valid. \
    Please make sure you update variables.cfg"; exit 1
fi

# Main Execution

echo -e "\nStarting OpenVPN as a daemon task (SUDO)\n"
if [ ! -f openvpn.log ]; then
    echo " - Creating new log file openvpn.log"
    touch openvpn.log
fi

if [ -x "$(which openvpn)" ]; then
    sudo openvpn \
        --daemon \
        --config $OVPNCFGFILE \
        --log openvpn.log
else
    echo " ERROR: The OpenVPN executable could not be found. Exiting"; exit 1 
fi
