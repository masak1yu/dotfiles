{ pkgs }:

with pkgs; [
  # Core
  git
  gh
  jq
  wget
  direnv
  just
  lazygit

  # Development
  go
  neovim
  mise
  openjdk

  # Infrastructure
  terraform
  aws-vault

  # Shell
  starship
  zsh-autosuggestions

  # Libraries
  libyaml
  zstd
  libffi
  openssl
  openssl.dev
  curl

  # DB clients / servers
  mysql80
  postgresql_14
  redis

  # Media / graphics
  imagemagick
  graphviz
  librsvg
  poppler
  cairo
  pango
  gdk-pixbuf

  # GUI / rendering
  gobject-introspection
  qt6.qtbase
  pkg-config

  # TLS / certs
  mkcert

  # Build / release
  goreleaser

  # Build tools
  cmake

  # Test / browser
  chromedriver
]
