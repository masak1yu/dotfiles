#!/usr/bin/env bash
# Initial machine setup script
# Run once after cloning dotfiles on a new machine

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

symlink() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
  echo "  linked: $dst -> $src"
}

echo "==> Linking dotfiles..."
symlink "$DOTFILES/config/zsh/zshrc"         "$HOME/.zshrc"
symlink "$DOTFILES/config/direnv/direnvrc"   "$HOME/.config/direnv/direnvrc"
symlink "$DOTFILES/config/direnv/envrc"      "$HOME/.envrc"

echo ""
echo "==> Done. Manual steps remaining:"
echo "  1. Install Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
echo "  2. Install direnv + nix-direnv: nix profile install nixpkgs#direnv nixpkgs#nix-direnv"
echo "  3. Allow direnv: direnv allow ~"
echo "  4. Copy ~/.ssh/config and ~/.aws/config from Notion"
echo "  5. Sign in to 1Password: eval \$(op signin)"
