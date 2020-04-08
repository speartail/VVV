#!/usr/bin/env bash

set -eEuo pipefail


if dpkg -l | grep --quiet 9mount; then
  echo "9mount is already installed"
else
  echo "Installing 9mount"
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y 9mount
fi


env | sort

exit 1
