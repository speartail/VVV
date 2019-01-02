with import <nixpkgs> {};

let
  ruby = pkgs.ruby_2_4;
  bundler = pkgs.bundler.override { inherit ruby; };

in stdenv.mkDerivation rec {
  name = "env";
  buildInputs = [
    libffi
    # phantomjs2
    # readline
    # sqlite # needed by mailcatcher
    # zlib
  ];

  nativeBuildInputs = [
    bundix
    bundler
    vagrant
    wp-cli
  ];
}
