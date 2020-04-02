#!/bin/bash
#
# provision-network-functions.sh
#
# This file is for common network helper functions that get called in
# other provisioners

GREEN="\033[38;5;2m"
RED="\033[38;5;9m"
CRESET="\033[0m"

HOST=ppa.launchpad.net

network_detection() {
  echo " * Testing network connection"
  # Network Detection
  #
  # Make an HTTP request to ppa.launchpad.net to determine if outside access is available
  # to us. If 3 attempts with a timeout of 5 seconds are not successful, then we'll
  # skip a few things further in provisioning rather than create a bunch of errors.
  if [[ "$(wget --tries=3 --timeout=10 --spider --recursive --level=2 https://$HOST 2>&1 | grep 'connected')" ]]; then
    echo -e "${GREEN} * Succesful Network connection to $HOST detected...${CRESET}"
    ping_result="Connected"
  else
    echo -e "${RED} ! Network connection not detected. Unable to reach $HOST...${CRESET}"
    ping_result="Not Connected"
  fi
}

network_check() {
  network_detection
  if [[ ! "$ping_result" == "Connected" ]]; then
    echo -e "${RED} "
    echo "#################################################################"
    echo " "
    echo "Problem:"
    echo " "
    echo "Provisioning needs a network connection but none was found."
    echo "VVV tried to ping ppa.launchpad.net, and got no response."
    echo " "
    echo "Make sure you have a working internet connection, that you "
    echo "restarted after installing VirtualBox and Vagrant, and that "
    echo "they aren't blocked by a firewall or security software. If"
    echo "you can load https://ppa.launchpad.net in your browser, then VVV"
    echo "should be able to connect."
    echo " "
    echo "Also note that some users have reported issues when combined"
    echo "with VPNs, disable your VPN and reprovision to see if this is"
    echo "the cause."
    echo " "
    echo "Additionally, if you're at a contributor day event, be kind,"
    echo "provisioning involves downloading things, a full provision may "
    echo "ruin the wifi for everybody else :("
    echo " "
    echo "Network ifconfig output:"
    echo " "
    ifconfig
    echo " "
    echo "No network connection available, aborting provision. Try "
    echo "provisioning again once network connectivity is restored."
    echo "If that doesn't work, and you're sure you have a strong "
    echo "internet connection, open an issue on GitHub, and include the "
    echo "output above so that the problem can be debugged"
    echo " "
    echo "vagrant reload --provision"
    echo " "
    echo "https://github.com/Varying-Vagrant-Vagrants/VVV/issues"
    echo " "
    echo "#################################################################${CRESET}"

    exit 1
  fi
}
