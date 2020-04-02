#!/usr/bin/env bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations included with Varying Vagrant Vagrants.

set -eEuo pipefail

GREEN="\033[38;5;2m"
RED="\033[38;5;9m"
CRESET="\033[0m"

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

# fix no tty warnings in provisioner logs
sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile

export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_NO_INTERACTION=1

# cleanup
mkdir -p /vagrant

# change ownership for /vagrant folder
chown -R vagrant:vagrant /vagrant

rm -f /vagrant/version
rm -f /vagrant/vvv-custom.yml
rm -f /vagrant/config.yml

echo $(date "+%Y.%m.%d_%H-%M-%S") > /vagrant/provisioned_at

date_time=$(cat /vagrant/provisioned_at)
logfolder="/var/log/provisioners/${date_time}"
logfile="${logfolder}/provisioner-main.log"
mkdir -p "${logfolder}"
touch "${logfile}"
exec > >(tee -a "${logfile}" )
exec 2> >(tee -a "${logfile}" >&2 )

echo -e "${GREEN} * Beginning Main VVV Provisioner, if this is the first provision this may take a few minutes${CRESET}"

if [ -d /srv/provision/resources ]; then
  echo " * An old /srv/provision/resources folder was found, removing the deprecated folder ( utilities are stored in /srv/provision/utilitys now )"
  rm -rf /srv/provision/resources ## remove deprecated folder
fi

# copy over version and config files
VVV_CONFIG=/vagrant/config.yml
install -m0644 -t /vagrant /home/vagrant/version /srv/config/config.yml
chmod 0644 /vagrant/provisioned_at

# symlink the certificates folder for older site templates compat
if [[ ! -d /vagrant/certificates ]]; then
  ln -s /srv/certificates /vagrant/certificates
fi

