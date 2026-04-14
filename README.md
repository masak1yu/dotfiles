# dotfiles

## 構成

```
nix/
├── flake.nix           # エントリポイント (inputs / outputs / devShell)
├── flake.lock
├── common/
│   └── packages.nix    # macOS / Linux 共通パッケージ
├── darwin/
│   └── default.nix     # macOS 固有 (homebrew cask, launchd, kafka)
└── linux/
    └── default.nix     # NixOS 固有
```

## Nix チートシート

### システム（macOS: nix-darwin）

```bash
# パッケージ追加・設定変更後に適用（sudo 必須）
sudo nix run nix-darwin -- switch --flake ./nix#macbook

# nixpkgs を最新に更新してから適用
nix flake update ./nix
sudo nix run nix-darwin -- switch --flake ./nix#macbook
```

### システム（Linux: NixOS）

```bash
# 設定適用
sudo nixos-rebuild switch --flake ./nix#linux
```

### 共通

```bash
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

### トラブルシューティング

#### `system activation must now be run as root`
`sudo` なしで実行した場合のエラー。必ず `sudo` を付けて実行する。

#### `primary user `` does not exist`
`system.primaryUser` の解決に失敗している。`builtins.getEnv` は nix の pure evaluation では環境変数を読めないため、`--impure` を付けて実行する：

```bash
sudo nix run nix-darwin -- switch --flake ./nix#macbook --impure
```

または `flake.nix` に直接ユーザー名を書く：

```nix
system.primaryUser = "ma.uchida";
```

### パッケージ調査

```bash
# パッケージ検索
nix search nixpkgs <name>

# パッケージの outputs 確認
nix eval nixpkgs#<package>.outputs
```
