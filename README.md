# dotfiles

## Nix チートシート

### システム（nix-darwin）

```bash
# パッケージ追加・設定変更後に適用
nix run nix-darwin -- switch --flake ./nix#macbook

# nixpkgs を最新に更新してから適用
nix flake update ./nix
nix run nix-darwin -- switch --flake ./nix#macbook

# ガベージコレクション（古い世代を削除）
nix-collect-garbage -d

# nix store の使用量確認
du -sh /nix/store
```

### devShell

```bash
# devShell に入る
nix develop ./nix

# devShell のパッケージを強制ビルド（初回セットアップ時など）
nix develop ./nix --command echo "done"
```

### direnv

```bash
# direnv キャッシュを再構築
rm -rf .direnv && direnv allow

# 現在の環境を再ロード
direnv reload
```

### パッケージ調査

```bash
# パッケージ検索
nix search nixpkgs <name>

# パッケージの outputs 確認
nix eval nixpkgs#<package>.outputs
```
