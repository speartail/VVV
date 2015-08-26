#!/bin/bash

TARGET=/etc/nginx/custom-sites/speartail.conf

host=$(mktemp)
conf=$(mktemp)

for site in ../site-* ; do
  name=$(echo $site | cut -f2 -d '-')

  echo "Processing: ${name}"

  # hosts
  echo ${name}.wordpress.dev >> $host

  # nginx configuration
  cat <<_EOF_ >> $conf
################################################################
# $name
#
# Host: http://${name}.wordpress.dev
# Path: /srv/www/${site}
server {
    listen       80;
    listen       443 ssl;
    server_name  ${name}.wordpress.dev *.${name}.wordpress.dev ~^${name}\.wordpress\.\d+\.\d+\.\d+\.\d+\.xip\.io$;
    root         /srv/www/${site};
    include      /etc/nginx/nginx-wp-common.conf;
}
_EOF_
done

mv $host vvv-hosts
sudo mv $conf $TARGET
