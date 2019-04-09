with import <nixpkgs> {};

let
  ruby = pkgs.ruby_2_5;
  bundler = pkgs.bundler.override { inherit ruby; };

in stdenv.mkDerivation rec {
  name = "env";
  buildInputs = [
    libffi
    libsodium
    libxml2
    zlib
  ];

  nativeBuildInputs = [
    bundix
    bundler
    phpPackages.composer
    vagrant
    wp-cli
  ];
}
