# lib.sh

set -eEuo pipefail

GREEN="\033[38;5;2m"
RED="\033[38;5;9m"
CRESET="\033[0m"
PHP_VERSION=7.2

_header() {
  local msg="$1"

  echo -e "${GREEN} * ${1}${CRESET}"
}

_msg() {
  local msg="$1"

  echo -e "${CRESET} ** ${msg}"
}

_error() {
  local msg="$1"

  echo -e "${RED} *** ERROR: ${1}${CRESET}"
  exit 1
}

_rm() {
  local path="$1"

  rm -rf "$path"
}

_apt_update() {
  apt-get update &>/dev/null
}

_apt_upgrade() {
  apt-get -y dist-upgrade
}

_apt_install() {
  apt-get -y \
    --allow-downgrades \
    --allow-remove-essential \
    --allow-change-held-packages \
    --no-install-recommends \
    --fix-missing \
    --fix-broken \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confnew \
    install "$@"
}

_get() {
  local source="$1"
  local target="$2"

  test -f "$target" && _rm "$target"

  curl --silent -L "$source" \
    -o "$target"
}

_npm() {
  npm -g --no-optional "$@"
}

_composer() {
  noroot composer --no-ansi
}

set_perms() {
  chown -R vagrant:vagrant  /vagrant /usr/lib/node_modules/
  chown -R vagrant:www-data /usr/local/bin /usr/local/src/composer
  chmod -R g+w              /usr/local/bin /usr/local/src/composer
  chmod -R +x /usr/local/bin/*
}

noroot() {
  sudo -EH -u "vagrant" "$@";
}
