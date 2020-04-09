#!/usr/bin/env bash

set -eEuo pipefail


if dpkg -l | grep --quiet 9mount; then
  echo "9mount is already installed"
else
  echo "Installing 9mount"
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y 9mount
fi

_mount() {
  local src=$1
  local tgt=$2

  test -d $tgt || mkdir -p $tgt

  9mount -u virtio!${src} $tgt
}

_mount be4352993449f4e31cd7f75cdfc66c7 /srv/www
_mount 5135071337af27114a2eac97b135f12 /var/log/memcached
_mount 60a2763146cbcc44148210a3936abc6 /var/log/nginx
_mount 0d82c342abf7a1e6b81b087ad94acb4 /var/log/php
_mount 26e00b958049d2609286d50af30ca98 /var/log/provisioners
