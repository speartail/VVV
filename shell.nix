let
  pkgs = import <nixpkgs> {};

in pkgs.mkShell rec {

  SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
  NIX_SSL_CERT_FILE = SSL_CERT_FILE;

  buildInputs = with pkgs; [
    libffi
    libsodium
    libxml2
    zlib

    bundix
    bundler
    mysql.client # needed for mysqldump which wp-cli needs
    phpPackages.composer
    vagrant
    wp-cli
  ];
}