codename=$(lsb_release --codename | cut -f2)
if [[ $codename == "trusty" ]]; then
  r="\e[0;32m"
  echo " "
  echo '__ __ __ __'
  echo '\ V\ V\ V / A message from the VVV team'
  echo ' \_/\_/\_/  '
  echo -e " "
  echo -e "We Have Some Good News and Some Bad News"
  echo -e "----------------------------------------"
  echo -e " "
  echo -e "The good news is that you updated to VVV 3+! Thanks for taking "
  echo -e "care of your install!"
  echo -e " "
  echo -e "The bad news is that your VM is still an Ubuntu 14 VM. VVV 3+ needs"
  echo -e "Ubuntu 18, and requires a vagant destroy and a reprovision."
  echo -e " "
  echo -e " "
  echo -e "\e[1;4;33mImportant: Destroying and reprovisioning will erase the database${r}"
  echo -e " "
  sqlcount=$(cd /srv/database/backups; ls -1q ./*.sql | wc -l)
  if [[ $sqlcount -gt 0 ]]; then
    echo -e "\e[0;33m "
    echo -e "\e[0;33mLuckily, VVV backs up the database to database/backups, and "
    echo -e "we found ${sqlcount} of those .sql files in database/backups from the last "
    echo -e "time you ran vagrant halt."

    echo -e "These DB backups can be restored after updating with this command:"
    echo -e "vagrant ssh -c \"db_restore\"${r}"
  else
    echo -e "\e[0;33m "
    echo -e "\e[0;33mNormally VVV takes backups, but we didn't find any existing backups${r}"
    echo -e " "
    echo -e "How Do I Grab Database Backups?"
    echo -e "--------------------------------"
    echo -e " "
    echo -e "If you've turned off database backups, or haven't turned off your VM"
    echo -e "in a while, take the following steps:"
    echo -e " "
    echo -e " 1. downgrade back to VVV 2:             git fetch --tags && git checkout 2.6.0"
    echo -e " 2. turn on the VM but dont provision:   vagrant up"
    echo -e " 3. run the backup DB script:            vagrant ssh -c \"db_backup\""
    echo -e " 4. turn off the VM:                     vagrant halt"
    echo -e " 5. return to VVV 3+:                    git checkout develop"
    echo -e " 6. you can now update your VM to VVV 3, see the instructions in the section above"
  fi
  echo -e " "
  echo -e " "
  echo -e "Updating Your VM To VVV 3+"
  echo -e "--------------------------"
  echo -e " "
  echo -e "If you're happy and have your database files, you can update your VM to VVV 3+ with these commands:"
  echo -e " "
  echo -e " 1. destroy the VM:              vagrant destroy"
  echo -e " 2. provision a new VM:          vagrant up --provision"
  echo -e " 3. optionally restore backups:  vagrant ssh -c \"db_restore\""
  echo -e " "
  echo -e " "
  echo -e " "
  exit 1
fi

source /srv/provision/provision-network-functions.sh

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages.
apt_package_install_list=(
  # Please avoid apostrophes in these comments - they break vim syntax
  # highlighting.
  #
  software-properties-common

  # PHP7
  #
  # Our base packages for php7.2. As long as php7.2-fpm and php7.2-cli are
  # installed, there is no need to install the general php7.2 package, which
  # can sometimes install apache as a requirement.
  php7.2-fpm
  php7.2-cli

  # Common and dev packages for php
  php7.2-common
  php7.2-dev

  # Extra PHP modules that we find useful
  php-pear
  php-imagick
  php-memcache
  php-memcached
  php-ssh2
  php-xdebug
  php-yaml
  php7.2-bcmath
  php7.2-curl
  php7.2-gd
  php7.2-mbstring
  php7.2-mysql
  php7.2-imap
  php7.2-json
  php7.2-soap
  php7.2-xml
  php7.2-zip

  # nginx is installed as the default web server
  nginx

  # memcached is made available for object caching
  memcached

  # mariadb (drop-in replacement on mysql) is the default database
  mariadb-server

  # other packages that come in handy
  imagemagick
  subversion
  git
  git-lfs
  git-svn
  zip
  unzip
  ngrep
  curl
  make
  vim
  colordiff
  postfix
  python-pip

  # ntp service to keep clock current
  ntp
  ntpdate

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

### FUNCTIONS

git_ppa_check() {
  # git
  #
  # apt-get does not have latest version of git,
  # so let's the use ppa repository instead.
  #
  if grep -Rq "^deb.*ppa:git-core/ppa" /etc/apt/sources.list.d/*.list; then
    # Install prerequisites.
    echo " * Setting up Git PPA pre-requisites"
    apt-get install -y python-software-properties software-properties-common &>/dev/null
    # Add ppa repo.
    echo " * Adding ppa:git-core/ppa repository"
    add-apt-repository -y ppa:git-core/ppa &>/dev/null
    # Update apt-get info.
    apt-get update &>/dev/null
    echo " * git-core/ppa added"
  else
    echo " * git-core/ppa already present, skipping"
  fi
}

noroot() {
  sudo -EH -u "vagrant" "$@";
}

cleanup_terminal_splash() {
  # Dastardly Ubuntu tries to be helpful and suggest users update packages
  # themselves, but this can break things
  rm -f /etc/update-motd.d/*
  install -m755 -t /etc/update-motd.d /srv/config/update-motd.d/00-vvv-bash-splash
}

profile_setup() {
  # root
  echo " * Copying /srv/config/bash_aliases                      to $HOME/.bash_aliases"
  rm -f "$HOME/.bash_aliases"
  cp -f "/srv/config/bash_aliases" "$HOME/.bash_aliases"
  . "$HOME/.bash_aliases"

  # vagrant
  # Copy custom dotfiles and bin file for the vagrant user from local
  echo " * Copying /srv/config/bash_profile                      to /home/vagrant/.bash_profile"
  cp --remove-destination -f "/srv/config/bash_profile" "/home/vagrant/.bash_profile"

  echo " * Copying /srv/config/bash_aliases                      to /home/vagrant/.bash_aliases"
  cp --remove-destination -f "/srv/config/bash_aliases" "/home/vagrant/.bash_aliases"

  echo " * Copying /srv/config/vimrc                             to /home/vagrant/.vimrc"
  cp --remove-destination -f "/srv/config/vimrc" "/home/vagrant/.vimrc"

  if [[ ! -d "/home/vagrant/.subversion" ]]; then
    mkdir -p "/home/vagrant/.subversion"
  fi

  echo " * Copying /srv/config/subversion-servers                to /home/vagrant/.subversion/servers"
  cp --remove-destination "/srv/config/subversion-servers" "/home/vagrant/.subversion/servers"

  echo " * Copying /srv/config/subversion-config                 to /home/vagrant/.subversion/config"
  cp --remove-destination "/srv/config/subversion-config" "/home/vagrant/.subversion/config"

  # If a bash_prompt file exists in the VVV config/ directory, copy to the VM.
  if [[ -f "/srv/config/bash_prompt" ]]; then
    echo " * Copying /srv/config/bash_prompt to /home/vagrant/.bash_prompt"
    cp --remove-destination "/srv/config/bash_prompt" "/home/vagrant/.bash_prompt"
  fi

  echo " * Setting ownership of files in /home/vagrant to vagrant"
  chown -R vagrant:vagrant /home/vagrant

  echo " * Copying /srv/config/ssh_known_hosts to /etc/ssh/ssh_known_hosts"
  cp -f /srv/config/ssh_known_hosts /etc/ssh/ssh_known_hosts
  echo " * Copying /srv/config/sshd_config to /etc/ssh/sshd_config"
  cp -f /srv/config/sshd_config /etc/ssh/sshd_config
  echo " * Reloading SSH Daemon"
  systemctl reload ssh
}

not_installed() {
  dpkg -s "$1" 2>&1 | grep -q 'Version:'
  if [[ "$?" -eq 0 ]]; then
    apt-cache policy "$1" | grep 'Installed: (none)'
    return "$?"
  else
    return 0
  fi
}

print_pkg_info() {
  local pkg="$1"
  local pkg_version="$2"
  local space_count
  local pack_space_count
  local real_space

  space_count="$(( 20 - ${#pkg} ))" #11
  pack_space_count="$(( 30 - ${#pkg_version} ))"
  real_space="$(( space_count + pack_space_count + ${#pkg_version} ))"
  printf " * $pkg %${real_space}.${#pkg_version}s ${pkg_version}\n"
}

package_install() {

  # MariaDB/MySQL
  #
  # Use debconf-set-selections to specify the default password for the root MariaDB
  # account. This runs on every provision, even if MariaDB has been installed. If
  # MariaDB is already installed, it will not affect anything.
  echo mariadb-server-10.3 mysql-server/root_password password "root" | debconf-set-selections
  echo mariadb-server-10.3 mysql-server/root_password_again password "root" | debconf-set-selections

  echo -e "\n * Setting up MySQL configuration file links..."

  if grep -q 'mysql' /etc/group; then
    echo " * mysql group exists"
  else
    echo " * creating mysql group"
    groupadd -g 9001 mysql
  fi

  if id -u mysql >/dev/null 2>&1; then
    echo " * mysql user present and has uid $(id -u mysql)"
  else
    echo " * adding the mysql user"
    useradd -u 9001 -g mysql -G vboxsf -r mysql
  fi
  id mysql

  echo " * Copying /srv/config/mysql-config/vvv-core.cnf to /etc/mysql/conf.d/vvv-core.cnf"
  install -D -t /etc/mysql/conf.d /srv/config/mysql-config/vvv-core.cnf

  # Postfix
  #
  # Use debconf-set-selections to specify the selections in the postfix setup. Set
  # up as an 'Internet Site' with the host name 'vvv'. Note that if your current
  # Internet connection does not allow communication over port 25, you will not be
  # able to send mail, even with postfix installed.
  echo postfix postfix/main_mailer_type select Internet Site | debconf-set-selections
  echo postfix postfix/mailname string vvv | debconf-set-selections

  # Provide our custom apt sources before running `apt-get update`
  echo " * Copying custom apt sources"
  cp -f /srv/config/apt-source-append.list /etc/apt/sources.list.d/vvv-sources.list

  echo " * Checking Apt Keys"
  keys=$( apt-key list )
  if [[ ! $( echo "${keys}" | grep 'NodeSource') ]]; then
    # Retrieve the NodeJS signing key from nodesource.com
    echo " * Applying NodeSource NodeJS signing key..."
    apt-key add /srv/config/apt-keys/nodesource.gpg.key
  fi

  # Before running `apt-get update`, we should add the public keys for
  # the packages that we are installing from non standard sources via
  # our appended apt source.list
  for key in /srv/config/apt-keys/*.key; do
    apt-key add $key || true
  done

  # Update all of the package references before installing anything
  echo " * Running apt-get update..."
  apt-get -y update

  # Install required packages
  echo " * Installing apt-get packages..."
  if ! apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew install --fix-missing --fix-broken ${apt_package_install_list[@]}; then
    echo " * Installing apt-get packages returned a failure code, cleaning up apt caches then exiting"
    apt-get clean
    return 1
  fi

  # Remove unnecessary packages
  echo " * Removing unnecessary packages..."
  apt-get autoremove -y

  # Clean up apt caches
  echo " * Cleaning apt caches..."
  apt-get clean

  return 0
}

# taken from <https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c>
latest_github_release() {
    local LATEST_RELEASE=$(curl --silent "https://api.github.com/repos/$1/releases/latest") # Get latest release from GitHub api
    local GITHUB_RELEASE_REGEXP="\"tag_name\": \"([^\"]+)\""

    if [[ $LATEST_RELEASE =~ $GITHUB_RELEASE_REGEXP ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

tools_install() {
  echo " * Running tools_install"
  # Disable xdebug before any composer provisioning.
  sh /srv/config/homebin/xdebug_off

  # Shyaml
  #
  # Used for passing custom parameters to the bash provisioning scripts
  echo " * Installing Shyaml for bash provisioning.."
  pip install shyaml

  echo " * Checking for NVM"
  if [[ -f ~/.nvm ]]; then
    echo " * .nvm folder found, switching to system node, and removing NVM folders"
    nvm use system
    rm -rf ~/.nvm ~/.npm ~/.bower /srv/config/nvm
    echo " * NVM folders removed"
  fi

  if [[ $(nodejs -v | sed -ne 's/[^0-9]*\(\([0-9]\.\)\{0,4\}[0-9][^.]\).*/\1/p') != '10' ]]; then
    echo " * Downgrading to Node v10."
    apt remove nodejs -y
    apt install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confnew install --fix-missing --fix-broken nodejs
  fi

  # npm
  #
  # Make sure we have the latest npm version and the update checker module
  echo " * Installing/updating npm..."
  npm install -g npm
  echo " * Installing/updating npm-check-updates..."
  npm install -g npm-check-updates

  # ack-grep
  #
  # Install ack-rep directory from the version hosted at beyondgrep.com as the
  # PPAs for Ubuntu Precise are not available yet.
  if [[ -f /usr/bin/ack ]]; then
    echo " * ack-grep already installed"
  else
    echo " * Installing ack-grep as ack"
    curl -s https://beyondgrep.com/ack-2.16-single-file > "/usr/bin/ack" && chmod +x "/usr/bin/ack"
  fi

  echo " * Making sure the composer cache is not owned by root"
  mkdir -p /usr/local/src/composer/cache
  chown -R vagrant:www-data /usr/local/src/composer
  chown -R vagrant:www-data /usr/local/bin

  # COMPOSER

  echo " * Checking for Composer"
  if [[ ! -f /usr/local/bin/composer ]]; then
    echo " * Installing Composer..."
    curl -sS "https://getcomposer.org/installer" | php
    install -Dm755 /home/vagrant/composer.phar /usr/local/bin/composer
  fi

  github_token=$(shyaml get-value general.github_token missing 2> /dev/null < ${VVV_CONFIG})
  if [[ "$github_token" != "missing" ]]; then
    rm /srv/provision/github.token
    echo "$github_token" >> /srv/provision/github.token
    echo " * A personal GitHub token was found, configuring composer"
    noroot composer config --global github-oauth.github.com "$github_token"
    echo " * Your personal GitHub token is set for Composer."
  fi

  # Update both Composer and any global packages. Updates to Composer are direct from
  # the master branch on its GitHub repository.
  if [[ -n "$(noroot composer --version --no-ansi | grep 'Composer version')" ]]; then
    echo " * Updating Composer..."
    export COMPOSER_HOME=/usr/local/src/composer
    noroot composer --no-ansi global config bin-dir /usr/local/bin
    noroot composer --no-ansi global config bin-dir /usr/local/bin
    noroot composer --no-ansi self-update --no-progress --no-interaction
    noroot composer --no-ansi global require --no-update --no-progress --no-interaction phpunit/phpunit:6.* phpunit/php-invoker:1.1.* mockery/mockery:0.9.* d11wtq/boris:v1.0.8
    noroot composer --no-ansi global update --no-progress --no-interaction
    unset COMPOSER_HOME
  fi

  # Grunt
  #
  # Install or Update Grunt based on current state.  Updates are direct
  # from NPM
  function hack_avoid_gyp_errors() {
    # Without this, we get a bunch of errors when installing `grunt-sass`:
    # > node scripts/install.js
    # Unable to save binary /usr/lib/node_modules/.../node-sass/.../linux-x64-48 :
    # { Error: EACCES: permission denied, mkdir '/usr/lib/node_modules/... }
    # Then, node-gyp generates tons of errors like:
    # WARN EACCES user "root" does not have permission to access the dev dir
    # "/usr/lib/node_modules/grunt-sass/node_modules/node-sass/.node-gyp/6.11.2"
    # TODO: Why do child processes of `npm` run as `nobody`?
    while [ ! -f /tmp/stop_gyp_hack ]; do
      if [ -d /usr/lib/node_modules/grunt-sass/ ]; then
        chown -R nobody:vagrant /usr/lib/node_modules/grunt-sass/
      fi
      sleep .2
    done
    rm /tmp/stop_gyp_hack
  }
  chown -R vagrant:vagrant /usr/lib/node_modules/

  echo " * Installing/updating Grunt CLI"
  if type -p grunt >/dev/null; then
    npm install -g grunt grunt-cli --no-optional
    hack_avoid_gyp_errors & npm install -g grunt-sass --no-optional
    touch /tmp/stop_gyp_hack
    npm install -g grunt-cssjanus --no-optional
    npm install -g grunt-rtlcss --no-optional
    echo " * Installed Grunt CLI"
  else
    npm update -g grunt grunt-cli --no-optional
    hack_avoid_gyp_errors & npm update -g grunt-sass; touch /tmp/stop_gyp_hack
    npm update -g grunt-cssjanus --no-optional
    npm update -g grunt-rtlcss --no-optional
    echo " * Updated Grunt CLI"
  fi

  # Graphviz
  #
  # Set up a symlink between the Graphviz path defined in the default Webgrind
  # config and actual path.
  echo " * Adding graphviz symlink for Webgrind..."
  ln -sf "/usr/bin/dot" "/usr/local/bin/dot"
}

