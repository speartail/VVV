#!/usr/bin/env bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations included with Varying Vagrant Vagrants.

set -eEuo pipefail

. /srv/provision/lib.sh

# Error out early if the VM version is wrong
/srv/provision/vm-is-too-old.sh

apt_packages=(
  # Please avoid apostrophes in these comments - they break vim syntax
  # highlighting.

  linux-virtual-hwe-18.04
  virtualbox-guest-dkms

  # PHP7
  #
  # Install -fpm and -cli instead of the general package to avoid pulling in unneeded dependencies
  php$PHP_VERSION-fpm
  php$PHP_VERSION-cli

  # Common and dev packages for php
  php$PHP_VERSION-common
  php$PHP_VERSION-dev

  # Extra PHP modules that we find useful
  php$PHP_VERSION-bcmath
  php$PHP_VERSION-curl
  php$PHP_VERSION-gd
  php$PHP_VERSION-imap
  php$PHP_VERSION-json
  php$PHP_VERSION-mbstring
  php$PHP_VERSION-mysql
  php$PHP_VERSION-soap
  php$PHP_VERSION-xml
  php$PHP_VERSION-zip
  php-imagick
  php-memcache
  php-memcached
  php-pear
  php-ssh2
  php-xdebug
  php-yaml

  # nginx is installed as the default web server
  nginx

  # memcached is made available for object caching
  memcached

  # mariadb (drop-in replacement on mysql) is the default database
  mariadb-server

  # other packages that come in handy
  colordiff
  git
  git-lfs
  git-svn
  imagemagick
  make
  ngrep
  postfix
  python-pip
  python-setuptools
  python-wheel
  subversion
  unzip
  zip

  # Required for i18n tools
  gettext

  # Required for Webgrind
  graphviz

  # dos2unix
  # Allows conversion of DOS style line endings to something less troublesome
  # in Linux.
  dos2unix

  # nodejs for use by grunt
  g++
  nodejs
)

_header "Starting VVV Provisioner, this may take a few minutes"

export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_NO_INTERACTION=1

. /srv/provision/provision-network-functions.sh

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

# fix no tty warnings in provisioner logs
sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile

mkdir -p /vagrant

# Add the vagrant user to the www-data group so that it has better access
# to PHP and Nginx related files.
usermod -a -G www-data vagrant

date_time=$(date "+%Y.%m.%d_%H-%M-%S")
echo $date_time > /vagrant/provisioned_at
logfolder=/var/log/provisioners/${date_time}
logfile=${logfolder}/provisioner-main.log
mkdir -p ${logfolder}
touch ${logfile}
exec > >(tee -a ${logfile} )
exec 2> >(tee -a ${logfile} >&2 )


_header "Vagrant config files"
install -Dm0644 -t /vagrant /home/vagrant/version /srv/config/config.yml

_header "Setting up root/vagrant user profiles"

_msg "root"
install -Dm644 /srv/config/bash_aliases $HOME/.bash_aliases
. $HOME/.bash_aliases

_msg "vagrant"
for f in bash_aliases bash_profiles bash_prompt vimrc; do
  test -e /srv/config/$f && install -Dm644 /srv/config/$f /home/vagrant/.$f
done
mkdir -p /home/vagrant/.subversion
for f in servers config; do
  install -Dm644 /srv/config/subversion-$f /home/vagrant/.subversion/$f
done

_header "Early software configuration"
_msg "SSH"
install -Dm644 -t /etc/ssh /srv/config/ssh_*

_msg "MariaDB"
# Use debconf-set-selections to specify the default password for the root MariaDB
# account. This runs on every provision, even if MariaDB has been installed. If
# MariaDB is already installed, it will not affect anything.
echo mariadb-server-10.3 mysql-server/root_password password "root" | debconf-set-selections
echo mariadb-server-10.3 mysql-server/root_password_again password "root" | debconf-set-selections

if ! grep -q 'mysql' /etc/group; then
  groupadd -g 9001 mysql
fi

if ! id -u mysql >/dev/null 2>&1; then
  useradd -u 9001 -g mysql -G vboxsf -r mysql
fi

install -Dm644 -t /etc/mysql/conf.d /srv/config/mysql-config/vvv-core.cnf

