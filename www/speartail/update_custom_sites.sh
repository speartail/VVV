#!/bin/bash

if [[ $(hostname) != "vvv" ]] ; then
  echo "You must run this inside the VM, not on the host!"
  exit 1
fi

SQLINIT=/srv/database/init-custom.sql
NGINX=/etc/nginx/custom-sites/speartail.conf

host=$(mktemp)
conf=$(mktemp)
sql=$(mktemp)

for site in ../site-* ; do
  site=$(basename $site)
  name=$(echo $site | cut -f2 -d '-')
  fqdn="${name}.wordpress.dev"

  echo "Processing: ${name}"

  # hosts
  echo ${fqdn} >> $host

  # sql
  cat <<_EOF_ >> $sql
CREATE DATABASE IF NOT EXISTS \`${name}\`;
GRANT ALL PRIVILEGES ON \`${name}\`.* TO 'wp'@'localhost' IDENTIFIED BY 'wp';
GRANT ALL PRIVILEGES ON \`${name}\`.* TO 'external'@'%' IDENTIFIED BY 'external';

_EOF_

  # nginx configuration
  cat <<_EOF_ >> $conf
################################################################
# $name
#
# Host: http://${fqdn}
# Path: /srv/www/${site}
server {
    listen       80;
    listen       443 ssl;
    server_name  ${fqdn} *.${fqdn} ~^${name}\.wordpress\.\d+\.\d+\.\d+\.\d+\.xip\.io$;
    root         /srv/www/${site};
    include      /etc/nginx/nginx-wp-common.conf;
}

_EOF_

done

# hosts
mv $host vvv-hosts

# sql
echo 'FLUSH PRIVILEGES;' >> $sql
sudo mv $sql $SQLINIT
mysql < $SQLINIT

# nginx
sudo mv $conf $NGINX
sudo chown root:root $NGINX
sudo chmod 644 $NGINX
sudo service nginx restart