nginx_setup() {
  # Create an SSL key and certificate for HTTPS support.
  if [[ ! -e /root/.rnd ]]; then
    echo " * Generating Random Number for cert generation..."
    vvvgenrnd="$(openssl rand -out /root/.rnd -hex 256 2>&1)"
    echo "$vvvgenrnd"
  fi
  if [[ ! -e /etc/nginx/server-2.1.0.key ]]; then
    echo " * Generating Nginx server private key..."
    vvvgenrsa="$(openssl genrsa -out /etc/nginx/server-2.1.0.key 2048 2>&1)"
    echo "$vvvgenrsa"
  fi
  if [[ ! -e /etc/nginx/server-2.1.0.crt ]]; then
    echo " * Sign the certificate using the above private key..."
    vvvsigncert="$(openssl req -new -x509 \
            -key /etc/nginx/server-2.1.0.key \
            -out /etc/nginx/server-2.1.0.crt \
            -days 3650 \
            -subj /CN=*.wordpress-develop.test/CN=*.wordpress.test/CN=*.wordpress-develop.dev/CN=*.wordpress.dev/CN=*.vvv.dev/CN=*.vvv.local/CN=*.vvv.localhost/CN=*.vvv.test 2>&1)"
    echo "$vvvsigncert"
  fi

  echo " * Setup configuration files..."

  # Used to ensure proper services are started on `vagrant up`
  echo " * Copying /srv/config/init/vvv-start.conf               to /etc/init/vvv-start.conf"
  install -D -t /etc/init /srv/config/init/vvv-start.conf

  # Copy nginx configuration from local
  echo " * Installing /srv/config/nginx-config/{nginx,nginx-wp-common}.conf           to /etc/nginx"
  install -D -t /etc/nginx /srv/config/nginx-config/{nginx,nginx-wp-common}.conf

  mkdir -p /etc/nginx/upstreams

  echo " * Copying /srv/config/nginx-config/php7.2-upstream.conf to /etc/nginx/upstreams/php72.conf"
  cp -f "/srv/config/nginx-config/php7.2-upstream.conf" "/etc/nginx/upstreams/php72.conf"

  mkdir -p /etc/nginx/custom-sites

  echo " * Rsync'ing /srv/config/nginx-config/sites/             to /etc/nginx/custom-sites"
  rsync -rvzh --delete "/srv/config/nginx-config/sites/" "/etc/nginx/custom-sites/"

  mkdir -p /etc/nginx/custom-utilities
  mkdir -p /etc/nginx/custom-dashboard-extensions

  rm -rf /etc/nginx/custom-{dashboard-extensions,utilities}/*

  echo " * Making sure the Nginx log files and folder exist"
  mkdir -p /var/log/nginx/
  touch /var/log/nginx/error.log
  touch /var/log/nginx/access.log
}

phpfpm_setup() {
  # Copy php-fpm configuration from local
  echo " * Installing PHP-FPM configuration"

  cp -f /srv/config/php-config/php7.2-fpm.conf /etc/php/7.2/fpm/php-fpm.conf
  cp -f /srv/config/php-config/php7.2-www.conf /etc/php/7.2/fpm/pool.d/www.conf
  cp -f /srv/config/php-config/php7.2-custom.ini /etc/php/7.2/fpm/conf.d/php-custom.ini
  cp -f /srv/config/php-config/opcache.ini /etc/php/7.2/fpm/conf.d/
  install -D -t /etc/php/7.2/mods-available /srv/config/php-config/{mailhog,xdebug}.ini

  echo " * Cleaning up mailcatcher.ini from a previous install (if it exists)"
  rm -f /etc/php/7.2/mods-available/mailcatcher.ini

  # Copy memcached configuration from local
  echo " * Installing memcached configuration"
  cp -f /srv/config/memcached-config/memcached.conf /etc/memcached.conf
  cp -f /srv/config/memcached-config/memcached.conf /etc/memcached_default.conf
}

mailhog_setup() {
  echo " * Cleaning up old mailcatcher.conf (if it exists)"
  rm -f /etc/init/mailcatcher.conf

  if [[ ! -e /usr/local/bin/mailhog ]]; then
    echo " * Installing MailHog"
    curl --silent -L -o /usr/local/bin/mailhog https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
  fi

  if [[ ! -e /usr/local/bin/mhsendmail ]]; then
    echo " * Installing MHSendmail"
    curl --silent -L -o /usr/local/bin/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64
  fi

  chmod +x /usr/local/bin/*

  echo " * Mailhog service unit"
  tee /etc/systemd/system/mailhog.service <<EOL
[Unit]
Description=MailHog
After=network.service vagrant.mount

[Service]
Type=simple
ExecStart=/usr/local/bin/mailhog
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

  echo " * Enabling and starting MailHog"
  systemctl enable mailhog --now
}

mysql_setup() {
  # If MariaDB/MySQL is installed, go through the various imports and service tasks.
  local exists_mysql

  if systemctl --quiet is-active mysql; then
    echo -e "\n * Setting up database configuration file links..."

    echo " * Install MySQL configuration"
    # Copy mysql configuration from local
    cp /srv/config/mysql-config/my.cnf /etc/mysql/my.cnf
    cp /srv/config/mysql-config/root-my.cnf /home/vagrant/.my.cnf

    echo " * Setting the default database password for the root user"
    mysqladmin -u root password root

    systemctl restart mysql

    # IMPORT SQL
    #
    # Create the databases (unique to system) that will be imported with
    # the mysqldump files located in database/backups/
    if [[ -e /srv/database/init-custom.sql ]]; then
      echo " * Running custom init-custom.sql under the root user..."
      mysql -u "root" -p"root" < /srv/database/init-custom.sql
      echo " * init-custom.sql has run"
    else
      echo -e "\n * No custom MySQL scripting found in database/init-custom.sql, skipping..."
    fi

    # Setup MySQL by importing an init file that creates necessary
    # users and databases that our vagrant setup relies on.
    mysql -u "root" -p"root" < /srv/database/init.sql
    echo " * Initial MySQL prep..."

    # Process each mysqldump SQL file in database/backups to import
    # an initial data set for MySQL.
    /srv/database/import-sql.sh
  else
    echo -e "\n * MySQL is not installed. No databases imported."
  fi
}

services_disable() {
  # DISABLE SERVICES
  #
  echo -e "\n * Disabling unneeded services..."
  for s in atd cron lxcfs lxd ntp rsyslog unattended-upgrades; do
    systemctl disable $s --now
  done
}

services_restart() {
  # RESTART SERVICES
  #
  # Make sure the services we expect to be running are running.
  echo -e "\n * Restarting services..."
  for s in nginx memcached mailhog; do
    systemctl restart $s
  done

  # Disable PHP Xdebug module by default
  echo " * Disabling XDebug PHP extension"
  phpdismod xdebug

  # Enable PHP MailHog sendmail settings by default
  echo " * Enabling MailHog for PHP"
  phpenmod -s ALL mailhog

  # Restart all php-fpm versions
  for s in $(systemctl --all | grep -e 'php.*fpm' | awk '{print $1}'); do
    systemctl restart $s
  done

  # Add the vagrant user to the www-data group so that it has better access
  # to PHP and Nginx related files.
  usermod -a -G www-data vagrant
}

wp_cli() {
  # WP-CLI Install
  local exists_wpcli

  # Remove old wp-cli symlink, if it exists.
  if [[ -L "/usr/local/bin/wp" ]]; then
    echo " * Removing old wp-cli symlink"
    rm -f /usr/local/bin/wp
  fi

  exists_wpcli="$(which wp)"
  if [[ "/usr/local/bin/wp" != "${exists_wpcli}" ]]; then
    echo " * Downloading wp-cli nightly, see http://wp-cli.org"
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli-nightly.phar
    chmod +x wp-cli-nightly.phar
    mv wp-cli-nightly.phar /usr/local/bin/wp

    echo " * Grabbing WP CLI bash completions"
    # Install bash completions
    curl -s https://raw.githubusercontent.com/wp-cli/wp-cli/master/utils/wp-completion.bash -o /srv/config/wp-cli/wp-completion.bash
  else
    echo " * Updating wp-cli..."
    wp --allow-root cli update --nightly --yes
  fi
}

php_codesniff() {
  # PHP_CodeSniffer (for running WordPress-Coding-Standards)
  # Sniffs WordPress Coding Standards
  echo -e "\n * Install/Update PHP_CodeSniffer (phpcs), see https://github.com/squizlabs/PHP_CodeSniffer"
  echo -e "\n * Install/Update WordPress-Coding-Standards, sniffs for PHP_CodeSniffer, see https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards"
  cd /srv/provision/phpcs
  noroot composer update --no-ansi --no-autoloader --no-progress

  # Link `phpcbf` and `phpcs` to the `/usr/local/bin` directory so
  # that it can be used on the host in an editor with matching rules
  ln -sf "/srv/www/phpcs/bin/phpcbf" "/usr/local/bin/phpcbf"
  ln -sf "/srv/www/phpcs/bin/phpcs" "/usr/local/bin/phpcs"

  # Install the standards in PHPCS
  phpcs --config-set installed_paths ./CodeSniffer/Standards/WordPress/,./CodeSniffer/Standards/VIP-Coding-Standards/,./CodeSniffer/Standards/PHPCompatibility/,./CodeSniffer/Standards/PHPCompatibilityParagonie/,./CodeSniffer/Standards/PHPCompatibilityWP/
  phpcs --config-set default_standard WordPress-Core
  phpcs -i
}

wpsvn_check() {
  echo " * Searching for SVN repositories that need upgrading"

  # Get all SVN repos.
  for repo in $(find /srv/www -maxdepth 5 -type d -name '.svn'); do
    # Test to see if an svn upgrade is needed on this repo.
    svn_test=$( svn status -u "$repo" 2>&1 );

    if [[ "$svn_test" == *"svn upgrade"* ]]; then
      # If it is needed do it!
      echo " * Upgrading svn repository: ${repo}"
      svn upgrade "${repo/%\.svn/}"
    fi;
  done
}

cleanup_vvv(){
  echo " * Cleaning up Nginx configs"
  # Kill previously symlinked Nginx configs
  find /etc/nginx/custom-sites -name 'vvv-auto-*.conf' -delete

  if [ -w /etc/hosts ]; then
    # Cleanup the hosts file
    echo " * Cleaning the virtual machine's /etc/hosts file..."
    sed -n '/# vvv-auto$/!p' /etc/hosts > /tmp/hosts
    echo "127.0.0.1 vvv # vvv-auto" >> "/etc/hosts"
    echo "127.0.0.1 vvv.test # vvv-auto" >> "/etc/hosts"
    if is_utility_installed core tideways; then
      echo "127.0.0.1 tideways.vvv.test # vvv-auto" >> "/etc/hosts"
      echo "127.0.0.1 xhgui.vvv.test # vvv-auto" >> "/etc/hosts"
    fi
    mv /tmp/hosts /etc/hosts
  fi
}

### SCRIPT
#set -xv

network_check
# Profile_setup
echo " * Bash profile setup and directories."
cleanup_terminal_splash
profile_setup

network_check
# Package and Tools Install
echo " "
echo " * Main packages check and install."
git_ppa_check
if ! package_install; then
  echo -e "${RED} ! Main packages check and install failed, halting provision${CRESET}"
  exit 1
fi

services_disable

tools_install
nginx_setup
mailhog_setup

phpfpm_setup
services_restart
mysql_setup

network_check
# WP-CLI and debugging tools
echo " "
echo " * Installing/updating wp-cli and debugging tools"

wp_cli
php_codesniff

network_check
# Time for WordPress!
echo " "

wpsvn_check

# VVV custom site import
echo " "
cleanup_vvv

#set +xv
# And it's done
end_seconds="$(date +%s)"
echo -e "${GREEN} -----------------------------${CRESET}"
echo -e "${GREEN} * Provisioning complete in "$(( end_seconds - start_seconds ))" seconds${CRESET}"
echo -e "${GREEN} * For further setup instructions, visit http://vvv.test${CRESET}"
