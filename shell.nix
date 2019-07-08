let
  pkgs = import <nixpkgs> {};

in pkgs.mkShell rec {
  buildInputs = with pkgs; [
    libffi
    libsodium
    libxml2
    zlib

    bundix
    bundler
    phpPackages.composer
    vagrant
    wp-cli
  ];
}
