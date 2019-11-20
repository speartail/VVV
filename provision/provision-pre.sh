#!/usr/bin/env bash

set -eEuo pipefail

MIRROR=sg
RELEASE=bionic

cat <<EOF > /etc/apt/sources.list
deb http://$MIRROR.releases.ubuntu.com/ubuntu $RELEASE          main universe multiverse restricted
deb http://$MIRROR.releases.ubuntu.com/ubuntu $RELEASE-updates  main universe multiverse restricted
deb http://$MIRROR.releases.ubuntu.com/ubuntu $RELEASE-security main universe multiverse restricted
EOF

sed -i /etc/apt/sources.list /etc/apt/sources.list.d/*.list -e '/deb-src/d' || true

cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime
