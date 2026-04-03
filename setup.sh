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
symlink "$DOTFILES/config/zsh/zshenv"        "$HOME/.zshenv"
symlink "$DOTFILES/config/zsh/zshrc"         "$HOME/.zshrc"
symlink "$DOTFILES/config/direnv/direnvrc"   "$HOME/.config/direnv/direnvrc"
symlink "$DOTFILES/config/direnv/envrc"      "$HOME/.envrc"
symlink "$DOTFILES/config/starship.toml"     "$HOME/.config/starship.toml"
symlink "$DOTFILES/config/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml"


echo ""
echo "==> Done. Manual steps remaining:"
echo ""
echo "  [Before running this script]"
echo "  0. Clone dotfiles:"
echo "       git clone git@github.com:masak1yu/dotfiles.git ~/workspace/dotfiles"
echo ""
echo "  [After running this script]"
echo "  1. Install Nix:"
echo "       curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
echo "     Then open a new shell to activate Nix."
echo ""
echo "  2. Install global tools:"
echo "       nix profile install nixpkgs#direnv nixpkgs#nix-direnv nixpkgs#starship nixpkgs#mise"
echo ""
echo "  3. Apply nix-darwin (installs system packages + GUI apps via Homebrew):"
echo "       nix run nix-darwin -- switch --flake ~/workspace/dotfiles/nix#macbook"
echo "     After first run, use: darwin-rebuild switch --flake ~/workspace/dotfiles/nix#macbook"
echo ""
echo "  4. Copy ~/.ssh/config and ~/.aws/config from Notion"
echo ""
echo "  5. Sign in to 1Password:"
echo "       eval \$(op signin)"
echo ""
echo "  6. Allow direnv (loads Nix env + secrets):"
echo "       direnv allow ~"
echo ""
echo "  7. Open a new shell — setup complete."
