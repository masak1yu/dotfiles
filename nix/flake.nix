{
  description = "msky's development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }:
    let
      darwinSystem = "aarch64-darwin";
      linuxSystem = "x86_64-linux";

      username = let u = builtins.getEnv "SUDO_USER"; in if u != "" then u else builtins.getEnv "USER";

      popplerOverlay = final: prev: {
        # Poppler: GObject Introspection typelib を有効にする（Ruby poppler gem 用）
        poppler = prev.poppler.override {
          introspectionSupport = true;
          gobject-introspection = prev.gobject-introspection;
        };
      };

      # rugged gem は libgit2 ~> 1.7.0 を要求するが nixpkgs-unstable は 1.9.x
      libgit2_1_7Overlay = final: prev: {
        libgit2_1_7 = prev.libgit2.overrideAttrs (_: {
          version = "1.7.2";
          src = prev.fetchFromGitHub {
            owner = "libgit2";
            repo = "libgit2";
            rev = "v1.7.2";
            hash = "sha256-fVPY/byE2/rxmv/bUykcAbmUFMlF3UZogVuTzjOXJUU=";
          };
        });
      };

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ popplerOverlay libgit2_1_7Overlay ];
      };

      darwinPkgs = mkPkgs darwinSystem;
      linuxPkgs = mkPkgs linuxSystem;

      commonPackagesFor = pkgs: import ./common/packages.nix { inherit pkgs; };

      darwinHomeDir = "/Users/${username}";
      linuxHomeDir = "/home/${username}";

      # --- devShell 共通定義 ---

      opLoader = ''
        _op_load() {
          local var="$1" ref="$2"
          local val
          if val=$(op read "$ref" 2>/dev/null); then
            export "$var=$val"
          fi
        }
      '';

      commonSecrets = ''
        if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
          _op_load GITHUB_TOKEN         "op://Personal/dotfiles-env/GITHUB_TOKEN"
          _op_load BUNDLE_GITHUB__COM   "op://Personal/dotfiles-env/BUNDLE_GITHUB__COM"
          _op_load AWS_ASSUME_ROLE_TTL  "op://RAKSUL/dotfiles-env/AWS_ASSUME_ROLE_TTL"
          _op_load KAFKA_HEAP_OPTS      "op://RAKSUL/dotfiles-env/KAFKA_HEAP_OPTS"
          _op_load BOOTSTRAP_SERVER_270 "op://RAKSUL/dotfiles-env/BOOTSTRAP_SERVER_270"
          _op_load BOOTSTRAP_SERVER_351 "op://RAKSUL/dotfiles-env/BOOTSTRAP_SERVER_351"
          _op_load DATADOG_ENABLED      "op://RAKSUL/dotfiles-env/DATADOG_ENABLED"
          _op_load AWS_ACCESS_KEY_ID    "op://RAKSUL/dotfiles-env/AWS_ACCESS_KEY_ID"
          _op_load AWS_SECRET_ACCESS_KEY "op://RAKSUL/dotfiles-env/AWS_SECRET_ACCESS_KEY"
          _op_load AWS_DEFAULT_REGION   "op://RAKSUL/dotfiles-env/AWS_DEFAULT_REGION"
          _op_load AWS_MFA_SERIAL       "op://RAKSUL/dotfiles-env/AWS_MFA_SERIAL"
        fi
      '';

      # librdkafka 2.5.3 は OpenSSL 3.6 と非互換（ENGINE API 削除 + rand.h 暗黙 include 削除）
      # devShell のビルド用に OpenSSL 3.0 LTS を使う
      opensslBuildFor = pkgs: pkgs.openssl_3;

      # macOS Nix Qt6 はフレームワーク形式のため、ruby-qt6 の extconf が
      # 期待する -lQt6Core / include/QtCore/QEvent が見つからない。
      # フレームワーク→通常形式のシンボリックリンクで橋渡しする。
      qt6Compat = darwinPkgs.runCommand "qt6-compat" {} ''
        mkdir -p $out/lib $out/include
        for fw in ${darwinPkgs.qt6.qtbase.out}/lib/Qt*.framework; do
          name=$(basename "$fw" .framework)
          ln -s "$fw/$name" "$out/lib/lib''${name/Qt/Qt6}.dylib"
          ln -s "$fw/Headers" "$out/include/$name"
        done
      '';

      makeDarwinShell = extraSecrets: let
        pkgs = darwinPkgs;
        opensslBuild = opensslBuildFor pkgs;
      in pkgs.mkShell {
        # ビルドツール（pkg-config の setup hook が buildInputs の
        # lib/pkgconfig を自動的に PKG_CONFIG_PATH へ追加する）
        nativeBuildInputs = with pkgs; [
          _1password-cli
          pkg-config
        ];

        # ライブラリ — pkg-config が .pc を自動検出する
        buildInputs = with pkgs; [
          # DB
          postgresql_14
          postgresql_14.pg_config
          mysql80

          # 汎用ライブラリ
          libyaml
          libyaml.dev
          libffi
          libffi.dev
          zstd
          curl

          # Image processing (rmagick gem)
          imagemagick
          imagemagick.dev

          # rugged gem requires libgit2 ~> 1.7.0
          libgit2_1_7

          # Ruby-GNOME (cairo / pango / gdk-pixbuf)
          cairo
          pango
          gdk-pixbuf
          glib
          gobject-introspection
          librsvg
          poppler

          # Ruby-GNOME の .pc Requires.private 推移的依存
          # （Ruby pkg-config gem がシステム pkg-config と違い全ツリーを解決するため必要）
          freetype
          fontconfig
          libpng
          pixman
          zlib
          harfbuzz
          expat
          pcre2
          fribidi
          libthai
          libdatrie
          libsysprof-capture

          # cairo.pc Requires.private: X11（ビルド時のみ、実行時不使用）
          libX11
          libXext
          libXrender
          libxcb
          libXdmcp
          libXau
          xorgproto

          # Qt6
          qt6.qtbase
        ];

        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
        PODMAN_COMPOSE_WARNING_LOGS = "false";
        JAVA_HOME = "${pkgs.openjdk}";

        # Ruby native extensions のビルドパス
        BUNDLE_BUILD__PG = "--with-pg-config=${pkgs.postgresql_14.pg_config}/bin/pg_config";
        BUNDLE_BUILD__MYSQL2 = "--with-mysql-config=${pkgs.mysql80}/bin/mysql_config";
        BUNDLE_BUILD__PSYCH = "--with-libyaml-include=${pkgs.libyaml.dev}/include --with-libyaml-lib=${pkgs.libyaml.out}/lib";
        BUNDLE_BUILD__FFI = "--with-libffi-dir=${pkgs.libffi.dev}";
        BUNDLE_BUILD__RUGGED = "--use-system-libraries";

        # ruby-qt6 extconf 用: フレームワーク形式→通常形式シンボリックリンク
        QT_INSTALL_HEADERS = "${qt6Compat}/include";
        QT_INSTALL_LIBS = "${qt6Compat}/lib";

        # OpenSSL 3.0 ヘッダーパス（librdkafka 2.5.3 互換）
        CPPFLAGS = "-I${opensslBuild.dev}/include";

        # リンカフラグ（openssl_3 は rpath で直接埋め込み、他パッケージの 3.6 と衝突させない）
        LDFLAGS = "-L${pkgs.zstd.out}/lib -L${opensslBuild.out}/lib -Wl,-rpath,${opensslBuild.out}/lib -L${pkgs.curl.out}/lib -F${pkgs.qt6.qtbase.out}/lib";

        # Fontconfig 設定ファイル（Nix 環境ではシステムデフォルトが見つからない）
        FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";

        # GObject Introspection typelib 検索パス（Ruby poppler/rsvg2 gem 用）
        GI_TYPELIB_PATH = builtins.concatStringsSep ":" [
          "${pkgs.poppler.out}/lib/girepository-1.0"
          "${pkgs.gobject-introspection}/lib/girepository-1.0"
        ];

        # ランタイムライブラリパス
        DYLD_LIBRARY_PATH = builtins.concatStringsSep ":" [
          "${pkgs.libyaml.out}/lib"
          "${pkgs.libffi.out}/lib"
          "${pkgs.zstd.out}/lib"
          "${pkgs.imagemagick.out}/lib"
          "${pkgs.cairo.out}/lib"
          "${pkgs.pango.out}/lib"
          "${pkgs.gdk-pixbuf.out}/lib"
          "${pkgs.glib.out}/lib"
          "${pkgs.gobject-introspection}/lib"
          "${pkgs.librsvg.out}/lib"
          "${pkgs.poppler.out}/lib"
          "${pkgs.qt6.qtbase.out}/lib"
          "${pkgs.openssl.out}/lib"
          "${pkgs.curl.out}/lib"
        ];

        shellHook = ''
          ${opLoader}
          ${commonSecrets}
          ${extraSecrets}

          # Aliases
          alias be='bundle exec'
          alias p-c='podman compose'

        '';
      };

      makeLinuxShell = extraSecrets: let
        pkgs = linuxPkgs;
        opensslBuild = opensslBuildFor pkgs;
      in pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          _1password-cli
          pkg-config
        ];

        buildInputs = with pkgs; [
          # DB
          postgresql_14.pg_config
          mysql80

          # 汎用ライブラリ
          libyaml
          libyaml.dev
          libffi
          libffi.dev
          zstd
          curl

          # Ruby-GNOME (cairo / pango / gdk-pixbuf)
          cairo
          pango
          gdk-pixbuf
          glib
          gobject-introspection
          librsvg
          poppler

          # Ruby-GNOME の .pc Requires.private 推移的依存
          freetype
          fontconfig
          libpng
          pixman
          zlib
          harfbuzz
          expat
          pcre2
          fribidi
          libthai
          libdatrie
          libsysprof-capture

          # X11
          libX11
          libXext
          libXrender
          libxcb
          libXdmcp
          libXau
          xorgproto

          # Qt6
          qt6.qtbase
        ];

        PODMAN_COMPOSE_WARNING_LOGS = "false";
        JAVA_HOME = "${pkgs.openjdk}";

        BUNDLE_BUILD__PG = "--with-pg-config=${pkgs.postgresql_14.pg_config}/bin/pg_config";
        BUNDLE_BUILD__MYSQL2 = "--with-mysql-config=${pkgs.mysql80}/bin/mysql_config";
        BUNDLE_BUILD__PSYCH = "--with-libyaml-include=${pkgs.libyaml.dev}/include --with-libyaml-lib=${pkgs.libyaml.out}/lib";
        BUNDLE_BUILD__FFI = "--with-libffi-dir=${pkgs.libffi.dev}";

        # Linux では通常のライブラリパスなので Qt6 compat シム不要
        QT_INSTALL_HEADERS = "${pkgs.qt6.qtbase.dev}/include";
        QT_INSTALL_LIBS = "${pkgs.qt6.qtbase.out}/lib";

        CPPFLAGS = "-I${opensslBuild.dev}/include";
        LDFLAGS = "-L${pkgs.zstd.out}/lib -L${opensslBuild.out}/lib -Wl,-rpath,${opensslBuild.out}/lib -L${pkgs.curl.out}/lib";

        FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";

        GI_TYPELIB_PATH = builtins.concatStringsSep ":" [
          "${pkgs.poppler.out}/lib/girepository-1.0"
          "${pkgs.gobject-introspection}/lib/girepository-1.0"
        ];

        LD_LIBRARY_PATH = builtins.concatStringsSep ":" [
          "${pkgs.libyaml.out}/lib"
          "${pkgs.libffi.out}/lib"
          "${pkgs.zstd.out}/lib"
          "${pkgs.cairo.out}/lib"
          "${pkgs.pango.out}/lib"
          "${pkgs.gdk-pixbuf.out}/lib"
          "${pkgs.glib.out}/lib"
          "${pkgs.gobject-introspection}/lib"
          "${pkgs.librsvg.out}/lib"
          "${pkgs.poppler.out}/lib"
          "${pkgs.qt6.qtbase.out}/lib"
          "${pkgs.openssl.out}/lib"
          "${pkgs.curl.out}/lib"
        ];

        shellHook = ''
          ${opLoader}
          ${commonSecrets}
          ${extraSecrets}

          # Aliases
          alias be='bundle exec'
          alias p-c='podman compose'

        '';
      };

      datadogQaSecrets = ''
        if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
          _op_load TF_VAR_datadog_api_key "op://Personal/datadog-qa/TF_VAR_datadog_api_key"
          _op_load TF_VAR_datadog_app_key "op://Personal/datadog-qa/TF_VAR_datadog_app_key"
        fi
      '';

      datadogProdSecrets = ''
        if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
          _op_load TF_VAR_datadog_api_key "op://Personal/datadog-prod/TF_VAR_datadog_api_key"
          _op_load TF_VAR_datadog_app_key "op://Personal/datadog-prod/TF_VAR_datadog_app_key"
        fi
      '';

    in {
      # --- macOS (Apple Silicon) ---
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem (
        import ./darwin/default.nix {
          pkgs = darwinPkgs;
          inherit username;
          homeDir = darwinHomeDir;
          commonPackages = commonPackagesFor darwinPkgs;
        }
      );

      devShells.${darwinSystem} = {
        default = makeDarwinShell "";
        datadog-qa = makeDarwinShell datadogQaSecrets;
        datadog-prod = makeDarwinShell datadogProdSecrets;
      };

      # --- Linux (x86_64) ---
      nixosConfigurations.linux = nixpkgs.lib.nixosSystem (
        import ./linux/default.nix {
          pkgs = linuxPkgs;
          commonPackages = commonPackagesFor linuxPkgs;
        }
      );

      devShells.${linuxSystem} = {
        default = makeLinuxShell "";
        datadog-qa = makeLinuxShell datadogQaSecrets;
        datadog-prod = makeLinuxShell datadogProdSecrets;
      };
    };
}