_msg "Postfix"

# Use debconf-set-selections to specify the selections in the postfix setup. Set
# up as an 'Internet Site' with the host name 'vvv'. Note that if your current
# Internet connection does not allow communication over port 25, you will not be
# able to send mail, even with postfix installed.
echo postfix postfix/main_mailer_type select Internet Site | debconf-set-selections
echo postfix postfix/mailname string vvv | debconf-set-selections

network_check

_header "Configuring APT/DPKG"

_msg "Loading APT keys"
for key in /srv/config/apt-keys/*; do
  apt-key add $key >/dev/null
done

for key in 0xF1656F24C74CD1D8 0xA1715D88E1DF1F24; do
  apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 $key
done

_msg "Setting up APT repositories"
rm -f /etc/apt/sources.list.d/git-core* # git-core is now in vvv-sources.list
install -Dm644 /srv/config/apt-source-append.list /etc/apt/sources.list.d/vvv-sources.list

_msg "Updating sources"
set -x
_apt_update

_msg "Installing packages"
_apt_install ${apt_packages[@]}
_apt_upgrade

_msg "Cleaning up packages"
apt-get autoremove -y
apt-get clean

_header "Disabling unneeded services"
for s in atd cron lxcfs rsyslog unattended-upgrades; do
  systemctl disable $s.service --now
done

_header "Installing tools"

_msg "shyaml for bash provisioning"
pip install -U shyaml

sh /srv/config/homebin/xdebug_off
# Disable xdebug before any composer provisioning.

_msg "NVM"
if [[ -f ~/.nvm ]]; then
  nvm use system
  _rm ~/.nvm ~/.npm ~/.bower /srv/config/nvm
fi

if [[ $(nodejs --version | cut -f1 -d '.') != 'v10' ]]; then
  _msg "Forcing Node v10"
  apt remove nodejs -y
  _apt_install nodejs
fi

_msg "Adding graphviz symlink for Webgrind"
ln -sf /usr/bin/dot /usr/local/bin/dot

_msg "NPM"
npm install -g npm npm-check-updates

_msg "MailHog"
_get https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64 \
  /usr/local/bin/mailhog
install -Dm644 -t /etc/systemd/system /srv/config/mailhog-config/mailhog.service
systemctl daemon-reload
systemctl enable mailhog --now

_msg "MHSendmail"
_get https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64 \
  /usr/local/bin/mhsendmail

# Install ack-rep directory from the version hosted at beyondgrep.com as the
# PPAs for Ubuntu Precise are not available yet.
_msg "ack-grep as ack"
_get https://beyondgrep.com/ack-2.16-single-file /usr/local/bin/ack

_header "Composer"
mkdir -p /usr/local/src/composer/cache
set_perms
if ! command -v composer >/dev/null; then
  curl -sS "https://getcomposer.org/installer" | php
  mv composer.phar /usr/local/bin/composer
fi

set_perms

github_token=$(shyaml get-value general.github_token missing 2> /dev/null < /vagrant/config.yml)
if [[ "$github_token" != "missing" ]]; then
  _msg "A personal GitHub token was found, configuring composer"
  echo "$github_token" >> /srv/provision/github.token
  _composer config --global github-oauth.github.com "$github_token"
fi

# Update both Composer and any global packages. Updates to Composer are direct from
# the master branch on its GitHub repository.
if [[ -n "$(_composer --version | grep 'Composer version')" ]]; then
  export COMPOSER_HOME=/usr/local/src/composer
  _msg "Updating Composer..."
  _composer global config bin-dir /usr/local/bin
  _composer self-update --no-progress --no-interaction
  _composer global require --no-update --no-progress --no-interaction \
    phpunit/phpunit:6.* \
    phpunit/php-invoker:1.1.* \
    mockery/mockery:0.9.* \
    d11wtq/boris:v1.0.8
  _composer global update --no-progress --no-interaction
fi

_header "Grunt CLI"

grunts=(grunt grunt-cli grunt-sass grunt-cssjanus grunt-rtlcss)
if command -v grunt >/dev/null 2>&1; then
  _npm update  ${grunts[@]}
else
  _npm install ${grunts[@]}
fi
unset grunts

_header "WP-CLI"
_msg "Downloading WP-CLI nightly, see http://wp-cli.org"
_get https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli-nightly.phar \
  /usr/local/bin/wp
_msg "WP-CLI bash completions"
curl -s https://raw.githubusercontent.com/wp-cli/wp-cli/master/utils/wp-completion.bash \
  -o /srv/config/wp-cli/wp-completion.bash


_header "NGINX"
serverKey=/etc/nginx/server-2.1.0.key
serverCert=/etc/nginx/server-2.1.0.crt

if [[ ! -e /root/.rnd ]]; then
  _msg "Generating Random Number for cert generation..."
  echo "$(openssl rand -out /root/.rnd -hex 256 2>&1)" >/root/.rnd
fi
if [[ ! -e $serverKey ]]; then
  _msg "Generating Nginx server private key..."
  openssl genrsa -out $serverKey 2048 2>&1
fi
if [[ ! -e $serverCert ]]; then
  _msg "Sign the certificate using the above private key..."
  openssl req -new -x509 \
          -key $serverKey \
          -out $serverCert \
          -days 3650 \
          -subj /CN=*.wordpress-develop.test/CN=*.wordpress.test/CN=*.wordpress-develop.dev/CN=*.wordpress.dev/CN=*.vvv.dev/CN=*.vvv.local/CN=*.vvv.localhost/CN=*.vvv.test 2>&1
fi

_msg "Configuration files..."

install -Dm644 -t /etc/init /srv/config/init/vvv-start.conf
install -Dm644 -t /etc/nginx /srv/config/nginx-config/{nginx,nginx-wp-common}.conf
install -Dm644 \
  /srv/config/nginx-config/php${PHP_VERSION}-upstream.conf \
  /etc/nginx/upstreams/php${PHP_VERSION}.conf
mkdir -p \
  /etc/nginx/custom-dashboard-extensions \
  /etc/nginx/custom-sites \
  /etc/nginx/custom-utilities \
  /var/log/nginx
_rm /etc/nginx/custom-{dashboard-extensions,utilities}/*
rsync -rvzh --delete /srv/config/nginx-config/sites/ /etc/nginx/custom-sites/

touch /var/log/nginx/{access,error}.log


_header "PHP-FPM"
install -Dm644 /srv/config/php-config/php$PHP_VERSION-fpm.conf \
  /etc/php/$PHP_VERSION/fpm/php-fpm.conf
install -Dm644 /srv/config/php-config/php$PHP_VERSION-www.conf \
  /etc/php/$PHP_VERSION/fpm/pool.d/www.conf
install -Dm644 /srv/config/php-config/php$PHP_VERSION-custom.ini \
  /etc/php/$PHP_VERSION/fpm/conf.d/php-custom.ini
install -Dm644 /srv/config/php-config/opcache.ini \
  /etc/php/$PHP_VERSION/fpm/conf.d/opcache.ini
install -Dm644  "/srv/config/php-config/xdebug.ini" "/etc/php/$PHP_VERSION/mods-available/xdebug.ini"
install -Dm644  "/srv/config/php-config/mailhog.ini" "/etc/php/$PHP_VERSION/mods-available/mailhog.ini"
_msg "Disabling XDebug PHP extension"
phpdismod xdebug
_msg "Enabling MailHog for PHP"
phpenmod -s ALL mailhog


_header "memcache"
install -Dm644 /srv/config/memcached-config/memcached.conf /etc/memcached.conf
install -Dm644 /srv/config/memcached-config/memcached.conf /etc/memcached_default.conf


_header "MariaDB"
if systemctl is-active --quiet mysql; then
  install -Dm644 /srv/config/mysql-config/my.cnf /etc/mysql/my.cnf
  install -Dm644 /srv/config/mysql-config/root-my.cnf $HOME/.my.cnf
  install -Dm644 /srv/config/mysql-config/root-my.cnf /home/vagrant/.my.cnf

  mysqladmin -u root password root

  # Create the databases (unique to system) that will be imported with
  # the mysqldump files located in database/backups/
  if [[ -e /srv/database/init-custom.sql ]]; then
    _msg "Running custom init-custom.sql under the root user..."
    mysql -u root -proot < /srv/database/init-custom.sql
  else
    _msg "No custom MySQL scripting found in database/init-custom.sql, skipping..."
  fi

  # Setup MySQL by importing an init file that creates necessary
  # users and databases that our vagrant setup relies on.
  mysql -u root -proot < /srv/database/init.sql
  _msg "Importing databases"
  /srv/database/import-sql.sh
else
  _msg "MySQL is not installed. No databases imported."
fi


_header "PHP_CodeSniffer"

# PHP_CodeSniffer (for running WordPress-Coding-Standards)
_msg "Install/Update PHP_CodeSniffer (phpcs), see https://github.com/squizlabs/PHP_CodeSniffer"
_msg "Install/Update WordPress-Coding-Standards, sniffs for PHP_CodeSniffer, see https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards"
cd /srv/provision/phpcs
_composer update --no-autoloader

# Link `phpcbf` and `phpcs` to the `/usr/local/bin` directory so
# that it can be used on the host in an editor with matching rules
for f in phpcbf phpcs; do
  ln -sf /srv/www/phpcs/bin/$f /usr/local/bin/$f
done

# Install the standards in PHPCS
phpcs --config-set installed_paths \
  ./CodeSniffer/Standards/WordPress/,./CodeSniffer/Standards/VIP-Coding-Standards/,./CodeSniffer/Standards/PHPCompatibility/,./CodeSniffer/Standards/PHPCompatibilityParagonie/,./CodeSniffer/Standards/PHPCompatibilityWP/
phpcs --config-set default_standard WordPress-Core
phpcs -i


_header "Restarting services"

_msg "System services"
for s in mysql nginx memcached mailhog ssh; do
  systemctl restart $s.service
done

_msg "PHP FPM"
for s in $(systemctl --all | grep -e "php*fpm" | awk '{print $1}'); do
  systemctl restart $s.service
done


_header "Updating SVN repositories"
for repo in $(find /srv/www -maxdepth 5 -type d -name '.svn'); do
  # Test to see if an svn upgrade is needed on this repo.
  svn_test=$(svn status -u "$repo" 2>&1 );

  if [[ "$svn_test" == *"svn upgrade"* ]]; then
    echo " * Upgrading svn repository: ${repo}"
    svn upgrade "${repo/%\.svn/}"
  fi;
done

_header "Cleaning up"

# Dastardly Ubuntu tries to be helpful and suggest users update packages
# themselves, but this can break things
_msg "MOTD"
rm -f /etc/update-motd.d/*
install -Dm755 -t /etc/update-motd.d /srv/config/update-motd.d/00-vvv-bash-splash

_msg "Leftovers from an old VVV and migrating data"

_rm /etc/init/mailcatcher.conf

_rm /etc/php/**/mods-available/mailcatcher.ini

