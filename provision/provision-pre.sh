#!/bin/bash

MIRROR=http://mirror.nus.edu.sg/ubuntu

cat <<EOF > /etc/apt/sources.list
deb $MIRROR trusty main universe multiverse restricted
deb $MIRROR trusty-updates main universe multiverse restricted
deb $MIRROR trusty-security main universe multiverse restricted
EOF

cp /usr/share/zoneinfo/Asia/Singapore /etc/localtime