_rm /vagrant/vvv-custom.yml

if [ -d /srv/provision/resources ]; then
  _msg "Removing /srv/provision/resources (new path: /srv/provision/utilities)"
  _rm /srv/provision/resources
fi

# symlink the certificates folder for older site templates compat
test -d /vagrant/certificates || ln -s /srv/certificates /vagrant


_msg "Old nginx configs"
find /etc/nginx/custom-sites -name 'vvv-auto-*.conf' -delete

_msg "/etc/hosts"
t=$(mktemp)
sed -n '/# vvv-auto$/!p' /etc/hosts > $t
echo "127.0.0.1 vvv # vvv-auto" >> $t
echo "127.0.0.1 vvv.test # vvv-auto" >> $t
if is_utility_installed core tideways; then
  echo "127.0.0.1 tideways.vvv.test # vvv-auto" >> $t
  echo "127.0.0.1 xhgui.vvv.test # vvv-auto" >> $t
fi
install -Dm644 $t /etc/hosts
_rm $t

_header "Setting permissions"

set_perms

end_seconds="$(date +%s)"
echo -e "${GREEN} -----------------------------${CRESET}"
echo -e "${GREEN} * Provisioning complete in "$(( end_seconds - start_seconds ))" seconds${CRESET}"
echo -e "${GREEN} * For further setup instructions, visit http://vvv.test${CRESET}"
